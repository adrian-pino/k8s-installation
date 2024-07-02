#!/bin/bash
# Install Calico with Kubernetes API datastore, 50 nodes or less:
# ref: https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises
curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml -O
kubectl apply -f calico.yaml

