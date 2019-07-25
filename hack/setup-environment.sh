#!/usr/bin/env bash

# Copyright 2019 The Knative Authors.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set -o errexit
set -o nounset
set -o pipefail

export CURRENT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/..
export KNATIVE_SERVING_DIR="${GOPATH}/src/knative.dev/serving"
# Update this env to point to the correct docker hub
export KO_DOCKER_REPO=docker.io/tommylike

function check-prerequisites {
  echo "checking prerequisites"
  which kubectl >/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    echo "kubectl not installed, exiting."
    exit 1
  else
    echo -n "found kubectl, " && kubectl version --short --client
  fi

  echo "checking kind"
  which kind >/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    echo "installing kind ."
    GO111MODULE="on" go get sigs.k8s.io/kind@v0.4.0
  else
    echo -n "found kind, version: " && kind version
  fi

  echo "checking ko"
  which ko >/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    echo "installing ko"
    go get github.com/google/ko/cmd/ko
  else
    echo -n "found ko, version: " && ko version
  fi
}

function kind-cluster-up {
    kind create cluster --config "${CURRENT_DIR}/hack/kind-config.yaml" --name "kind"  --wait "200s"
}


function install-istio {

    echo "installing istio crds"
    kubectl apply -f "${KNATIVE_SERVING_DIR}/third_party/istio-1.2-latest/istio-crds.yaml"
    while [[ $(kubectl get crd gateways.networking.istio.io -o jsonpath='{.status.conditions[?(@.type=="Established")].status}') != 'True' ]]; do
        echo "Waiting on Istio CRDs"; sleep 2
    done
    echo "installing istio services (NodePort)"
    cat "${KNATIVE_SERVING_DIR}/third_party/istio-1.2-latest/istio.yaml" | sed 's/LoadBalancer/NodePort/' | kubectl apply -f -
}

function install-cert-manager {
    echo "installing cert manager crds"
    kubectl apply -f "${KNATIVE_SERVING_DIR}/third_party/cert-manager-0.6.1/cert-manager-crds.yaml"
    while [[ $(kubectl get crd certificates.certmanager.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Established")].status}') != 'True' ]]; do
        echo "Waiting on Cert-Manager CRDs"; sleep 2
    done
    echo "installing cert manager services"
    kubectl apply -f "${KNATIVE_SERVING_DIR}/third_party/cert-manager-0.6.1/cert-manager.yaml" "--validate=false"
}

function install-knative-serving {
    echo "build and install knative serving...."
    ko apply -f "${KNATIVE_SERVING_DIR}/config/" -f "${KNATIVE_SERVING_DIR}/config/v1beta1"
    echo "installing sample knative service"
    kubectl apply -f "${CURRENT_DIR}/hack/knative-serving.yaml"
    echo "waiting 60s until hello world is running."
    sleep 60
    echo "Get NodePort for 80 port"
    NODEPORT=`kubectl get svc istio-ingressgateway --namespace istio-system -o 'jsonpath={.spec.ports[?(@.port==80)].nodePort}'`
    echo "Get NodeIP for hello world service"
    NODEIP=`kubectl get node  --output 'jsonpath={.items[0].status.addresses[0].address}'`
    echo "Get host name for hello world service"
    SAMPLE_HOST=`kubectl get route helloworld-go --output 'jsonpath={.status.url}' | sed 's/http:\/\//''/'`
    echo "====================Knative development env has been successfully initialized===================="
    echo "Usage: Please follow these commands below:
[Refresh K8s config]: export KUBECONFIG=\"$(kind get kubeconfig-path --name=\"kind\")\"
[Try hello world service]: curl -H \"Host: ${SAMPLE_HOST}\" http://${NODEIP}:${NODEPORT}
[DockerRepo]: ${KO_DOCKER_REPO}
[RePublish Knative serving components]: ko apply -f \"${KNATIVE_SERVING_DIR}/config/\" -f \"${KNATIVE_SERVING_DIR}/config/v1beta1\"
[Delete kind clusters]: kind delete cluster  --name kind"

}

echo "Preparing environment for knative developing......"

check-prerequisites

kind-cluster-up

install-istio

install-cert-manager

install-knative-serving
