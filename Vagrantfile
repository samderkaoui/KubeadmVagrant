# -*- mode: ruby -*-
# vi: set ft=ruby :

MASTER_MEMORY = 6144
MASTER_CPUS = 6
WORKER_MEMORY = 2048
WORKER_CPUS = 2
LINKED_CLONE = true
ALMA_VERSION = "10.1.20251125"
IP_MASTER = "192.168.10.100"
IP_WORKER_BASE = "192.168.10."

Vagrant.configure(2) do |config|

  NodeCount = 0 # Changer ici pour ajouter des workers


# Provisioning inline pour /etc/hosts sur TOUTES les machines
  hosts_entries = "#{IP_MASTER} k8s-master\n"
  (1..NodeCount).each { |i| hosts_entries += "#{IP_WORKER_BASE}#{i + 1} k8s-worker#{i}\n" }

  config.vm.provision "shell", inline: <<-SHELL
    cat <<EOF >/etc/hosts
127.0.0.1 localhost
#{hosts_entries}
EOF
  SHELL

  config.vm.provision "shell", path: "install/requirements.sh", privileged: true
  
  # Définition du master
  config.vm.define "master" do |master|
    master.vm.box = "almalinux/10"
    master.vm.box_version = ALMA_VERSION
    master.vm.hostname = "k8s-master"
    master.vm.network "private_network", ip: IP_MASTER
    master.vm.provider "virtualbox" do |vb|
      vb.memory = MASTER_MEMORY
      vb.cpus = MASTER_CPUS
      vb.linked_clone = LINKED_CLONE
    end
    master.vm.provision "shell", path: "install/master.sh", privileged: true
  end
  
  (1..NodeCount).each do |i|
    config.vm.define "worker#{i}" do |node|
      node.vm.box = "almalinux/10"
      node.vm.box_version = ALMA_VERSION
      node.vm.hostname = "k8s-worker#{i}"
      node.vm.network "private_network", ip: "#{IP_WORKER_BASE}#{i + 1}" # worker1: .2, worker2: .3, etc.
      node.vm.provider "virtualbox" do |vb|
        vb.memory = WORKER_MEMORY
        vb.cpus = WORKER_CPUS
        vb.linked_clone = LINKED_CLONE
      end
      node.vm.provision "shell", path: "install/worker.sh", privileged: true
    end
  end


end
