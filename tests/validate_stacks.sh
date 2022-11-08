#!/bin/sh

set -x

filesStr=$("$(pwd)/tests/get_changed_stacks.sh")

ginkgo run --procs 2 \
  tests/validate_stacks -- -stacksDir "$(pwd)"/stacks -filesStr "$filesStr"
