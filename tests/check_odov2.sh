#!/usr/bin/env bash

set -x

ginkgo run --procs 2 \
  --slow-spec-threshold 120s \
  --timeout 2h \
  tests/odov2 -- -stacksPath "$(pwd)"/stacks -stackDirs python
