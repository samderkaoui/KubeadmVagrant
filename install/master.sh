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

info "[TACHE 4] DÉPLOYER LE RÉSEAU CALICO"
su - vagrant -c "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/calico.yaml"
sleep 35

info "[TACHE 5] CONFIGURER CALICO POUR UTILISER LA BONNE INTERFACE RÉSEAU (eth1)"
kubectl -n kube-system set env daemonset calico-node \
  IP_AUTODETECTION_METHOD="interface=eth1"
sleep 5
kubectl -n kube-system rollout restart daemonset calico-node
sleep 30

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



# Tu as déjà le ServiceAccount + ClusterRoleBinding, il te manque juste le jeton (Bearer Token) à coller dans le dashboard. Voici les deux façons usuelles, selon ta version de `kubectl`.

# ## Méthode 1 : `kubectl create token` (recommandée, K8s récents)

# Sur un cluster récent (1.24+), tu peux simplement faire :

# ```bash
# su - vagrant -c "kubectl -n kubernetes-dashboard create token dashboard-admin"
# ```

# La sortie est directement le token à copier/coller dans le champ « Token » du Kubernetes Dashboard (sans guillemets, juste la chaîne).[1][2][3][4]

# ## Méthode 2 : via Secret du ServiceAccount (clusters plus anciens)

# Si `kubectl create token` n’existe pas, tu peux récupérer le token stocké dans le Secret associé :

# 1. Récupérer le nom du Secret lié au SA :

# ```bash
# su - vagrant -c "kubectl -n kubernetes-dashboard get sa dashboard-admin -o jsonpath='{.secrets[0].name}'"
# ```

# 2. Afficher le token (base64 → clair) :

# ```bash
# SECRET_NAME=$(su - vagrant -c "kubectl -n kubernetes-dashboard get sa dashboard-admin -o jsonpath='{.secrets[0].name}'")

# su - vagrant -c "kubectl -n kubernetes-dashboard get secret $SECRET_NAME -o jsonpath='{.data.token}'" | base64 --decode
# ```

# La valeur décodée est le Bearer Token à coller dans le formulaire de login du Dashboard.[5][6][2][7][8]

# Dans le Dashboard, tu choisis « Token », tu colles la valeur et tu valides.[4]

# [1](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_token/)
# [2](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
# [3](https://docs.stakepool.dev.br/polygon/kubernetes/access-the-kubernetes-dashboard)
# [4](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
# [5](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/)
# [6](https://stackoverflow.com/questions/50553233/how-to-log-in-to-kubernetes-dashboard-ui-with-service-accounts-token)
# [7](https://labex.io/questions/how-to-get-the-token-for-kubernetes-dashboard-admin-user-23734)
# [8](https://www.ibm.com/docs/en/cloud-private/3.2.x?topic=kubectl-using-service-account-tokens-connect-api-server)
# [9](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md)
# [10](https://kubernetes.io/blog/2026/01/07/kubernetes-v1-35-csi-sa-tokens-secrets-field-beta/)

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