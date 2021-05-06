#
# Copyright (c) 2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
FROM quay.io/openshift-pipeline/golang:1.15 AS builder

# Install dependencies
RUN apk add --no-cache git bash

COPY . /registry

# Download the registry build tools
RUN git clone https://github.com/devfile/registry-support.git /registry-support

# Run the registry build tools
RUN /registry-support/build-tools/build.sh /registry /build

FROM quay.io/devfile/devfile-index-base:next

COPY --from=builder /build/index.json /index.json
COPY --from=builder /build/stacks /stacks