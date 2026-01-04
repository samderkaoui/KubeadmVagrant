# vagrant-k8s-kubeadm — AlmaLinux (tested on 8.8)

Tutorial reference: https://www.linuxtechi.com/install-kubernetes-on-rockylinux-almalinux/  
Badges examples: https://gist.github.com/kimjisub/360ea6fc43b82baaf7193175fd12d2f7

---
[![tag](https://img.shields.io/badge/-Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)](none)
[![tag](https://img.shields.io/badge/-VirtualBox-183A61?style=flat&logo=virtualbox&logoColor=white)](none)
[![Vagrant](https://img.shields.io/badge/-Vagrant-1868F2?style=flat&logo=vagrant&logoColor=white)](none)
[![tag](https://img.shields.io/badge/-Shell-FFD500?style=flat&logo=shell&logoColor=white)](none)
[![tag](https://img.shields.io/badge/-AlmaLinux-000000?style=flat&logo=almalinux&logoColor=white)](none)

Overview
--------

This project automates the creation of a complete Kubernetes cluster using Vagrant and VirtualBox, with AlmaLinux nodes. The number of worker nodes is configurable.

Project status

- Distribution: AlmaLinux 8.8 (tested)
  - Latest supported Kubernetes version: 1.30 (distribution uses cgroups v1)
  - Using Flannel for CNI (Calico had issues with VirtualBox interface)
  - firewalld is disabled in provisioning
  - Metric Server installed
  - master.sh now includes untainting of the master node
  - Kubernetes Dashboard installed
  - Auto-install fix for k9s
  - AlmaLinux optimizations and DNF cleanup included
  - kubens / kubectx installed
  - Gateway choice pending (Ingress version outdated; moving to Gateway API — Istio proposed)

To do
- Consider updating to AlmaLinux 9+ (Cilium requires newer kernel)
  - Migrate from Calico to Cilium for an eBPF-based architecture (removes kube-proxy overhead, better visibility via Hubble, and finer-grained L7 security)

Table of Contents
- Quick start
- VirtualBox DHCP fix
- Configuration
  - Adding workers
  - Renaming a worker node
- Machines summary
- Credentials

Quick start

Bring the cluster up:

```bash
vagrant up
```

VirtualBox DHCP issue (host workaround)
If you encounter DHCP issues with VirtualBox, on the host machine:

1. Open the VirtualBox GUI.
2. Go to File → Host Network Manager (or Preferences → Network).
3. Select the vboxnet0 adapter (typically 192.168.56.1).
4. Open the DHCP Server tab.
5. Uncheck "Enable Server" to disable DHCP.
6. Apply the change (OK).

Configuration

Adding worker nodes

Adjust NodeCount in the Vagrantfile to change the number of worker nodes:

```ruby
Vagrant.configure(2) do |config|
  NodeCount = 2  # Change this value to add or remove workers
  # ...existing code...
end
```

Renaming / labeling a worker node

To label a worker node (for example to mark it as a worker role):

```bash
kubectl label nodes worker1 node-role.kubernetes.io/worker=worker
```

Machines summary
- ...existing code... (keep your existing machine list or inventory here)

Credentials
- Username / password for Vagrant boxes: vagrant / vagrant

Notes
- This repository is intended as a lightweight, local Kubernetes lab environment for testing and learning.
- If you plan to migrate to AlmaLinux 9/10 or use Cilium, expect kernel and networking changes; test accordingly.
