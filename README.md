# vagrant-k8s-kubeadm - ALMALINUX 8 & 10

`tutorial install : https://www.linuxtechi.com/install-kubernetes-on-rockylinux-almalinux/`

`badges : https://gist.github.com/kimjisub/360ea6fc43b82baaf7193175fd12d2f7`

---
[![tag](https://img.shields.io/badge/-Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)](none)
[![tag](https://img.shields.io/badge/-VirtualBox-183A61?style=flat&logo=virtualbox&logoColor=white)](none)
[![Vagrant](https://img.shields.io/badge/-Vagrant-1868F2?style=flat&logo=vagrant&logoColor=white)](none)
[![tag](https://img.shields.io/badge/-Shell-FFD500?style=flat&logo=shell&logoColor=white)](none)
[![tag](https://img.shields.io/badge/-AlmaLinux-000000?style=flat&logo=almalinux&logoColor=white)](none)

## Overview

This project aims to install a complete K8s cluster with a configurable number of workers.

Project status:

- [x] Distribution: AlmaLinux 8.8/8.10 (old / Branch alma8-Flannel)
  - [x] Latest Kubernetes version **(1.30)** supported by the distribution (because cgroups v1)
  - [x] Use of Flannel (Calico error with VirtualBox interface — too lazy to dig => Cilium on AlmaLinux 10 :) )
  - [x] Disable firewalld
  - [x] Add Metrics Server
  - [x] Add in master.sh script: Un-Taint master node
  - [x] Add Kubernetes Dashboard
  - [x] Fix auto-install of k9s
  - [x] Optimize AlmaLinux and clean DNF
  - [x] Add kubens/kubectx


- [x] Distribution: AlmaLinux 10 (because Cilium requires Kernel 5+ and AlmaLinux 8 is on 4.x)
  - [x] Make scripts cleaner
  - [ ] Choose a Gateway (Ingress too old, switching to the Gateway API! 🚀) => Traefik
  - [ ] Switch from Calico to Cilium to move to a lighter, higher-performance eBPF architecture: this reduces system overhead by replacing kube-proxy, will eliminate iptables slowness, provide full visibility into traffic with Hubble, and secure flows at the application layer (L7, more granular, with HTTP, requests etc.) rather than by simple IP addresses
---

> **Table of Contents**:
>
> * [Starting the cluster](#installer-cluster)
> * [Configuration](#configuration)
>   * [Adding workers](#ajout-workers)
>   * [Change worker name](#changement-nom-worker)
> * [Machines summary](#recapitulatif-machines)
---

## Starting the cluster

```ruby
vagrant up
```

```bash
# Fix DHCP issues on VirtualBox
1- Open the VirtualBox GUI on your host (Ubuntu).
2- Go to File → Host Network Manager (or Preferences → Network on some versions).
3- Select the vboxnet0 interface (the one with 192.168.56.1).
4- Click on the DHCP Server tab.
5- Uncheck "Enable Server" (disable the DHCP).
6- Apply (OK).
```

## Configuration

### Adding workers

Change NodeCount in the Vagrantfile
```ruby
Vagrant.configure(2) do |config|

  NodeCount = 2  # Change here to add workers
```

### Change worker name (if needed)
```bash
kubectl label nodes worker1 node-role.kubernetes.io/worker=worker
```

## Id/pw of VM's
vagrant/vagrant
