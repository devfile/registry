#!/bin/bash

base_path=$(dirname $0)/..
samples_file=${base_path}/extraDevfileEntries.yaml
# Cached remote samples directory
samples_dir=${base_path}/samples/.cache

# Clones remote samples into cache directory
clone_samples() {
    samples_len=$(yq eval '.samples | length' ${samples_file})

    # Removes old cached samples directory
    if [ -d ${samples_dir} ]; then
        rm -rf ${samples_dir}
    fi

    for ((idx=0;idx<${samples_len};idx++)); do
        name=$(yq eval .samples.${idx}.name ${samples_file})
        remote_url=$(yq eval .samples.${idx}.git.remotes.origin ${samples_file})

        git clone --depth=1 ${remote_url} ${samples_dir}/${name}
    done
}

# Builds sample parent dependency file
build_parents() {
    samples_len=$(yq eval '.samples | length' ${samples_file})

    if [ -f parents.yaml ]; then
        rm parents.yaml
    fi

    for ((idx=0;idx<${samples_len};idx++)); do
        name=$(yq eval .samples.${idx}.name ${samples_file})
        devfile=${samples_dir}/${name}/devfile.yaml
        parent=$(yq eval .parent.id ${devfile})
        
        if [ "${parent}" != "null" ]; then
            if [ -f parents.yaml ] && [ "$(yq eval .parents.${parent}.children parents.yaml)" != "null" ]; then
                next_idx=$(yq eval ".parents.${parent}.children | length" parents.yaml)
                yq eval ".parents.${parent}.children[${next_idx}] = \"${name}\"" -i parents.yaml
            elif [ -f parents.yaml ]; then
                yq eval ".parents.${parent}.children[0] = \"${name}\"" -i parents.yaml
            else
                yq eval -n ".parents.${parent}.children[0] = \"${name}\"" > parents.yaml
            fi
        fi
    done
}

clone_samples

build_parents