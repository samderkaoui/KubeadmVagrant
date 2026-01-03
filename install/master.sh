#!/bin/bash
# Variables
#CALICO_VERSION="3.31.3"
IP_MASTER="192.168.10.100"

#echo "[TACHE 1] PREREQUIS FIREWALLD"
#sudo firewall-cmd --permanent --add-service=ssh
#sudo firewall-cmd --permanent --add-port={6443,2379,2380,10250,10251,10252,10257,10259,179}/tcp
#sudo firewall-cmd --reload


echo "[TACHE 2] INITIALISER LE CLUSTER KUBERNETES"
sudo kubeadm init --apiserver-advertise-address=$IP_MASTER --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///run/containerd/containerd.sock --v=4

echo "[TACHE 3] COPIER LA CONFIGURATION D'ADMIN KUBE DANS LE RÉPERTOIRE .kube DE L'UTILISATEUR VAGRANT"
mkdir /home/vagrant/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
sleep 20

echo "[TACHE 4] RETIRER LE TAINT DU MASTER POUR Y DÉPLOYER DES PODS (OPTIONNEL)"
su - vagrant -c "kubectl taint nodes k8s-master node-role.kubernetes.io/control-plane:NoSchedule-"
sleep 5

echo "[TACHE 5] DÉPLOYER LE RÉSEAU FLANNEL"
su - vagrant -c "kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"
sleep 5

echo "[TACHE 6] CONFIGURER FLANNEL POUR UTILISER LA BONNE INTERFACE RÉSEAU (eth1)"
su - vagrant -c "kubectl patch daemonset kube-flannel-ds -n kube-flannel --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--iface=eth1"}
]'
"

sleep 15

echo "[TACHE 7] DÉPLOYER METRICS-SERVER"
su - vagrant -c "kubectl apply -f /vagrant/manifests/metrics-server.yaml"

echo "[TACHE 8] GÉNÉRER ET ENREGISTRER LA COMMANDE DE REJOINDRE LE CLUSTER DANS /VAGRANT/JOINCLUSTER.SH"
sudo kubeadm token create --print-join-command > /vagrant/joincluster.sh 2>/dev/null

# echo "[TACHE 9] INSTALLER K9S"
# su - vagrant -c "curl -sS https://webi.sh/k9s | sh"
# su - vagrant -c "source ~/.config/envman/PATH.env"

echo "[TACHE 9] INSTALLER K9S (version stable)"

# Téléchargement direct de la dernière version stable (au 02 jan 2026 : v0.32.5, mais on prend latest)
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
# Si pas d'internet, on force une version connue stable
if [ -z "$K9S_VERSION" ]; then
    echo "Pas d'accès à GitHub → utilisation d'une version connue stable"
    K9S_VERSION="v0.32.5"
fi

echo "Version k9s détectée/forcée : $K9S_VERSION"

sudo curl -L https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz \
    -o /tmp/k9s.tar.gz

sudo tar -xzf /tmp/k9s.tar.gz -C /tmp k9s
sudo mv /tmp/k9s /usr/local/bin/k9s
sudo chmod +x /usr/local/bin/k9s
# Nettoyage
rm -f /tmp/k9s.tar.gz

echo "k9s installé avec succès !"
echo "Utilisation : k9s"


echo "[TACHE 10] DÉPLOYER LE DASHBOARD KUBERNETES"
su - vagrant -c "kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml"
sleep 15

echo "[TACHE 11] CRÉER LE SERVICEACCOUNT ET LE CLUSTERROLEBINDING POUR ACCÉDER AU DASHBOARD"
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

echo "TACHE 12] Installation kubens et kubectx ohmyzsh"
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
# Optionnel mais recommandé : rendre exécutables (au cas où)
sudo chmod +x /opt/kubectx/kubectx /opt/kubectx/kubens
# fzf pour le mode interactif (fortement recommandé !)
su - vagrant -c "git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf"
su - vagrant -c "~/.fzf/install --all"
su - vagrant -c "source ~/.bashrc"

# Installer zsh non-interactivement (package)
sudo dnf install -y zsh

# Installer oh-my-zsh pour l'utilisateur vagrant sans interaction :
# - CHSH=no empêche le script de tenter de changer le shell lui-même (évite la question interactive)
# - RUNZSH=no empêche le script de lancer zsh immédiatement
# On exécute en tant que vagrant pour que les fichiers soient créés dans /home/vagrant
su - vagrant -c 'env CHSH=no RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'

# Forcer le changement de shell pour l'utilisateur vagrant vers zsh (non-interactif)
# Utilise usermod pour être sûr que le shell est bien modifié
sudo usermod -s "$(command -v zsh)" vagrant

sudo cp /vagrant/install/.zshrc /home/vagrant/.zshrc
su - vagrant -c "git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
su - vagrant -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
su - vagrant -c "source /home/vagrant/.zshrc"

# Remarques :
# - Si vous souhaitez préserver un fichier ~/.zshrc existant, appelez l'installateur avec
#   KEEP_ZSHRC=yes (ex: env CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh -c "...").
# - Le changement de shell est appliqué dans /etc/passwd immédiatement ; pour que
#   la session SSH en cours utilise le nouveau shell, reconnectez-vous (log out / log in).

echo "[TACHE 13] GÉNÉRER LE JETON D'ACCÈS POUR LE DASHBOARD ET L'ENREGISTRER DANS /VAGRANT/TOKEN_DASHBOARD.TXT"
su - vagrant -c "kubectl -n kubernetes-dashboard create token dashboard-admin > /vagrant/token_dashboard.txt"

sudo modprobe br_netfilter