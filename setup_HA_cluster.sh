#!/bin/bash
# ----- Pre requisites -----
# ----- Get Hostname and IP -----
echo -----------------------------
echo --- get initial variables ---
echo -----------------------------
export PEER_NAME=$(hostname)
export PRIVATE_IP=$(ip addr show ens4 | grep -Po 'inet \K[\d.]+')
echo $PEER_NAME
echo $PRIVATE_IP
echo $USER
echo ----------------------------- DONE STEP 1 initial variables --------------------

# ----- Start setting up to HA cluster ----- #
echo --------------------------------------
echo --- Start setting up to HA cluster ---
echo --------------------------------------

export USER=$(whoami) && \
chown $USER /usr/local/bin/ && \
curl -o /usr/local/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 &&  \
curl -o /usr/local/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 && \
chmod +x /usr/local/bin/cfssl*
echo ----------------------------- DONE STEP 2 HA cluster -----------------


mkdir -p /etc/kubernetes/pki/etcd && \
cd /etc/kubernetes/pki/etcd
cat >ca-config.json <<EOF
{
    "signing": {
        "default": {
            "expiry": "43800h"
        },
        "profiles": {
            "server": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            },
            "client": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            },
            "peer": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
EOF

cat >ca-csr.json <<EOF
{
    "CN": "etcd",
    "key": {
        "algo": "rsa",
        "size": 2048
    }
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca -

cat >client.json <<EOF
{
    "CN": "client",
    "key": {
        "algo": "ecdsa",
        "size": 256
    }
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client client.json | cfssljson -bare client

ssh-keygen -t rsa -b 4096 -C "paulo.roblesglz@gmail.com"
echo -ne '\n'
echo -ne '\n'
echo -ne '\n'

cat ~/.ssh/id_rsa.pub

#To be ran only in guest master nodes!!
#mkdir -p /etc/kubernetes/pki/etcd
#cd /etc/kubernetes/pki/etcd
#scp root@10.142.0.4:/etc/kubernetes/pki/etcd/ca.pem .
#scp root@10.142.0.4:/etc/kubernetes/pki/etcd/ca-key.pem .
#scp root@10.142.0.4:/etc/kubernetes/pki/etcd/client.pem .
#scp root@10.142.0.4:/etc/kubernetes/pki/etcd/client-key.pem .
#scp root@10.142.0.4:/etc/kubernetes/pki/etcd/ca-config.json .

cfssl print-defaults csr > config.json
sed -i '0,/CN/{s/example\.net/'"$PEER_NAME"'/}' config.json
sed -i 's/www\.example\.net/'"$PRIVATE_IP"'/' config.json
sed -i 's/example\.net/'"$PEER_NAME"'/' config.json

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server config.json | cfssljson -bare server
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=peer config.json | cfssljson -bare peer

export ETCD_VERSION=v3.1.12
curl -sSL https://github.com/coreos/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz | tar -xzv --strip-components=1 -C /usr/local/bin/
rm -rf etcd-$ETCD_VERSION-linux-amd64*

touch /etc/etcd.env
echo "PEER_NAME=$PEER_NAME" >> /etc/etcd.env
echo "PRIVATE_IP=$PRIVATE_IP" >> /etc/etcd.env


# --------- To run only on host master ----
#cat >/etc/systemd/system/etcd.service <<EOF
#[Unit]
#Description=etcd
#Documentation=https://github.com/coreos/etcd
#Conflicts=etcd.service
#Conflicts=etcd2.service
#
#[Service]
#EnvironmentFile=/etc/etcd.env
#Type=notify
#Restart=always
#RestartSec=5s
#LimitNOFILE=40000
#TimeoutStartSec=0
#
#ExecStart=/usr/local/bin/etcd --name ${PEER_NAME} \
#    --data-dir /var/lib/etcd \
#    --listen-client-urls https://${PRIVATE_IP}:2379 \
#    --advertise-client-urls https://${PRIVATE_IP}:2379 \
#    --listen-peer-urls https://${PRIVATE_IP}:2380 \
#    --initial-advertise-peer-urls https://${PRIVATE_IP}:2380 \
#    --cert-file=/etc/kubernetes/pki/etcd/server.pem \
#    --key-file=/etc/kubernetes/pki/etcd/server-key.pem \
#    --client-cert-auth \
#    --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.pem \
#    --peer-cert-file=/etc/kubernetes/pki/etcd/peer.pem \
#    --peer-key-file=/etc/kubernetes/pki/etcd/peer-key.pem \
#    --peer-client-cert-auth \
#    --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.pem \
#    --initial-cluster k8sfed-z5sh=https://10.142.0.4:2380,k8sfed-8jwm=https://10.142.0.5:2380 \
#    --initial-cluster-token my-etcd-token \
#    --initial-cluster-state new
#
#[Install]
#WantedBy=multi-user.target
#EOF
#
#systemctl daemon-reload
#systemctl start etcd
#systemctl status etcd
#
#cat >config.yaml <<EOF
#apiVersion: kubeadm.k8s.io/v1alpha1
#kind: MasterConfiguration
#api:
#  advertiseAddress: 10.142.0.4
#etcd:
#  endpoints:
#  - https://10.142.0.4:2379 #for master01
#  - https://10.142.0.5:2379 #for master..n
#  caFile: /etc/kubernetes/pki/etcd/ca.pem
#  certFile: /etc/kubernetes/pki/etcd/client.pem
#  keyFile: /etc/kubernetes/pki/etcd/client-key.pem
#networking:
#  podSubnet: <podCIDR>
#apiServerCertSANs:
#- <load-balancer-ip>
#apiServerExtraArgs:
#  apiserver-count: "2" # represents the count of masters
#EOF

#kubeadm init --config=config.yaml

# ---------- to run on guest masters only
#scp root@<master0-ip-address>:/etc/kubernetes/pki/* /etc/kubernetes/pki
#rm apiserver.*

