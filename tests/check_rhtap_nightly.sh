#!/usr/bin/env bash

set -x

ROOT_REPO_DIR=$(pwd)
samplesFile="$ROOT_REPO_DIR/extraDevfileEntries.yaml"

# Install golang modules
cd "$ROOT_REPO_DIR"/tests/rhtap && \
    go mod tidy && \
    go mod vendor && \
    cd "$ROOT_REPO_DIR"

ginkgo run -p \
  --timeout 2h \
  tests/rhtap -- -samplesFile "$samplesFile"
