# ----- Federation SetUp

# ----- Install for k8s 1.9 and above
curl -LO \
    https://storage.googleapis.com/kubernetes-release/release/v1.10.0-alpha.0/federation-client-linux-amd64.tar.gz
tar -xzvf federation-client-linux-amd64.tar.gz

# ----- copy binary to your path and grant permissions
sudo cp federation/client/bin/kubefed /usr/local/bin
sudo chmod +x /usr/local/bin/kubefed

# ----- Choosing a host cluster (only one host cluster per federation)
kubectl config get-contexts

# Initialize federation control plane for a federation
# named foo in the host cluster whose local kubeconfig
# context is bar.
kubefed init federation_name \
    --host-cluster-context=context_name \
    --dns-provder="dns-provider"
    --dns-zone-name="domain.com."


# The machines in your host cluster must have the appropriate permissions to program the DNS service
# that you are using.

# set context on kubectl
kubectl config use-context federation_name

# add a cluster to the federation
kubectl config use-context fellowship
kubectl create clusterrolebinding <your_user>-cluster-admin-binding --clusterrole=cluster-admin \
    --user=<your_user>@example.org --context=<joining_cluster_context>

#join cluster
kubefec join federation_name \
    --host-cluster-context=context_name

# update kube-dns