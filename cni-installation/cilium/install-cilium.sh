#!/bin/bash

# VARIABLES
################################
MASTER_NODE_IP=X.Y.Z.T
POD_CIDR=A.B.C.D/E
REPLICAS=2
################################

helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium \
    --namespace kube-system \
    --set ipam.mode=cluster-pool \
    --set ipam.operator.clusterPoolIPv4PodCIDRList=$POD_CIDR \
    --set k8sServiceHost=$MASTER_NODE_IP \
    --set k8sServicePort=6443 \
    --set operator.replicas=$REPLICAS
