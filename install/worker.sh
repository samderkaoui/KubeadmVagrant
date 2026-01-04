#!/bin/bash
# -----------------------------------------------------------------------------
# worker.sh
# - Script pour l'ajout d'un nœud worker au cluster créé par master.sh
# -----------------------------------------------------------------------------

info() {
    echo
    echo "------------------------------------------------------------"
    echo " $1"
    echo "------------------------------------------------------------"
    echo
}

info "[TACHE 1] REJOINDRE LE NŒUD AU CLUSTER KUBERNETES"
# Exécute le script généré par le master pour rejoindre le cluster
bash /vagrant/joincluster.sh 2>/dev/null

echo "===================================="
echo 'run command: vagrant ssh master -c "kubectl get nodes -o wide"'
echo "===================================="
