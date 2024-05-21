#!/bin/bash
#####################################################################################
# Script to install Kubernetes via kubeadm using containerd as the container runtime.
#####################################################################################
# Tested with Ubuntu 20.04 & Ubuntu 22.04

# VARIABLES
################################
# K8S_VERSION=1.28.2-1.1                                # Needed for master and worker installation
# CONTAINERD_VERSION=1.6.31-1                           # Needed for master and worker installation
# IS_MASTER=true|false                                  # Needed for master and worker installation
# MASTER_NODE_IP=x.x.x.x                        	    # Needed for master installation (not used in worker installation)
# POD_CIDR=172.12.0.0/16      				            # Needed for master installation (not used in worker installation) -> Update it for each new cluster
################################

# Check if mandatory variables are missing
if [ -z "$K8S_VERSION" ] || [ -z "$IS_MASTER" ]; then
    echo "Error: Either K8S_VERSION or IS_MASTER variables are missing. Please set them."
    exit 1
fi

# Check if IS_MASTER is either true or false
if [ "$IS_MASTER" != "true" ] && [ "$IS_MASTER" != "false" ]; then
    echo "IS_MASTER is not set to either 'true' or 'false'."
    exit 1
fi

# Check if IS_MASTER is true, then check if MASTER_NODE_IP or POD_CIDR are missing
if [ "$IS_MASTER" = "true" ] && ([ -z "$MASTER_NODE_IP" ] || [ -z "$POD_CIDR" ]  ); then
    echo "Error: IS_MASTER is set to true but MASTER_NODE_IP and/or POD_CIDR are  missing. Please set them."
    exit 1
fi

###############################
# CRI Installation: Containerd
###############################
# Load overlay & br_netfilter modules
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# Configure systctl to persist
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl parameters
sudo sysctl --system

# Install containerd
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update -y
sudo apt install containerd.io=$CONTAINERD_VERSION -y

# Set the cgroup driver for runc to systemd
# Create the containerd configuration file (containerd by default takes the config looking at /etc/containerd/config.toml)
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/' /etc/containerd/config.toml
# sudo rm /etc/containerd/config.toml

# Restart containerd with the new configuration
sudo systemctl restart containerd

# disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

###############################
# Kubernetes installation
###############################
# Update the apt package index and install packages needed to use the Kubernetes apt repository
sudo apt-get update && sudo apt-get install -y apt-transport-https curl

# Check which versions are available
# apt-cache madison kubelet kubeadm kubectl

K8S_KEY_VERSION=$(echo "$K8S_VERSION" | cut -d'.' -f1-2)
K8S_URL="https://pkgs.k8s.io/core:/stable:/v$K8S_KEY_VERSION/deb/Release.key"

# Download public signing key for the Kubernetes package repository
sudo curl -fsSL "$K8S_URL" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes apt repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_KEY_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# install kubelet, kubeadm and kubectl, and pin their version
sudo apt-get update
sudo apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION
sudo apt-mark hold kubelet kubeadm kubectl

if $IS_MASTER; then
    #--pod-network-cidr=$POD_CIDR
    sudo kubeadm init --apiserver-advertise-address=$MASTER_NODE_IP --pod-network-cidr=$POD_CIDR
    # Once kubeadm has bootstraped the K8s cluster, set proper access to the cluster from the CP/master node
    mkdir -p "$HOME"/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # Untaint master node (in order to run workloads on it (comment it in case this is not the intended behaviour)
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
else
    echo "As a last step, please join the worker to the cluster (use the token obtained in the master after installing it"
fi
