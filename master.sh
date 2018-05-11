#!/bin/bash
# Logs stdout and stderr
logFile='/home/k8s_setup_log.txt'
exec >  >(tee -ia $logFile)
exec 2> >(tee -ia $logFile >&2)

# ~~~ All Steps need to be run as root ~~~
# sudo -i

# ----- Update and deploy Docker -----
echo ------------------------------
echo -- Update and deploy Docker --
echo ------------------------------
apt-get update -y && apt-get install docker.io -y && \
docker run docker/whalesay cowsay Docker installation completed!!
echo ----------------------------- DONE STEP 2 deploy Docker -----------------------------

# ----- install kubeadm -----
echo -------------------------------
echo ------ install kubeadm --------
echo -------------------------------

apt-get update && apt-get install -y apt-transport-https curl && \
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update && apt-get install -y kubelet kubeadm kubectl
echo ----------------------------- DONE STEP 4 install kubeadm ---------------------


# ----- config cgroup (master only) -----
echo ------------------------------
echo ------ config cgroup  --------
echo ------------------------------

docker info | grep -i cgroup && \
cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sudo systemctl daemon-reload && sudo systemctl restart kubelet
echo ----------------------------- DONE STEP 5 cgroup ----------------------


# ----- initialize kubeadm master only
echo ------------------------------
echo --- initialize kubeadm  ------
echo ------------------------------

kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=0.0.0.0
echo ----------------------------- DONE STEP 6 initialize kubeadm -------------------------------


# ~~~ Run these from /home/user_folder not user ~~~
# ----- enable kubectl to all users
echo -----------------------------------
echo --- enable kubectl to all users ---
echo -----------------------------------

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes

echo ----------------------------- DONE STEP 7 kubectl to all users -------------------

echo ------------------------------------------------------------------
echo ---------------------- Installing a pod network with Calico ------
echo ------------------------------------------------------------------

kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml

echo ----------------------------- DONE STEP 8 Created Pod Network -------------------