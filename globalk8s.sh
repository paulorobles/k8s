gcloud container  clusters create west-cluster --zone us-west1-a --scopes "cloud-platform,storage-ro,logging-write,monitoring-write,service-control,service-management,https://www.googleapis.com/auth/ndev.clouddns.readwrite"

gcloud container  clusters create east-cluster --zone us-east1-b --scopes "cloud-platform,storage-ro,logging-write,monitoring-write,service-control,service-management,https://www.googleapis.com/auth/ndev.clouddns.readwrite"


kubefed init kfed --host-cluster-context=east --dns-zone-name=testkubernetes.com --dns-provider=google-clouddns


curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.9.0-alpha.3/kubernetes-client-linux-amd64.tar.gz
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.10.0-alpha.0/kubernetes-client-linux-amd64.tar.gz
tar -xzvf kubernetes-client-linux-amd64.tar.gz