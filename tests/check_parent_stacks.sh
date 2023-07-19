#!/bin/bash

base_path=$(dirname $0)/..
# default samples file path
samples_file=${base_path}/extraDevfileEntries.yaml
# Cached remote samples directory
samples_dir=${base_path}/samples/.cache
parents_file=${base_path}/parents.yaml

# Read samples file as first argument
# if unset use default samples file path
if [ ! -z "${1}" ]; then
    samples_file=${1}
fi

# Clones remote samples into cache directory
clone_samples() {
    samples_len=$(yq eval '.samples | length' ${samples_file})

    # Removes old cached samples directory
    if [ -d ${samples_dir} ]; then
        rm -rf ${samples_dir}
    fi

    for ((s_idx=0;s_idx<${samples_len};s_idx++)); do
        name=$(yq eval .samples.${s_idx}.name ${samples_file})
        versions=($(yq eval .samples.${s_idx}.versions.[].version ${samples_file}))

        # Iterate through sample versions if sample has multi version support
        if [ ${#versions[@]} -ne 0 ]; then
            for ((v_idx=0;v_idx<${#versions[@]};v_idx++)); do
                remote_url=$(yq eval .samples.${s_idx}.versions.${v_idx}.git.remotes.origin ${samples_file})

                git clone --depth=1 ${remote_url} ${samples_dir}/${name}/${versions[$v_idx]}
            done
        else
            remote_url=$(yq eval .samples.${s_idx}.git.remotes.origin ${samples_file})

            git clone --depth=1 ${remote_url} ${samples_dir}/${name}
        fi
    done
}

# Builds sample parent dependency file
build_parents() {
    samples_len=$(yq eval '.samples | length' ${samples_file})

    if [ -f ${parents_file} ]; then
        rm ${parents_file}
    fi

    for ((s_idx=0;s_idx<${samples_len};s_idx++)); do
        name=$(yq eval .samples.${s_idx}.name ${samples_file})
        versions=($(yq eval .samples.${s_idx}.versions.[].version ${samples_file}))

        # Iterate through sample versions if sample has multi version support
        if [ ${#versions[@]} -ne 0 ]; then
            for ((v_idx=0;v_idx<${#versions[@]};v_idx++)); do
                devfile=${samples_dir}/${name}/${versions[$v_idx]}/devfile.yaml
                parent=$(yq eval .parent.id ${devfile})
                parent_version=$(yq eval .parent.version ${devfile})
                
                # TODO: multi version build control logic
            done
        else
            devfile=${samples_dir}/${name}/devfile.yaml
            parent=$(yq eval .parent.id ${devfile})

            if [ "${parent}" != "null" ]; then
                if [ -f ${parents_file} ] && [ "$(yq eval .parents.${parent}.children ${parents_file})" != "null" ]; then
                    next_idx=$(yq eval ".parents.${parent}.children | length" ${parents_file})
                    yq eval ".parents.${parent}.children[${next_idx}] = \"${name}\"" -i ${parents_file}
                elif [ -f ${parents_file} ]; then
                    yq eval ".parents.${parent}.children[0] = \"${name}\"" -i ${parents_file}
                else
                    yq eval -n ".parents.${parent}.children[0] = \"${name}\"" > ${parents_file}
                fi
            fi
        fi
    done
}

clone_samples

# build_parents
