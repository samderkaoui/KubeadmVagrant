#!/bin/bash
# -----------------------------------------------------------------------------
# requirements.sh
# - Prépare une VM AlmaLinux/CentOS pour Kubernetes (containerd + kubeadm)
# -----------------------------------------------------------------------------

# Variables
KUBE_REPO_VER="v1.35" # cgroup v2 a partir de 1.31, donc alma 8 en 1.30 et -

# Petite fonction d'affichage pour homogénéiser les étapes (cosmétique uniquement)
info() {
    echo
    echo "============================================================"
    echo " $1"
    echo "============================================================"
    echo
}

info "[TACHE 1] PREREQUIS (paquets , SSH, firewall)"
#sudo dnf update -y
sudo dnf install -y dnf-utils
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install wget git curl vim containerd.io container-selinux kernel-modules kernel-modules-extra -y
sudo systemctl start containerd
sudo systemctl enable containerd

info "[TACHE OPTIM] ALLÉGER ALMALINUX de 150Mb environ"
# Désactivation de services non nécessaires pour alléger l'image
sudo systemctl disable --now firewalld auditd gssproxy irqbalance polkit postfix avahi-daemon cups bluetooth libvirtd rpcbind
#sudo dnf install -y firewalld
#sudo systemctl enable --now firewalld
#sudo firewall-cmd --permanent --add-service=ssh
#sudo firewall-cmd --reload

info "[TACHE 2] MODULES KERNEL ET SYSCTL (Indispensable avant containerd)"
# Chargement des modules nécessaires et réglages sysctl pour Kubernetes
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system >/dev/null 2>&1

info "[TACHE 3] CONFIGURER CONTAINER RUNTIME (CONTAINERD)"
# Création de la config par défaut puis activation de SystemdCgroup
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
# Activation du support Systemd pour les Cgroups
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd

info "[TACHE 4] DISABLE SWAP & SELINUX"
# Désactivation swap et passage de SELinux en permissive (pour kubeadm)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux

info "[TACHE 5] AJOUT K8S REPO"
# Note l'utilisation de KUBE_REPO_VER pour le chemin de l'URL
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/${KUBE_REPO_VER}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${KUBE_REPO_VER}/rpm/repodata/repomd.xml.key
EOF

info "[TACHE 6] INSTALLER KUBEADM, KUBELET, KUBECTL"
# On utilise dnf install sans les versions si on veut la toute dernière du repo
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet
sleep 10

info "[TACHE 7] Clean"
sudo dnf autoremove
sudo dnf clean all
