#
#   Copyright 2021-2022 Red Hat, Inc.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
shopt -s expand_aliases
set -ex
ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_REV="$(git rev-parse --short=7 HEAD)"
INDEX_IMAGE="${INDEX_IMAGE:-quay.io/app-sre/devfile-index}"
VIEWER_IMAGE="${VIEWER_IMAGE:-quay.io/app-sre/registry-viewer}"
IMAGE_TAG="${IMAGE_TAG:-${GIT_REV}}"
USE_PODMAN=${USE_PODMAN:-false}
# PLATFORM_EV is required by the devfile-web/scripts/build_viewer.sh script
PLATFORM_EV=${PLATFORM_EV:-"linux/amd64"}

# Ensure container engine is set properly for devfile-web scripts
if [[ ${USE_PODMAN} == true ]]; then
    alias docker=podman
    echo "using podman as container engine"
fi

# Run the build script
bash $ABSOLUTE_PATH/build.sh

# Clone devfile-web for building registry-viewer
if [ -d $ABSOLUTE_PATH/devfile-web ]
then
    rm -rf $ABSOLUTE_PATH/devfile-web
fi
git clone https://github.com/devfile/devfile-web.git $ABSOLUTE_PATH/devfile-web

# export PLATFORM_EV so build_viewer.sh does not fail for MacOS users
export PLATFORM_EV
# Build registry-viewer
bash $ABSOLUTE_PATH/devfile-web/scripts/build_viewer.sh

# Push the image to quay.io
if [[ -n "$QUAY_USER" && -n "$QUAY_TOKEN" ]]; then
    DOCKER_CONF="$PWD/.docker"
    mkdir -p "$DOCKER_CONF"

    # login into quay.io
    docker --config="$DOCKER_CONF" login -u="$QUAY_USER" -p="$QUAY_TOKEN" quay.io

    # devfile-index
    docker tag devfile-index "${INDEX_IMAGE}:${IMAGE_TAG}"
    docker tag devfile-index "${INDEX_IMAGE}:next"
    docker --config="$DOCKER_CONF" push "${INDEX_IMAGE}:${IMAGE_TAG}"
    docker --config="$DOCKER_CONF" push "${INDEX_IMAGE}:next"

    # registry-viewer
    docker tag registry-viewer "${VIEWER_IMAGE}:${IMAGE_TAG}"
    docker tag registry-viewer "${VIEWER_IMAGE}:next"
    docker --config="$DOCKER_CONF" push "${VIEWER_IMAGE}:${IMAGE_TAG}"
    docker --config="$DOCKER_CONF" push "${VIEWER_IMAGE}:next"
fi
