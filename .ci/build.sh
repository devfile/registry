#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

#!/usr/bin/env bash
# This script downloads the registry build tools and builds up this repository
# This script runs on both the GitHub action CI and the CICD for the hosted registry

# cleanup_and_exit removes the registry-support folder we cloned and exits with the exit code passed into it
ciFolder="$(dirname "$0")"
ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cleanup_and_exit() {
  rm -rf $ABSOLUTE_PATH/registry-support
  exit $1
}

cd $ciFolder
rm -rf registry-support/

# Clone the build tools
git clone https://github.com/devfile/registry-support.git
if [ $? -ne 0 ]; then
  echo "Failed to clone build tools repo"
  cleanup_and_exit 1
fi

# Run the build script
./registry-support/build-tools/build_image.sh ../

cleanup_and_exit 0