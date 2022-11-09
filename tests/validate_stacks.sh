#!/usr/bin/env bash

set -x

stackDirs=$("$(pwd)/tests/get_stacks.sh")

ginkgo run --procs 2 \
  tests/validate_stacks -- -stacksPath "$(pwd)"/stacks -stackDirs "$stackDirs"
