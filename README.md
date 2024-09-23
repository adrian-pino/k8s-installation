# Steps to provision a Kubernetes cluster

First, clone the repo **inside each node** that conform the cluster:

```bash
git clone https://github.com/adrian-pino/k8s-installation.git
```

## Install kubernetes using kubeadm

### Installing the Control Plane

First, set up variables from `install-k8s-kubeadm.sh` script. Those are the variables for the control plane

```bash
# VARIABLES
################################
K8S_VERSION=1.30.2-1.1      # Needed for master and worker installation
CONTAINERD_VERSION=1.6.31-1 # Needed for master and worker installation
IS_MASTER=true              # Needed for master and worker installation
MASTER_NODE_IP=172.28.5.51  # Needed for master installation (not used in worker installation)
POD_CIDR=172.25.0.0/16      # Needed for master installation (not used in worker installation) -> Update it for each new cluster
################################
```

Now, run the script **inside the control plane node**:

```bash
ubuntu@test-vm-1:~/k8s-installation/cluster-installation$ ./install-k8s-kubeadm.sh 
```

After the control plane node is installed, keep the following ouptut of the script, we will use that later in the workers so they can join the cluster.

```
Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.28.5.51:6443 --token eu25z4.m0k8kd1w1kci9r47 \
	--discovery-token-ca-cert-hash sha256:f8ee2bb4de30e945640ebb08280e68108bb54e3821cfa3e426d153f627156acb 
node/test-vm-1 untainted
```

> [!WARNING]
> W0923 08:01:25.061658  128355 checks.go:844] detected that the sandbox image "registry.k8s.io/pause:3.6" of the container runtime is inconsistent with that used by kubeadm.It is recommended to use "registry.k8s.io/pause:3.9" as the CRI sandbox image.

### Add a worker in the cluster

Now, let's install the worker. We run the same scripts but adjust the variables accordingly:

```bash
# VARIABLES
################################
K8S_VERSION=1.30.2-1.1                                # Needed for master and worker installation
CONTAINERD_VERSION=1.6.31-1                           # Needed for master and worker installation
IS_MASTER=false                                  # Needed for master and worker installation
# MASTER_NODE_IP= X.X.X.X                                 # Needed for master installation (not used in worker installation)
# POD_CIDR=X.X.X.X                                              # Needed for master installation (not used in worker installation) -> Update it for each new cluster
################################
```

Now, we run the script again **inside the worker node**:

```bash
ubuntu@test-vm-2:~/k8s-installation/cluster-installation$ ./install-k8s-kubeadm.sh 
```

We can consider that the script run successfully if we see the following output:

```
***************************************************************************************************************
Congratulations! at this point, Kubernetes elements should be installed within this node
As a last step, please join the worker to the cluster (use the token obtained in the master after installing it
***************************************************************************************************************
```

After the script runs successfully, we can add now the worker to the cluster. To do so, we need to copy the output from the control plane installation. You need to be **root** so it runs successfully.

```bash
ubuntu@test-vm2:~/k8s-installation/cluster-installation$ sudo kubeadm join 172.28.5.51:6443 --token eu25z4.m0k8kd1w1kci9r47 --discovery-token-ca-cert-hash sha256:f8ee2bb4de30e945640ebb08280e68108bb54e3821cfa3e426d153f627156acb 
```

If everything went fine, we should see an output like this.

```
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-check] Waiting for a healthy kubelet. This can take up to 4m0s
[kubelet-check] The kubelet is healthy after 1.001644s
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

## Adding extra workers

If we want to add extra workers, we just need to repeat the process from [previous section](#add-a-worker-in-the-cluster).

## Configuring Cilium as CNI

Now, we have our cluster with all the nodes enrolled into it. But if we take a look at the `kubectl get nodes` command (run in the control plane node) we can see that the nodes look as not ready:

```bash
ubuntu@test-vm-1:~$ kubectl get nodes
NAME        STATUS     ROLES           AGE     VERSION
test-vm-1   NotReady   control-plane   18m     v1.30.2
test-vm-3   NotReady   <none>          3s      v1.30.2
test-vm2    NotReady   <none>          4m37s   v1.30.2
```

This is because we need a CNI plugin to provide connectivity between pods running in each node. To do so, first we need to install helm as a dependency. [Helm](https://helm.sh/) is basically a package manager for kubernetes. To do so, we can use the script located in this repo:

```bash
ubuntu@test-vm-1:~$ k8s-installation/cni-installation/cilium/install-helm.sh 
Downloading https://get.helm.sh/helm-v3.16.1-linux-amd64.tar.gz
Verifying checksum... Done.
Preparing to install helm into /usr/local/bin
helm installed into /usr/local/bin/helm
```

Now, update the variables inside the `install-cilium.sh` script:

```bash
# VARIABLES
################################
MASTER_NODE_IP=172.28.5.51
POD_CIDR=172.25.0.0/16
################################
```

Now, run the script in all the nodes:

```
ubuntu@test-vm-1:~/k8s-installation/cni-installation/cilium$ ./install-cilium.sh 
"cilium" has been added to your repositories
NAME: cilium
LAST DEPLOYED: Mon Sep 23 10:11:11 2024
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
You have successfully installed Cilium with Hubble.

Your release version is 1.16.1.

For any further help, visit https://docs.cilium.io/en/v1.16/gettinghelp
```

Now, if we check again the nodes, all the nodes on the cluster should look as `Ready`:

```
ubuntu@test-vm-1:~/k8s-installation/cni-installation/cilium$ kubectl get nodes
NAME        STATUS   ROLES           AGE    VERSION
test-vm-1   Ready    control-plane   131m   v1.30.2
test-vm-3   Ready    <none>          112m   v1.30.2
test-vm2    Ready    <none>          116m   v1.30.2
```

