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

ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build devfile-index
docker build --no-cache -t devfile-index -f $ABSOLUTE_PATH/Dockerfile $ABSOLUTE_PATH/..

# Clone devfile-web for building registry-viewer
if [ -d $ABSOLUTE_PATH/devfile-web ]
then
    rm -rf $ABSOLUTE_PATH/devfile-web
fi
git clone https://github.com/devfile/devfile-web.git $ABSOLUTE_PATH/devfile-web

# Build registry-viewer
cd $ABSOLUTE_PATH/devfile-web && bash $ABSOLUTE_PATH/devfile-web/scripts/build_viewer.sh && cd -
