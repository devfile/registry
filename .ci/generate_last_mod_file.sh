#!/bin/sh

#
# Copyright Red Hat
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

stack_data=()
sample_data=()

grab_stacks() {
    echo "Grabbing last modified date for stacks"

    # look through git tree for all devfiles under stacks/
    for filename in $(git ls-tree -r --name-only HEAD); do
        if [[ $filename == *"stacks/"*"/devfile"* ]]; then
            directory=$(dirname "$filename")
            stack=$(yq -r .metadata.name $filename)
            version=$(yq -r .metadata.version $filename)
            # last commit that modified the entire directory that contains a devfile
            last_commit=$(git log -1 --format="%aI" -- "$directory")

            # replace null -> undefined for consistency with sample handling
            if [[ $version == "null" ]]; then
                version="undefined"
            fi

            stack_data+=("{\"name\": \"${stack}\",\"version\": \"${version}\",\"lastModified\": \"${last_commit}\"}") 
        fi
    done
}

grab_samples(){
    echo "Grabbing last modified date for samples"
    echo "Creating temp data.json file"

    yq -p yaml -o json extraDevfileEntries.yaml > data.json
    PARENT_DIR=$PWD
    TEMP_DIR=$PWD/temp
    mkdir -p temp && cd temp
    while IFS= read -r line; do
        name=$(echo "$line" | cut -d ' ' -f 1)
        version=$(echo "$line" | cut -d ' ' -f 2)
        revision=$(echo "$line" | cut -d ' ' -f 3)
        git_origin=$(echo "$line" | cut -d ' ' -f 4)
        if [[ $revision == "undefined" ]]; then
            repo_name="$name"
            git clone -q $git_origin $repo_name
        else
            repo_name="$name"-"$revision"
            git clone -q -b $revision $git_origin $repo_name
        fi
        
        cd $repo_name
        last_commit=$(git log -1 --format="%aI")
        cd $TEMP_DIR
        sample_data+=("{\"name\": \"${name}\",\"version\": \"${version}\",\"lastModified\": \"${last_commit}\"}")
    done < <(jq -r '
    .samples[] | 
    if has("versions") 
    then 
        "\(.name) \(.versions[] | "\(.version) \(.git.revision) \(.git.remotes.origin)")" 
    elif .git.revision != null 
    then 
        "\(.name) undefined \(.git.revision) \(.git.remotes.origin)" 
    else 
        "\(.name) undefined undefined \(.git.remotes.origin)" 
    end
    ' $PARENT_DIR/data.json)

    cd $PARENT_DIR
    
    # cleanup of temp files and temp data store
    echo "Cleaning up temp files"
    rm -rf $PARENT_DIR/temp
    rm $PARENT_DIR/data.json

}

create_last_modified_file() {
    grab_stacks
    grab_samples
    echo "Creating the last_modified.json file"

    stacks_json=$(printf '%s\n' "${stack_data[@]}" | jq -s .)
    samples_json=$(printf '%s\n' "${sample_data[@]}" | jq -s .)

    last_mod_file=$(jq -n --argjson stacks "$stacks_json" --argjson samples "$samples_json" '{ stacks: $stacks, samples: $samples }')
    echo "$last_mod_file" > last_modified.json

}

create_last_modified_file