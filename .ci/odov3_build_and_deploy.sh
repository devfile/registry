#!/bin/bash

#
# Copyright Red Hat
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Share docker env with minikube
eval $(minikube docker-env)

# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail
# error on unset variables
set -u
# print each command before executing it
set -x

# Disable telemtry for odo
export ODO_DISABLE_TELEMETRY=true

# Disable image pushing for odo by default
export ODO_PUSH_IMAGES=${ODO_PUSH_IMAGES:-'false'}

# Split the registry image and image tag from the REGISTRY_IMAGE env variable
IMG="$(echo $REGISTRY_IMAGE | cut -d':' -f1)"
TAG="$(echo $REGISTRY_IMAGE | cut -d':' -f2)"

# Set namespace
NAMESPACE=${NAMESPACE:-'devfile-registry-test'}
# Set pull policy of REGISTRY_IMAGE
PULL_POLICY=${PULL_POLICY:-'Always'}

# Fail if odo is not installed
if [ -z $(command -v odo 2> /dev/null) ]; then
    echo "install odo."
    exit 1
fi

# Create testing namespace if does not exist, otherwise set to testing namespace
if [ -z $(kubectl describe namespace/${NAMESPACE} 2> /dev/null) ]; then
    odo create namespace ${NAMESPACE}
else
    odo set namespace ${NAMESPACE}
fi

# Wait for ingress to be ready
kubectl wait pods -l app.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller --namespace ingress-nginx --for=condition=Ready --timeout=600s

# Deploy devfile registry using odo v3
odo deploy --var hostName=${NAMESPACE}.$(minikube ip).nip.io \
    --var hostAlias=${NAMESPACE}.$(minikube ip).nip.io \
    --var indexImageName=${IMG} \
    --var indexImageTag=${TAG} \
    --var indexPullPolicy=${PULL_POLICY}

# Wait for deployment to be ready
kubectl wait deploy/devfile-registry --for=condition=Available --timeout=600s
if [ $? -ne 0 ]; then
    # Return the logs of the 3 containers in case the condition is not met
    echo "devfile-registry container logs:"
    kubectl logs -l app=devfile-registry --container devfile-registry
    echo "oci-registry container logs:"
    kubectl logs -l app=devfile-registry --container oci-registry
    echo "registry-viewer container logs:"
    kubectl logs -l app=devfile-registry --container registry-viewer
    # Return the description of every pod
    kubectl describe pods

    odo delete component --name devfile-registry-community --force

    exit 1
fi

# Get status code, retry for 5 times until status code is 200 otherwise fail
STATUS_CODE=$(curl --fail --retry 5 -o /dev/null -s -w "%{http_code}\n" "http://${NAMESPACE}.$(minikube ip).nip.io/health")
if [ ${STATUS_CODE} -ne 200 ]; then
    echo "unexpected status code ${STATUS_CODE}, was expecting 200"

    odo delete component --name devfile-registry-community --force

    exit 1
else
    odo delete component --name devfile-registry-community --force
fi
