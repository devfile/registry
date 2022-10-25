#!/usr/bin/env bash

set -x
DEVFILES_DIR="$(pwd)/stacks/"
FAILED_TESTS=""

getURLs() {
    urls=$($ODO_PATH url list | awk '{ print $3 }' | tail -n +3 | tr '\n' ' ')
    echo "$urls"
}

# periodicaly check url till it returns expected HTTP status
# exit after 10 tries
waitForHTTPStatus() {
   url=$1
   statusCode=$2

    for i in $(seq 1 10); do
        echo "try: $i"
        content=$(curl -i "$url")
        echo "Checking if $url is returning HTTP $statusCode"
        echo "$content" | grep -q -E "HTTP/[0-9.]+ $statusCode"
        retVal=$?
        if [ $retVal -ne 0 ]; then
            echo "ERROR not HTTP $statusCode"
            echo "$content"
        else
            echo "OK HTTP $statusCode"
            return 0
        fi
        sleep 10
    done
    return 1
}

# run test on devfile
# parameters:
# - name of a component and project 
# - path to devfile.yaml
# - namespace for the project
test() {
    devfileName=$1
    devfilePath=$2
    namespace=$3

    # remember if there was en error
    error=false

    tmpDir=$(mktemp -d)
    cd "$tmpDir" || return 1

    $ODO_PATH project create "$namespace" || error=true
    if $error; then
        echo "ERROR project create failed"
        FAILED_TESTS="$FAILED_TESTS $namespace"
        return 1
    fi
    
    # Get the starter project name
    starterProject=$($YQ_PATH e '.starterProjects[0].name' $devfilePath)
    if [ "$REGISTRY" = "local" ]; then
      $ODO_PATH create --devfile "$devfilePath" --starter $starterProject || error=true
    else
      $ODO_PATH create "$devfileName" --starter $starterProject || error=true
    fi

    if $error; then
        echo "ERROR create failed"
        $ODO_PATH project delete -f "$namespace"
        FAILED_TESTS="$FAILED_TESTS $namespace"
        return 1
    fi

    if [ "$ENV" = "minikube" ]; then
        exposedEndpoints=$("$YQ_PATH" e '.components[].container.endpoints[] | select (.exposure != "none" and .exposure != "internal").targetPort' "$devfilePath")
        if [ "$exposedEndpoints" = "" ] || [ "$exposedEndpoints" = "null" ]; then
            echo "WARN Devfile at path $devfilePath has no endpoints => no URL will be created."
        else
            for ep in $exposedEndpoints; do
                "$ODO_PATH" url create --host "$(minikube ip).nip.io" --port "$ep" || error=true
            done
            if $error; then
                echo "ERROR url create failed"
                $ODO_PATH project delete -f "$namespace"
                FAILED_TESTS="$FAILED_TESTS $namespace"
                return 1
            fi
        fi
    fi

    $ODO_PATH push || error=true
    if $error; then
        echo "ERROR push failed"
        $ODO_PATH delete -f -a || error=true
        $ODO_PATH project delete -f "$namespace"
        FAILED_TESTS="$FAILED_TESTS $namespace"
        return 1
    fi

    # check if application is responding
    urls=$(getURLs)

    for url in $urls; do
        statusCode=200
        
        waitForHTTPStatus "$url" "$statusCode"
        if [ $? -ne 0 ]; then
            echo "ERROR unable to get working url"
            $ODO_PATH project delete -f "$namespace"
            FAILED_TESTS="$FAILED_TESTS $namespace"
            error=true
            return 1
        fi
    done

    # kill -9 $CPID
    $ODO_PATH delete -f -a || error=true
    $ODO_PATH project delete -f "$namespace"

    if $error; then
        echo "FAIL"
        # record failed test
        FAILED_TESTS="$FAILED_TESTS $namespace"
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
  echo "ERROR: Allowed values for ENV are either \"minikube\" (default) or \"openshift\"."
  exit 1
fi
if [ -z $REGISTRY ]; then
  REGISTRY=local
fi
if [ "$REGISTRY" != "local" ] && [ "$REGISTRY" != "remote" ]; then
  echo "ERROR: Allowed values for REGISTRY are either \"local\" (default) or \"remote\"."
  exit 1
fi

for devfile_dir in $(find $DEVFILES_DIR -maxdepth 2 -type d ! -path $DEVFILES_DIR); do
    devfile_path=$devfile_dir/devfile.yaml
    if [ ! -f "$devfile_path" ]; then
        # multi version stacks contain nested devfiles
        continue
    fi

    # skip devfiles that use 2.2
    devfile_schema_version=$($YQ_PATH eval '.schemaVersion' $devfile_path)
    if [[ $devfile_schema_version == "2.2."* ]]; then
        continue
    fi

    devfile_name=$($YQ_PATH eval '.metadata.name' $devfile_path)
    devfile_version=$($YQ_PATH eval '.metadata.version' $devfile_path)

    # deploying a multi version stack requires unique namespaces
    namespace=$devfile_name-${devfile_version//.}

    # Skipping the java-wildfly-bootable-jar stack right now since it's broken.
    # ToDo: Uncomment once fixed.
    if [ $devfile_name != "java-wildfly-bootable-jar" ]; then
        test "$devfile_name" "$devfile_path" "$namespace"
    fi
done

# remember if there was an error so the script can exist with proper exit code at the end
error=false

# print out which tests failed
if [ "$FAILED_TESTS" != "" ]; then
    error=true
    echo "FAILURE: FAILED TESTS: $FAILED_TESTS"
    exit 1
fi

exit 0
