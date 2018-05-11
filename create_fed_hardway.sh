gcloud container clusters create asia-east1-b --zone asia-east1-b \
--scopes "cloud-platform,storage-ro,logging-write,monitoring-write,service-control,service-management,https://www.googleapis.com/auth/ndev.clouddns.readwrite"

gcloud container clusters create europe-west1-b --zone=europe-west1-b \
--scopes "cloud-platform,storage-ro,logging-write,monitoring-write,service-control,service-management,https://www.googleapis.com/auth/ndev.clouddns.readwrite"

gcloud container clusters create us-east1-b --zone=us-east1-b \
--scopes "cloud-platform,storage-ro,logging-write,monitoring-write,service-control,service-management,https://www.googleapis.com/auth/ndev.clouddns.readwrite"

gcloud container clusters create us-central1-b --zone=us-central1-b \
--scopes "cloud-platform,storage-ro,logging-write,monitoring-write,service-control,service-management,https://www.googleapis.com/auth/ndev.clouddns.readwrite"

#Save the cluster creds
for cluster in asia-east1-b europe-west1-b us-east1-b us-central1-b; do
  gcloud container clusters get-credentials ${cluster} \
  --zone ${cluster}
done

#Create Cluster Contexts
GCP_PROJECT=$(gcloud config list --format='value(core.project)')

#Create context aliases:

for cluster in asia-east1-b europe-west1-b us-east1-b us-central1-b; do
  kubectl config set-context ${cluster} \
    --cluster=gke_${GCP_PROJECT}_${cluster}_${cluster} \
    --user=gke_${GCP_PROJECT}_${cluster}_${cluster}
done

#Create the host cluster context:

HOST_CLUSTER=us-central1-b
kubectl config set-context host-cluster \
  --cluster=gke_${GCP_PROJECT}_${HOST_CLUSTER}_${HOST_CLUSTER} \
  --user=gke_${GCP_PROJECT}_${HOST_CLUSTER}_${HOST_CLUSTER} \
  --namespace=federation

#Verify
gcloud container clusters list


#Create a Google DNS Managed Zone
gcloud dns managed-zones create federation \
  --description "Kubernetes federation testing" \
  --dns-name testkubernetes.com

#Provision Federated API Server
#Pre-Req
kubectl config use-context host-cluster

#Create the Federation Namespace
kubectl create -f ns/federation.yaml

#Create the Federated API Server Service
kubectl create -f services/federation-apiserver.yaml

#Validate
kubectl get services --all-namespaces

#Create the Federation API Server Secret
FEDERATION_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
cat > known-tokens.csv <<EOF
${FEDERATION_TOKEN},admin,admin
EOF

#Create the federation-apiserver-secrets
kubectl create secret generic federation-apiserver-secrets --from-file=known-tokens.csv

kubectl describe secrets federation-apiserver-secrets

#Federation API Server Deployment
#Create a Persistent Volume Claim
#Create a persistent disk for the federated API server:
kubectl create -f pvc/federation-apiserver-etcd.yaml

#Verify
kubectl get pvc
kubectl get pv

#Create the Deployment
kubectl create configmap federated-apiserver \
  --from-literal=advertise-address=$(kubectl \
    get services federation-apiserver \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

kubectl get configmap federated-apiserver \
  -o jsonpath='{.data.advertise-address}'
Create the federated API server:

kubectl create -f deployments/federation-apiserver.yaml

#Verify
kubectl get deployments --all-namespaces
kubectl get pods --all-namespaces

#Provision Federated Controller Manager
#Prerequisites
kubectl config use-context host-cluster

#Create the Federated API Server Kubeconfig
kubectl config set-cluster federation-cluster \
  --server=https://$(kubectl get services federation-apiserver \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}') \
  --insecure-skip-tls-verify=true

#Get the token from the known-tokens.csv file:
FEDERATION_TOKEN=$(cut -d"," -f1 known-tokens.csv)
kubectl config set-credentials federation-cluster \
  --token=${FEDERATION_TOKEN}
kubectl config set-context federation-cluster \
  --cluster=federation-cluster \
  --user=federation-cluster

#Switch to the federation-cluster context and dump the federated API server credentials:
kubectl config use-context federation-cluster
mkdir -p kubeconfigs/federation-apiserver
kubectl config view --flatten --minify > kubeconfigs/federation-apiserver/kubeconfig

#Create the Federated API Server Secret
kubectl config use-context host-cluster
kubectl create secret generic federation-apiserver-kubeconfig \
  --from-file=kubeconfigs/federation-apiserver/kubeconfig

#Verify
kubectl describe secrets federation-apiserver-kubeconfig

#Deploy the Federated Controller Manager
DNS_ZONE_NAME=$(gcloud dns managed-zones describe federation --format='value(dnsName)')
DNS_ZONE_ID=$(gcloud dns managed-zones describe federation --format='value(id)')
kubectl create configmap federation-controller-manager \
  --from-literal=zone-id=${DNS_ZONE_ID} \
  --from-literal=zone-name=${DNS_ZONE_NAME}
kubectl get configmap federation-controller-manager -o yaml
kubectl create -f deployments/federation-controller-manager.yaml

#Wait for the federation-controller-manager pod to be running.
kubectl get pods

#Configure kube-dns with federated DNS support
kubectl config use-context federation-cluster
mkdir -p configmaps
cat > configmaps/kube-dns.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
data:
  federations: federation=${DNS_ZONE_NAME}
EOF
kubectl create -f configmaps/kube-dns.yaml

#Adding Clusters
#Prerequisites
kubectl config use-context host-cluster
CLUSTERS="asia-east1-b europe-west1-b us-east1-b us-central1-b"

#Generate kubeconfigs and cluster objects
mkdir clusters
mkdir -p kubeconfigs
for cluster in ${CLUSTERS}; do
  mkdir -p kubeconfigs/${cluster}/

  SERVER=$(gcloud container clusters describe ${cluster} \
    --zone ${cluster} \
    --format 'value(endpoint)')

  CERTIFICATE_AUTHORITY_DATA=$(gcloud container clusters describe ${cluster} \
    --zone ${cluster} \
    --format 'value(masterAuth.clusterCaCertificate)')

  CLIENT_CERTIFICATE_DATA=$(gcloud container clusters describe ${cluster} \
    --zone ${cluster} \
    --format 'value(masterAuth.clientCertificate)')

  CLIENT_KEY_DATA=$(gcloud container clusters describe ${cluster} \
    --zone ${cluster} \
    --format 'value(masterAuth.clientKey)')

  kubectl config set-cluster ${cluster} --kubeconfig kubeconfigs/${cluster}/kubeconfig

  kubectl config set clusters.${cluster}.server \
    "https://${SERVER}" \
    --kubeconfig kubeconfigs/${cluster}/kubeconfig

  kubectl config set clusters.${cluster}.certificate-authority-data \
    ${CERTIFICATE_AUTHORITY_DATA} \
    --kubeconfig kubeconfigs/${cluster}/kubeconfig

  kubectl config set-credentials admin --kubeconfig kubeconfigs/${cluster}/kubeconfig

  kubectl config set users.admin.client-certificate-data \
    ${CLIENT_CERTIFICATE_DATA} \
    --kubeconfig kubeconfigs/${cluster}/kubeconfig

  kubectl config set users.admin.client-key-data \
    ${CLIENT_KEY_DATA} \
    --kubeconfig kubeconfigs/${cluster}/kubeconfig

  kubectl config set-context default \
    --cluster=${cluster} \
    --user=admin \
    --kubeconfig kubeconfigs/${cluster}/kubeconfig

  kubectl config use-context default \
    --kubeconfig kubeconfigs/${cluster}/kubeconfig

  cat > clusters/${cluster}.yaml <<EOF
apiVersion: federation/v1beta1
kind: Cluster
metadata:
  name: ${cluster}
spec:
  serverAddressByClientCIDRs:
    - clientCIDR: "0.0.0.0/0"
      serverAddress: "https://${SERVER}"
  secretRef:
    name: ${cluster}
EOF
done

#Create the Cluster Secrets
for cluster in ${CLUSTERS}; do
  kubectl create secret generic ${cluster} \
    --from-file=kubeconfigs/${cluster}/kubeconfig
done

#Create the cluster resources
kubectl config use-context federation-cluster
kubectl create -f clusters/

#Verify
kubectl get clusters

#Federated NGINX Service
#Prerequisites
kubectl config use-context federation-cluster

#Federated NGINX ReplicaSet
kubectl get clusters

kubectl create -f rs/nginx.yaml

#Verify
kubectl get rs

#List Pods
CLUSTERS="asia-east1-b europe-west1-b us-east1-b us-central1-b"

for cluster in ${CLUSTERS}; do
  echo ""
  echo "${cluster}"
  kubectl --context=${cluster} get pods --all-namespaces
done


kubectl run hello-world -–image=gcr.io/google-samples/node-hello:1.0 --port=8080 –-replicas=2
kubectl run hell0 --image=grc.io/google-samples/node-hello --port=8080 --replicas=2