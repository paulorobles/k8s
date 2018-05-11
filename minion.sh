#!/bin/bash

# ----- Update and deploy Docker -----
apt-get update -y && apt-get install docker.io -y && docker run docker/whalesay cowsay Docker installation completed!!

# ----- install kubeadm -----
apt-get update && apt-get install -y apt-transport-https curl && \
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update && apt-get install -y kubelet kubeadm kubectl

# ----- Add nodes to the cluster (minion only)

