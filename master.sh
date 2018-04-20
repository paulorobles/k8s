#!/bin/bash
# --------- Manual steps --------- 
# --------- Rename host name --------- 
# vi /etc/hostname -> remove current name replace with new node name
# vi /etc/hosts -> remove current name replace with new node name
# shutdown now
# sudo su
# ifconfig endp0s8 <new fix ip>
# vi /etc/network/interfaces
# Configure enp0s8
#	auto endp0s8
#	iface endp0s8 inet static
#		address <new fix ip>		
#		netmask 255.255.255.0
# reboot
# ping www.google.com
# manually add the list to apt-get sources
# apt-get update && apt-get install -y apt-transport-https curl
# apt install curl
# curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
# cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
# deb http://apt.kubernetes.io/ kubernetes-xenial main
# EOF
# apt-get update

# ----- Pre requisites -----
# ----- Disable swapoff -----
swapoff -a
# vi /etc/fstab ----- comment the swap line

# ----- Update and deploy Docker -----
apt-get update -y && apt-get install docker.io -y && docker run docker/whalesay cowsay Docker installation completed!!

# ----- validate SSH installation -----
apt-get install openssh-server -y

# ----- install kubeadm -----
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update && apt-get install -y kubelet kubeadm kubectl

# ----- condig cgroup (master only) -----
docker info | grep -i cgroup
cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
systemctl daemon-reload
systemctl restart kubelet

# ----- initialize kubeadm master only
kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=10.138.0.2
#kubeadm join 10.138.0.2:6443 --token sxgbc5.7km52de9lrn26zry --discovery-token-ca-cert-hash sha256:4d99777b97c0698c4d29ea5702e65d0dd586ee96223cf4a1eb33fc892a7ebbd6

# ----- enable kubectl to all users
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# enable kubectl for sudo su (master only)
export KUBECONFIG=/etc/kubernetes/admin.conf
