#!/usr/bin/env bash

set -x

samplesFile="$(pwd)/extraDevfileEntries.yaml"

ginkgo run --procs 2 \
  --timeout 2h \
  tests/rhtap -- -samplesFile "$samplesFile"
