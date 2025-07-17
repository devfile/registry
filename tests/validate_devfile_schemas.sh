#!/usr/bin/env bash

# Source shared utilities
source "$(dirname "$0")/get_paths.sh"

POSITIONAL_ARGS=()
SAMPLES="false"
VERBOSE="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--samples)
      SAMPLES="true"
      shift # past argument
      ;;
    -v|--verbose)
      VERBOSE="true"
      shift # past argument
      ;;
    --stackDirs)
      stackDirs=$2
      shift # past argument
      shift
      ;;
    --stacksPath)
      stacksPath=$2
      shift # past argument
      shift
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

# Restore positional parameters
restore_positional_args POSITIONAL_ARGS

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
