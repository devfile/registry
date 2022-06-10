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
set -ex
ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_REV="$(git rev-parse --short=7 HEAD)"
IMAGE="${IMAGE:-quay.io/app-sre/devfile-index}"
IMAGE_TAG="${IMAGE_TAG:-${GIT_REV}}"

# Run the build script
$ABSOLUTE_PATH/build.sh

# Push the iamge to quay.io
if [[ -n "$QUAY_USER" && -n "$QUAY_TOKEN" ]]; then
    DOCKER_CONF="$PWD/.docker"
    mkdir -p "$DOCKER_CONF"
    docker tag devfile-index "${IMAGE}:${IMAGE_TAG}"
    docker tag devfile-index "${IMAGE}:next"
    docker --config="$DOCKER_CONF" login -u="$QUAY_USER" -p="$QUAY_TOKEN" quay.io
    docker --config="$DOCKER_CONF" push "${IMAGE}:${IMAGE_TAG}"
    docker --config="$DOCKER_CONF" push "${IMAGE}:next"
fi
