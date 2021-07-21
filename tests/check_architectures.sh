#!/bin/bash

STACKS_DIR="$(pwd)/stacks/"
EXTRA_DEVFILES_FILE="$(pwd)/extraDevfileEntries.yaml"

display_usage() { 
  echo "usage: check_architectures.sh \"stacks/java-maven/devfile.yaml stacks/java-openliberty/devfile.yaml\" [/path/to/yq]" 
} 

checkStacks() {
    STACK=$1
    for STACK_DIR in $(find $STACKS_DIR -maxdepth 1 -type d ! -path $STACKS_DIR); do
        STACK_NAME="$(basename $STACK_DIR)"

        if [[ $STACK_NAME == $STACK ]]; then
            DEVFILE_PATH=$STACK_DIR/devfile.yaml
    
            DEVFILE_ARCHITECTURES=$(cat $DEVFILE_PATH | grep architectures)

            if [[ -z $DEVFILE_ARCHITECTURES ]]; then
                missingStackDevfileArch="$missingStackDevfileArch$STACK_NAME, "
            fi
        fi
    done
}

checkSamples() {
    if ! command -v $YQ_PATH &> /dev/null
    then
        echo "The command $YQ_PATH could not be found, please install the command to parse $EXTRA_DEVFILES_FILE"
        exit 1
    fi

    NO_OF_SAMPLES="$($YQ_PATH e '.samples | length' $EXTRA_DEVFILES_FILE)"

    for i in $(seq $NO_OF_SAMPLES); do
        SAMPLE_NAME="$($YQ_PATH e .samples[$(($i-1))].name $EXTRA_DEVFILES_FILE)"
        SAMPLE_ARCHS="$($YQ_PATH e .samples[$(($i-1))].architectures $EXTRA_DEVFILES_FILE)"

        if [[ $SAMPLE_ARCHS == "null" ]]; then
            missingSampleArch="$missingSampleArch$SAMPLE_NAME, "
        fi
    done
}

# Check if stack devfiles to scan were passed in, if not, exit
if [ $# -lt 1 ]; then
  display_usage
  exit 1
fi

YQ_PATH=$2
if [[ -z $YQ_PATH ]]; then
  YQ_PATH=yq
fi

FILE_DIFF=$1
for file in $FILE_DIFF
do
    file="${file//\'}"
    if [ $file == "extraDevfileEntries.yaml" ]; then
        checkSamples
    elif [[ $file == stacks/*/devfile.yaml ]]; then
        STACK_TEMP="$(echo $file | cut -d'/' -f2)"
        checkStacks $STACK_TEMP
    fi
done

if [[ ! -z "$missingStackDevfileArch" || ! -z "$missingSampleArch" ]]; then
    if [ ! -z "$missingStackDevfileArch" ]; then
        missingStackDevfileArch=$(echo $missingStackDevfileArch | sed s'/,$//')
        echo stacks with missing architectures: $missingStackDevfileArch
    fi

    if [ ! -z "$missingSampleArch" ]; then
        missingSampleArch=$(echo $missingSampleArch | sed s'/,$//')
        echo samples with missing architectures: $missingSampleArch
    fi

    exit 1
fi
