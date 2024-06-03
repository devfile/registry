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

ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USE_PODMAN=${USE_PODMAN:-false}
DEFAULT_ARCH="linux/amd64"

# Check if different architecture was passed for image build
# Will default to $DEFAULT_ARCH if unset
if [ ! -z "$1" ]
  then
    arch="$1"
else
    arch="$DEFAULT_ARCH"
fi

if [[ ${USE_PODMAN} == true ]]; then
    alias docker=podman
    echo "using podman as container engine"
fi

if [ $# -eq 1 ] && [ $1 == "offline" ]
then
    docker build --no-cache --platform "${arch}" -t devfile-index -f $ABSOLUTE_PATH/Dockerfile.offline $ABSOLUTE_PATH/..
else
    docker build --no-cache --platform "${arch}" -t devfile-index -f $ABSOLUTE_PATH/Dockerfile $ABSOLUTE_PATH/..
fi
