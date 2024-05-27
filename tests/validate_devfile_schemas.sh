#!/usr/bin/env bash

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
set -x

stacksDir=${STACKS_DIR:-stacks}
stackDirs=${STACKS:-"$(bash "$(pwd)/tests/get_stacks.sh")"}

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

ginkgo run --procs 2 \
  tests/validate_devfile_schemas -- -stacksPath ${stacksDir} -stackDirs "$stackDirs"
