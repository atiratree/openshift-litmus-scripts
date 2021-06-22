#!/bin/env bash

set -e

SCRIPTS_DIR="$(dirname "$(readlink -f "$0")")"


PRIVILEGED_EXPERIMENTS=(pod-network-loss container-kill pod-dns-error)
RESTRICTED_EXPERIMENTS=(pod-delete)

NAMESPACE="$(oc project -q)"

# -l node-role.kubernetes.io/master="" # to filter master nodes
for NODE_NAME in $(oc get nodes --no-headers  |  awk '{print $1}'); do
    echo "activating net emulator in ${NODE_NAME}"
    "${SCRIPTS_DIR}/activate_net_emulator.expect" "$NODE_NAME" &
done

wait

oc apply -f https://litmuschaos.github.io/litmus/litmus-operator-v1.13.5.yaml
oc apply -f https://hub.litmuschaos.io/api/chaos/1.13.5\?file\=charts/generic/experiments.yaml 


for EXPERIMENT in ${RESTRICTED_EXPERIMENTS[@]}; do
    oc apply -f "${SCRIPTS_DIR}/${EXPERIMENT}-sa.yaml"
done

for EXPERIMENT in ${PRIVILEGED_EXPERIMENTS[@]}; do
    oc apply -f "${SCRIPTS_DIR}/${EXPERIMENT}-sa.yaml"
    oc patch scc privileged --type json -p '[{"op":"add","path":"/users/-","value": "system:serviceaccount:'"${NAMESPACE}"':'"${EXPERIMENT}"'-sa"}]'
done

