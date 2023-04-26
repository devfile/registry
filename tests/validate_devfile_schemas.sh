#!/usr/bin/env bash

set -x

stackDirs=$(bash "$(pwd)/tests/get_stacks.sh")

ginkgo run --procs 2 \
  tests/validate_devfile_schemas -- -stacksPath "$(pwd)"/stacks -stackDirs "$stackDirs"
