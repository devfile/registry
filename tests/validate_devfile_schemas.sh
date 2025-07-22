#!/usr/bin/env bash

# Source shared utilities
source "$(dirname "$0")/paths_util.sh"

SAMPLES="false"
VERBOSE="false"

handle_additional_args() {
    case $1 in
        -s|--samples)
            SAMPLES="true"
            echo 1
            return 0
            ;;
        -v|--verbose)
            VERBOSE="true"
            echo 1
            return 0 
            ;;
        *)
            echo 0
            return 1
            ;;
    esac
}

# Parse all arguments
parse_arguments "$@"

# Restore positional parameters
set -- "${POSITIONAL_ARGS[@]}"

set -x

# Set defaults for stack arguments, with backward compatibility for environment variables
if [ -z "$stacksPath" ]; then
  stacksPath=${STACKS_DIR:-stacks}
fi

if [ -z "$stackDirs" ]; then
  stackDirs=${STACKS:-"$(bash "$(pwd)/tests/get_stacks.sh")"}
fi

stacksDir="$stacksPath"

# Use pwd if relative path
if [[ ! ${stacksDir} = /* ]]; then
  stacksDir=$(pwd)/${stacksDir}
fi

# Unzip resource files if samples
if [ "${SAMPLES}" == "true" ]; then
  if [ "${VERBOSE}" == "true" ]; then
    for sample_dir in $(ls $stacksDir); do
      unzip -n $stacksDir/$sample_dir/sampleName.zip -d $stacksDir
    done
  else
    for sample_dir in $(ls $stacksDir); do
      unzip -q -n $stacksDir/$sample_dir/sampleName.zip -d $stacksDir
    done
  fi
fi

ginkgo run --mod=readonly --procs 2 \
  tests/validate_devfile_schemas -- -stacksPath ${stacksDir} -stackDirs "$stackDirs"
