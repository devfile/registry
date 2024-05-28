#!/bin/bash

POSITIONAL_ARGS=()
VERBOSE="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE="true"
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# default samples file path
samples_file=$(pwd)/extraDevfileEntries.yaml
# Cached remote samples directory
samples_dir=$(pwd)/.cache/samples
# default stacks directory
stacks_dir=${STACKS:-"$(pwd)/stacks"}
parents_file=$(pwd)/parents.yaml
# Base directory path
base_path=$(realpath $(dirname $(dirname $0)))

# YAML query cmd path
YQ_PATH=${YQ_PATH:-yq}

# Read samples file as first argument
# if unset use default samples file path
if [ ! -z "${1}" ]; then
    samples_file=${1}
fi

get_parent_version() {
    devfile=$1
    name=$2
    version=$($YQ_PATH eval .parent.version ${devfile})

    if [ "${version}" == "null" ] && [ -f "${stacks_dir}/${name}/stack.yaml" ]; then
        version=$($YQ_PATH eval '.versions | filter(.default) | .[0].version' ${stacks_dir}/${name}/stack.yaml)
    fi

    echo ${version}
}

# Get parent index if exists, else returns -1
parent_index() {
    name=$1
    version=$2

    if [ -z "${version}" ]; then
        result=$($YQ_PATH eval ".parents | to_entries | filter(.value.name == \"${name}\") | .[0].key" ${parents_file})
    else
        result=$($YQ_PATH eval ".parents | to_entries | filter(.value.name == \"${name}\" and .value.version == \"${version}\") | .[0].key" ${parents_file})
    fi

    if [ "${result}" == "null" ]; then
        echo "-1"
    else
        echo ${result}
    fi
}

# Get child index if exists, else returns -1
child_index() {
    parent_idx=$1
    name=$2
    version=$3

    if [ -z "${version}" ]; then
        result=$($YQ_PATH eval ".parents.[${parent_idx}].children | to_entries | filter(.value.name == \"${name}\") | .[0].key" ${parents_file})
    else
        result=$($YQ_PATH eval ".parents.[${parent_idx}].children | to_entries | filter(.value.name == \"${name}\" and .value.version == \"${version}\") | .[0].key" ${parents_file})
    fi

    if [ "${result}" == "null" ]; then
        echo "-1"
    else
        echo ${result}
    fi
}

# Builds sample parent
build_parent() {
    parent_name=$1
    parent_version=$2

    if [ "${parent_version}" == "null" ]; then
        parent_version=""
    fi

    if [ "${parent_name}" != "null" ]; then
        if [ ! -f ${parents_file} ]; then
            $YQ_PATH eval -n ".parents[0].name = \"${parent_name}\"" > ${parents_file}
            if [ "${parent_version}" != "" ]; then
                $YQ_PATH eval ".parents[0].version = \"${parent_version}\"" -i ${parents_file}
            fi
            
            return
        fi

        if [ "$($YQ_PATH eval .parents ${parents_file})" == "null" ]; then
            $YQ_PATH eval ".parents[0].name = \"${parent_name}\"" -i ${parents_file}
            if [ "${parent_version}" != "" ]; then
                $YQ_PATH eval ".parents[0].version = \"${parent_version}\"" -i ${parents_file}
            fi

            return
        fi

        parent_idx=$(parent_index ${parent_name} ${parent_version})
        if [ "${parent_idx}" == "-1" ]; then
            next_idx=$($YQ_PATH eval ".parents | length" ${parents_file})
            $YQ_PATH eval ".parents[${next_idx}].name = \"${parent_name}\"" -i ${parents_file}
            if [ "${parent_version}" != "" ]; then
                $YQ_PATH eval ".parents[${next_idx}].version = \"${parent_version}\"" -i ${parents_file}
            fi
        fi
    else
        return 1
    fi
}

# Builds a child of a parent stack
build_child() {
    parent_name=$1
    parent_version=$2
    sample_name=$3
    sample_version=$4

    parent_idx=$(parent_index ${parent_name} ${parent_version})

    if [ "$($YQ_PATH eval .parents[${parent_idx}].children ${parents_file})" == "null" ]; then
        $YQ_PATH eval ".parents[${parent_idx}].children[0].name = \"${sample_name}\"" -i ${parents_file}
        if [ "${sample_version}" != "" ]; then
            $YQ_PATH eval ".parents[${parent_idx}].children[0].version = \"${sample_version}\"" -i ${parents_file}
        fi

        return
    fi

    child_idx=$(child_index ${parent_idx} ${sample_name} ${sample_version})
    if [ "${child_idx}" == "-1" ]; then
        next_idx=$($YQ_PATH eval ".parents[${parent_idx}].children | length" ${parents_file})
        $YQ_PATH eval ".parents[${parent_idx}].children[${next_idx}].name = \"${sample_name}\"" -i ${parents_file}
        if [ "${sample_version}" != "" ]; then
            $YQ_PATH eval ".parents[${parent_idx}].children[${next_idx}].version = \"${sample_version}\"" -i ${parents_file}
        fi
    fi
}

build_parents_file() {
    samples_len=$($YQ_PATH eval '.samples | length' ${samples_file})

    for ((s_idx=0;s_idx<${samples_len};s_idx++)); do
        sample_name=$($YQ_PATH eval .samples.${s_idx}.name ${samples_file})
        sample_versions=($($YQ_PATH eval .samples.${s_idx}.versions.[].version ${samples_file}))

        # Iterate through sample versions if sample has multi version support
        if [ ${#sample_versions[@]} -ne 0 ]; then
            for ((v_idx=0;v_idx<${#sample_versions[@]};v_idx++)); do
                devfile=${samples_dir}/${sample_name}/${sample_versions[$v_idx]}/devfile.yaml
                parent_name=$($YQ_PATH eval .parent.id ${devfile})
                parent_version=$(get_parent_version ${devfile} ${parent_name})
                build_parent ${parent_name} ${parent_version}

                if [ $? -eq 0 ]; then
                    build_child "${parent_name}" "${parent_version}" "${sample_name}" "${sample_versions[$v_idx]}"
                fi
            done
        else
            devfile=${samples_dir}/${sample_name}/devfile.yaml
            parent_name=$($YQ_PATH eval .parent.id ${devfile})
            parent_version=$(get_parent_version ${devfile} ${parent_name})
            build_parent ${parent_name} ${parent_version}

            if [ $? -eq 0 ]; then
                build_child "${parent_name}" "${parent_version}" "${sample_name}" ""
            fi
        fi
    done
}

# Gets the children sample paths of parents.
# When TEST_DELTA is set to true, only children of parents 
# with changes are returned.
get_children_of_parents() {
    stack_dirs=$(bash $(pwd)/tests/get_stacks.sh)
    children=()

    for stack_dir in $stack_dirs; do
        if [ "$(basename $(dirname $stack_dir))" == "." ]; then
            stack_name=$(basename $stack_dir)
            
            names=($($YQ_PATH eval ".parents | filter(.name == \"${stack_name}\") | .[0].children.[].name" ${parents_file}))
            versions=($($YQ_PATH eval ".parents | filter(.name == \"${stack_name}\") | .[0].children.[].version" ${parents_file}))
        else
            stack_name=$(basename $(dirname $stack_dir))
            stack_version=$(basename $stack_dir)

            names=($($YQ_PATH eval ".parents | filter(.name == \"${stack_name}\" and .version == \"${stack_version}\") | .[0].children.[].name" ${parents_file}))
            versions=($($YQ_PATH eval ".parents | filter(.name == \"${stack_name}\" and .version == \"${stack_version}\") | .[0].children.[].version" ${parents_file}))
        fi
        

        for ((c_idx=0;c_idx<${#names[@]};c_idx++)); do
            if [ "${versions[$c_idx]}" == "null" ]; then
                children+=("${names[$c_idx]}")
            else
                children+=("${names[$c_idx]}/${versions[$c_idx]}")
            fi
        done
    done

    echo ${children[@]}
}

if [ ! -d ${base_path}/registry-support ]
then
    if [ "$VERBOSE" == "true" ]
    then
        git clone https://github.com/devfile/registry-support ${base_path}/registry-support
    else
        git clone -q https://github.com/devfile/registry-support ${base_path}/registry-support
    fi
fi

if [ "$VERBOSE" == "true" ]
then
    bash ${base_path}/registry-support/build-tools/cache_samples.sh ${samples_file} ${samples_dir}
else
    bash ${base_path}/registry-support/build-tools/cache_samples.sh ${samples_file} ${samples_dir} > /dev/null 2>&- echo
fi

if [ -f ${parents_file} ]; then
    rm ${parents_file}
fi

build_parents_file

get_children_of_parents
