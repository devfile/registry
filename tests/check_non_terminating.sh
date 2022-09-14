#!/bin/bash
set -o nounset
set -o errexit

DEVFILES_DIR="$(pwd)/stacks"

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

getContainerComponentsNum() {
    devfilePath=$1
    component_num=$($YQ_PATH eval '[ .components[] | select(has("container")) ] | length' "$devfilePath" -r)
    echo "${component_num}"
}

getName() {
    devfilePath=$1
    name=$($YQ_PATH eval '.metadata.name' "$devfilePath" -r)
    echo "${name}"
}

getFirstContainerComponentImage() {
    devfilePath=$1

    image_original=$($YQ_PATH eval '[ .components[] | select(has("container")) ] | .[0].container.image' "$devfilePath" -r)
    image_processed=$(replaceVariables "${image_original}")
    echo "${image_processed}"
}

getFirstContainerComponentCommand() {
    devfilePath=$1
    local _gfccc_command=()
    local _gfccc_command_string=()

    IFS=" " read -r -a _gfccc_command_string <<< "$($YQ_PATH eval '[ .components[] | select(has("container")) ] | .[0].container.command[]? + " "' "$devfilePath" -r | paste -s -d '\0' -)"
    if (( ${#_gfccc_command_string[@]} == 0 )); then
        echo ""
    else
        for command_word in "${_gfccc_command_string[@]}"; do
            _gfccc_command+=("${command_word}")
        done
        echo "${_gfccc_command[@]}"
    fi
}

getFirstContainerComponentArgs() {
    devfilePath=$1
    local _gfcca_args=()
    local _gfcca_args_string=()

    IFS=" " read -r -a _gfcca_args_string <<< "$($YQ_PATH eval '[ .components[] | select(has("container")) ] | .[0].container.args[]? + " "' "$devfilePath" -r | paste -s -d '\0' -)"
    if (( ${#_gfcca_args_string[@]} == 0 )); then
      echo ""
    else
        for arg in "${_gfcca_args_string[@]}"; do 
            _gfcca_args+=("${arg}")
        done
        echo "${_gfcca_args[@]}"
    fi
}

isNonTerminating() {
    _int_image=$1
    _int_command=("$2")
    _int_command_args=("$3")

    namespace=default
    timeout_in_sec=15

    echo "  PARAMS: image --> $_int_image, command --> ${_int_command[*]}, args --> ${_int_command_args[*]}"
 
    if [ "${_int_command[*]}" == "null" ] && [ "${_int_command_args[*]}" == "null" ]; then
        echo "  COMMAND: \"kubectl run test-terminating -n default --attach=false --restart=Never --image=$_int_image\""
        2>/dev/null 1>/dev/null kubectl run test-terminating -n default --attach=false --restart=Never --image="$_int_image"
    elif [ "${_int_command[*]}" == "null" ]; then
        echo "  COMMAND: \"kubectl run test-terminating -n default --attach=false --restart=Never --image=$_int_image -- ${_int_command_args[*]}\""
        2>/dev/null 1>/dev/null kubectl run test-terminating -n default --attach=false --restart=Never --image="$_int_image" -- ${_int_command_args[*]}
    elif [ "${_int_command_args[*]}" == "null" ]; then
        echo "  COMMAND: \"kubectl run test-terminating -n default --attach=false --restart=Never --image=$_int_image --command -- ${_int_command[*]}\""
        2>/dev/null 1>/dev/null kubectl run test-terminating -n default --attach=false --restart=Never --image="$_int_image" --command=true -- ${_int_command[*]}
    else
        echo "  COMMAND: \"kubectl run test-terminating -n default --attach=false --restart=Never --image=$_int_image --command -- ${_int_command[*]} ${_int_command_args[*]}\""
        2>/dev/null 1>/dev/null kubectl run test-terminating -n default --attach=false --restart=Never --image="$_int_image" --command=true -- ${_int_command[*]} ${_int_command_args[*]}
    fi
    
    if 2>/dev/null 1>/dev/null kubectl wait pods -n ${namespace} test-terminating --for condition=Ready --timeout=${timeout_in_sec}s; then
      echo "  SUCCESS: The container started successfully and didn't terminate"
      2>/dev/null 1>/dev/null kubectl delete pod --force test-terminating -n default
      return 0
    else
      echo "  ERROR: Failed to reach \"Ready\" condition after $timeout_in_sec seconds"
      echo "  ↓↓↓↓↓↓↓↓↓ Pod description ↓↓↓↓↓↓↓↓"
      echo ""
      kubectl describe pod -n ${namespace} test-terminating
      echo ""
      echo "  ↑↑↑↑↑↑↑↑↑ Pod description ↑↑↑↑↑↑↑↑"
      2>/dev/null 1>/dev/null kubectl delete pod --force test-terminating -n default
      return 1
    fi
}

YQ_PATH=yq

find "$DEVFILES_DIR" -maxdepth 1 -type d ! -path "$DEVFILES_DIR" -print0 | while IFS= read -r -d '' devfile_dir; do

    devfile_path=$devfile_dir/devfile.yaml

    echo "======================="
    echo "Testing ${devfile_path}"

    IFS=" " read -r -a components_num <<< "$(getContainerComponentsNum "$devfile_path")"
    # components_num=($(getContainerComponentsNum "$devfile_path"))

    # if there are zero components of type container skip
    if (( components_num = 0 )); then
        echo "WARNING: Devfile with no container component found (""$devfile_path""). Skipping."
        echo "======================="
        continue
    fi

    # if there is more than one component of type container skip (we may want to cover this case in the future)
    if (( components_num > 1 )); then
        echo "WARNING: Devfile with more than one container component found (""$devfile_path""). Skipping."
        echo "======================="
        continue
    fi

    name=$(getName "$devfile_path")
    image=$(getFirstContainerComponentImage "$devfile_path")

    declare -a command=()
    IFS=" " read -r -a command <<< "$(getFirstContainerComponentCommand "$devfile_path")"

    declare -a command_args=()
    IFS=" " read -r -a command_args <<< "$(getFirstContainerComponentArgs "$devfile_path")"

    if (( ${#command[@]} > 0 )); then
        command_string="${command[*]}"
    else
        command_string="null"
    fi

    if (( ${#command_args[@]} > 0 )); then
        command_args_string="${command_args[*]}"
    else
        command_args_string="null"
    fi

    isNonTerminating "${image}" "${command_string}" "${command_args_string}";

    echo "======================="
done

exit 0
