#!/usr/bin/env bash

set -x

ginkgo run --procs 2 \
  tests/validate_devfile_schemas -- -stacksPath "$(pwd)"/stacks -stackDirs $("$(pwd)/tests/get_stacks.sh")
