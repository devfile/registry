#!/bin/sh

set -x

ginkgo run --procs 2 \
  tests/validate_stacks -- -stacksDir "$(pwd)"/stacks
