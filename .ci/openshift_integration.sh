#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

#!/usr/bin/env bash
# exit immediately when a command fails
set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail
# error on unset variables
set -u
# print each command before executing it
set -x

# Disable telemtry for odo
export ODO_DISABLE_TELEMETRY=true

# Split the registry image and image tag from the REGISTRY_IMAGE env variable
IMG="$(echo $REGISTRY_IMAGE | cut -d':' -f1)"
TAG="$(echo $REGISTRY_IMAGE | cut -d':' -f2)"

# Create a project/namespace for running the tests in
oc new-project devfile-registry-test

# Install yq
curl -sL https://github.com/mikefarah/yq/releases/download/v4.9.5/yq_linux_amd64 -o yq && chmod +x yq
YQ_PATH=$(realpath yq)

# Download odo
curl -sL https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/odo/latest/odo-linux-amd64 -o odo && chmod +x odo
export GLOBALODOCONFIG=$(pwd)/preferences.yaml

# Install the devfile registry
oc process -f .ci/deploy/devfile-registry.yaml -p DEVFILE_INDEX_IMAGE=$IMG -p IMAGE_TAG=$TAG -p REPLICAS=3 | \
  oc apply -f -

# Deploy the routes for the registry
oc process -f .ci/deploy/route.yaml | oc apply -f -

# Wait for the registry to become ready
oc wait deploy/devfile-registry --for=condition=Available --timeout=600s

# Get the route URL for the registry
REGISTRY_HOSTNAME=$(oc get route devfile-registry -o jsonpath="{.spec.host}")

echo $REGISTRY_HOSTNAME

# Delete the default devfile registry and add the test one we just stood up
$(realpath odo) registry delete DefaultDevfileRegistry -f
$(realpath odo) registry add TestDevfileRegistry http://$REGISTRY_HOSTNAME

# Run the devfile validation tests
ENV=openshift REGISTRY=remote tests/test.sh $(realpath odo) $YQ_PATH
