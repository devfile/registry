#!/usr/bin/env bash

set -x

stacksDir=${STACKS_DIR:-stacks}
stackDirs=${STACKS:-"$(bash "$(pwd)/tests/get_stacks.sh")"}

# Use pwd if relative path
if [[ ! ${stacksDir} = /* ]]; then
  stacksDir=$(pwd)/${stacksDir}
fi

ginkgo run --procs 2 \
  tests/validate_devfile_schemas -- -stacksPath ${stacksDir} -stackDirs "$stackDirs"
