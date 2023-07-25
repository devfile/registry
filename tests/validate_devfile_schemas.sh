#!/usr/bin/env bash

set -x

stacksDir=${STACKS_DIR:-"$(pwd)/stacks"}
stackDirs=${STACKS:-"$(bash "$(pwd)/tests/get_stacks.sh")"}

ginkgo run --procs 2 \
  tests/validate_devfile_schemas -- -stacksPath ${stacksDir} -stackDirs "$stackDirs"
