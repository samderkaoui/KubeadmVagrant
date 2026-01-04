#!/bin/bash
# -----------------------------------------------------------------------------
# master.sh
# - Initialise le control-plane Kubernetes via kubeadm et déploie quelques outils
# -----------------------------------------------------------------------------

# Variables
#CALICO_VERSION="3.31.3"
IP_MASTER="192.168.10.100"

# Fonction d'affichage (cosmétique)
info() {
    echo
    echo "************************************************************"
    echo " $1"
    echo "************************************************************"
    echo
}

info "[TACHE 1] INITIALISER LE CLUSTER KUBERNETES"
# Lancement de l'initialisation kubeadm (options inchangées)
sudo kubeadm init --apiserver-advertise-address=$IP_MASTER --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///run/containerd/containerd.sock --v=4

info "[TACHE 2] COPIER LA CONFIGURATION D'ADMIN KUBE DANS LE RÉPERTOIRE .kube DE L'UTILISATEUR VAGRANT"
mkdir /home/vagrant/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
sleep 20

info "[TACHE 3] RETIRER LE TAINT DU MASTER POUR Y DÉPLOYER DES PODS (OPTIONNEL)"
su - vagrant -c "kubectl taint nodes k8s-master node-role.kubernetes.io/control-plane:NoSchedule-"
sleep 5

info "[TACHE 4] DÉPLOYER LE RÉSEAU FLANNEL"
su - vagrant -c "kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"
sleep 5

info "[TACHE 5] CONFIGURER FLANNEL POUR UTILISER LA BONNE INTERFACE RÉSEAU (eth1)"
su - vagrant -c "kubectl patch daemonset kube-flannel-ds -n kube-flannel --type='json' -p='[
  {\"op\": \"add\", \"path\": \"/spec/template/spec/containers/0/args/-\", \"value\": \"--iface=eth1\"}
]'
"

sleep 15

info "[TACHE 6] DÉPLOYER METRICS-SERVER"
su - vagrant -c "kubectl apply -f /vagrant/manifests/metrics-server.yaml"

info "[TACHE 7] GÉNÉRER ET ENREGISTRER LA COMMANDE DE REJOINDRE LE CLUSTER DANS /VAGRANT/JOINCLUSTER.SH"
sudo kubeadm token create --print-join-command > /vagrant/joincluster.sh 2>/dev/null

info "[TACHE 8] INSTALLER K9S (version stable)"
# Téléchargement direct de la dernière version stable (si possible), fallback si pas d'internet
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
if [ -z "$K9S_VERSION" ]; then
    echo "Pas d'accès à GitHub → utilisation d'une version connue stable"
    K9S_VERSION="v0.50.16"
fi

echo "Version k9s détectée/forcée : $K9S_VERSION"

sudo curl -L https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz \
    -o /tmp/k9s.tar.gz

sudo tar -xzf /tmp/k9s.tar.gz -C /tmp k9s
sudo mv /tmp/k9s /usr/local/bin/k9s
sudo chmod +x /usr/local/bin/k9s
rm -f /tmp/k9s.tar.gz

echo "k9s installé avec succès !"
echo "Utilisation : k9s"

info "[TACHE 9] DÉPLOYER LE DASHBOARD KUBERNETES"
su - vagrant -c "kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml"
sleep 15

info "[TACHE 10] CRÉER LE SERVICEACCOUNT ET LE CLUSTERROLEBINDING POUR ACCÉDER AU DASHBOARD"
su - vagrant -c "
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-admin
  namespace: kubernetes-dashboard
EOF
"
su - vagrant -c "
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dashboard-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: dashboard-admin
  namespace: kubernetes-dashboard
EOF
"

info "TACHE 11] Installation kubens et kubectx ohmyzsh"
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
sudo chmod +x /opt/kubectx/kubectx /opt/kubectx/kubens
su - vagrant -c "git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf"
su - vagrant -c "~/.fzf/install --all"
su - vagrant -c "source ~/.bashrc"

sudo dnf install -y zsh

su - vagrant -c 'env CHSH=no RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
sudo usermod -s "$(command -v zsh)" vagrant

sudo cp /vagrant/install/.zshrc /home/vagrant/.zshrc
su - vagrant -c "git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
su - vagrant -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
su - vagrant -c "source /home/vagrant/.zshrc"

info "[TACHE 12] GÉNÉRER LE JETON D'ACCÈS POUR LE DASHBOARD ET L'ENREGISTRER DANS /VAGRANT/TOKEN_DASHBOARD.TXT"
su - vagrant -c "kubectl -n kubernetes-dashboard create token dashboard-admin > /vagrant/token_dashboard.txt"

sudo modprobe br_netfilter