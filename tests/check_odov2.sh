#!/usr/bin/env bash

set -x
DEVFILES_DIR="$(pwd)/stacks"
FAILED_TESTS=()

# The stacks to test as a string separated by spaces
STACKS=$(bash "$(pwd)/tests/get_stacks.sh")

replaceVariables() {
  image=$1
  VAR_KEYS=(liberty-version)
  VAR_VALUES=(22.0.0.1)

  for i in "${!VAR_KEYS[@]}"; do
    key='{{'
    key+=${VAR_KEYS[i]}
    key+='}}'
    value=${VAR_VALUES[i]}
    image=${image/${key}/${value}}
  done
  echo "$image"
}

getFirstContainerComponentImage() {
  devfilePath=$1
  image_original=$($YQ_PATH eval '[ .components[] | select(has("container")) ] | .[0].container.image' "$devfilePath" -r)
  image_processed=$(replaceVariables "${image_original}")
  echo "${image_processed}"
}

getURLs() {
  urls=$($ODO_PATH url list | awk '{ print $3 }' | tail -n +3 | tr '\n' ' ')
  echo "$urls"
}

# periodicaly check url till it returns expected HTTP status
# exit after 10 tries
waitForHTTPStatus() {
  url=$1
  status_code=$2

  for i in $(seq 1 10); do
    echo "try: $i"
    content=$(curl -i "$url")
    echo "Checking if $url is returning HTTP $status_code"
    echo "$content" | grep -q -E "HTTP/[0-9.]+ $status_code"
    ret_val=$?
    if [ $ret_val -ne 0 ]; then
      echo "ERROR: not HTTP $status_code"
      echo "$content"
    else
      echo "OK HTTP $status_code"
      return 0
    fi
    sleep 10
  done
  return 1
}

# run test on devfile
# parameters:
# - name of the devfile
# - version of the devfile
# - path to devfile.yaml
test() {
  devfile_name=$1
  devfile_version=$2
  devfile_path=$3

  # deploying a multi version stack requires unique namespaces
  namespace=$devfile_name-${devfile_version//./}

  # remember if there was en error
  error=false

  tmp_dir=$(mktemp -d)
  cd "$tmp_dir" || return 1

  $ODO_PATH project create "$namespace" || error=true
  if $error; then
    echo "ERROR: project create failed"
    FAILED_TESTS+=("name: $devfile_name version: $devfile_version error: project create failed")
    return 1
  fi

  # Get the starter project name
  starter_project=$($YQ_PATH e '.starterProjects[0].name' $devfile_path)
  if [ "$REGISTRY" = "local" ]; then
    $ODO_PATH create --devfile "$devfile_path" --starter $starter_project || error=true
  else
    $ODO_PATH create "$devfile_name" --starter $starter_project || error=true
  fi

  if $error; then
    echo "ERROR: create failed"
    $ODO_PATH project delete -f "$namespace"
    FAILED_TESTS+=("name: $devfile_name version: $devfile_version error: create failed")
    return 1
  fi

  if [ "$ENV" = "minikube" ]; then
    # workaround: cri-dockerd v0.2.6+ fixes a timeout issue where large images are not being pulled
    # this can be removed when actions-setup-minikube updates cri-dockerd
    image=$(getFirstContainerComponentImage "$devfile_path")
    minikube ssh docker pull $image >/dev/null 2>&1

    exposed_endpoints=$("$YQ_PATH" e '.components[].container.endpoints[] | select (.exposure != "none" and .exposure != "internal").targetPort' "$devfile_path")
    if [ "$exposed_endpoints" = "" ] || [ "$exposed_endpoints" = "null" ]; then
      echo "WARN Devfile at path $devfile_path has no endpoints => no URL will be created."
    else
      for ep in $exposed_endpoints; do
        "$ODO_PATH" url create --host "$(minikube ip).nip.io" --port "$ep" || error=true
      done
      if $error; then
        echo "ERROR: url create failed"
        $ODO_PATH project delete -f "$namespace"
        FAILED_TESTS+=("name: $devfile_name version: $devfile_version error: url create failed")
        return 1
      fi
    fi
  fi

  $ODO_PATH push || error=true
  if $error; then
    echo "ERROR: push failed"
    $ODO_PATH delete -f -a || error=true
    $ODO_PATH project delete -f "$namespace"
    FAILED_TESTS+=("name: $devfile_name version: $devfile_version error: push failed")
    return 1
  fi

  # check if application is responding
  urls=$(getURLs)

  for url in $urls; do
    status_code=200

    waitForHTTPStatus "$url" "$status_code"
    if [ $? -ne 0 ]; then
      echo "ERROR: unable to get working url"
      $ODO_PATH project delete -f "$namespace"
      FAILED_TESTS+=("name: $devfile_name version: $devfile_version error: unable to get working url")
      error=true
      return 1
    fi
  done

  # kill -9 $CPID
  $ODO_PATH delete -f -a || error=true
  $ODO_PATH project delete -f "$namespace"

  if $error; then
    echo "ERROR: project delete failed"
    FAILED_TESTS+=("name: $devfile_name version: $devfile_version error: project delete failed")
    return 1
  fi

  return 0
}

ODO_PATH=$1
YQ_PATH=$2

if [ -z $ODO_PATH ]; then
  ODO_PATH=odo
fi

if [ -z $YQ_PATH ]; then
  YQ_PATH=yq
fi

if [ -z $ENV ]; then
  ENV=minikube
fi

if [ "$ENV" != "minikube" ] && [ "$ENV" != "openshift" ]; then
  echo "ERROR:: Allowed values for ENV are either \"minikube\" (default) or \"openshift\"."
  exit 1
fi

if [ -z $REGISTRY ]; then
  REGISTRY=local
fi

if [ "$REGISTRY" != "local" ] && [ "$REGISTRY" != "remote" ]; then
  echo "ERROR:: Allowed values for REGISTRY are either \"local\" (default) or \"remote\"."
  exit 1
fi

for stack in $STACKS; do
  devfile_path="$DEVFILES_DIR/$stack/devfile.yaml"
  if [ ! -f "$devfile_path" ]; then
    echo "WARN: Devfile not found at path $devfile_path"
    continue
  fi

  # skip devfiles that use 2.2
  devfile_schema_version=$($YQ_PATH eval '.schemaVersion' $devfile_path)
  if [[ $devfile_schema_version == "2.2."* ]]; then
    continue
  fi

  devfile_name=$($YQ_PATH eval '.metadata.name' $devfile_path)
  devfile_version=$($YQ_PATH eval '.metadata.version' $devfile_path)

  # Skipping the java-wildfly-bootable-jar stack right now since it's broken.
  # TODO: Uncomment once fixed.
  if [[ $stack != "java-wildfly-bootable-jar" && $stack != "java-quarkus/1.3.0" && $stack != "java-quarkus/1.4.0" ]]; then
    test "$devfile_name" "$devfile_version" "$devfile_path"
  fi
done

# print out which tests failed
if [ ! ${#FAILED_TESTS[@]} -eq 0 ]; then
  echo "The following tests failed:"
  for test in "${FAILED_TESTS[@]}"; do
    echo "$test"
  done

  exit 1
fi

exit 0
