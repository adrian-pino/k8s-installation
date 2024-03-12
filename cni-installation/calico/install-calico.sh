#!/bin/bash
#####################################################################################
# Script to install Calico CNI
#####################################################################################

# ref: https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises

# VARIABLES
################################
# CALICO_VERSION="v3.26.1"
# POD_CIDR="172.12.0.0/16"         	# Reminder: Provide the same value specified at provisioning time
################################
# Note: POD_CIDR could be checked running (kubectl -n kube-system describe cm kubeadm-config)
# In case no POD_CIDR was specified at kubeadm provisioning time, comment the update step (*).

# Check if POD_CIDR is empty, and if so, print an error and exit
if [ -z "$POD_CIDR" ]; then
    echo "Error: POD_CIDR value not provided."
    exit 1
fi

# Install the operator
echo "Installing the Calico operator..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml

# Download custom resources
echo "Downloading custom resources..."
curl https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources.yaml -o custom-resources.yaml

# Update the custom-resources.yaml with the specified POD_CIDR value
# ------------------------------------------------------------------------
# (*) Comment these lines if no POD_CIDR was specified at kubeadm provisioning time (aka we're using the default CIDR).
echo "Updating custom-resources.yaml with POD_CIDR=$POD_CIDR"
sed -i "s|cidr:.*|cidr: $POD_CIDR|" custom-resources.yaml
# ------------------------------------------------------------------------

# Create the manifest to install Calico
echo "Creating the manifest to install Calico..."
kubectl create -f custom-resources.yaml

# Print message for manual verification
echo ""
echo "Calico installation initiated. You can manually check Calico installation by running:"
echo "kubectl get pods -n calico-system"

