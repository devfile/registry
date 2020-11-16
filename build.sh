#
# Copyright (c) 2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

#!/bin/sh

# Pull down the index generator/validator if needed
if [ ! -d "./registry-support" ]; then
  echo "Cloning index-generator tool"
  git clone https://github.com/devfile/registry-support.git ./registry-support
  if [ ! $? -eq 0 ]; then
    echo "Failed to clone index-generator tool"
    exit 1
  fi
  echo "Successfully pulled the index-generator tool\n"
fi

# Build the index generator/validator
echo "Building index-generator tool"
cd ./registry-support/index/generator
./build.sh
if [ ! $? -eq 0 ]; then
  echo "Failed to build index-generator tool"
  exit 1
fi
echo -e "Successfully built the index-generator tool\n"
cd "$OLDPWD"
cp -rf ./registry-support/index/generator/index-generator ./index-generator

echo "Build the devfile registry index"
./index-generator ./stacks ./index.json
if [ ! $? -eq 0 ]; then
  echo "Failed to build the devfile registry index"
  exit 1
fi
echo -e "Successfully built the devfile registry index\n"

# Build the Docker image containing the devfile stacks and index.json
echo "Building the devfile registry index container"
docker build -t devfile-index .
if [ ! $? -eq 0 ]; then
  echo "Failed to build the devfile registry index container"
  exit 1
fi

echo "Successfully built the devfile registry index container"