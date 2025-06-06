#
#   Copyright 2020-2023 Red Hat, Inc.
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
ARG BASE_IMAGE=quay.io/devfile/devfile-index-base:next

FROM registry.access.redhat.com/ubi8/go-toolset:1.23 AS builder

# Set user as root
USER root

# Automatically set when --platform flag is set, will default to amd64 if no platform is given
ARG TARGETARCH=amd64

# Install yq and jq
ENV YQ_VERSION=v4.44.1
ENV JQ_VERSION=1.6
RUN curl -sL -O https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH} -o /usr/local/bin/yq && mv ./yq_linux_${TARGETARCH} /usr/local/bin/yq && chmod +x /usr/local/bin/yq
RUN yum install -y jq-${JQ_VERSION}

COPY . /registry

# Script needs to be run from within registry directory
WORKDIR /registry
RUN bash .ci/generate_last_mod_file.sh
WORKDIR /

# Download the registry build tools
RUN git clone https://github.com/devfile/registry-support.git /registry-support

# Run the registry build tools
RUN bash /registry-support/build-tools/build.sh /registry /build

# Set user as non-root
USER 1001

FROM ${BASE_IMAGE}

COPY --from=builder /build /registry
