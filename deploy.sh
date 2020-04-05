#!/bin/bash
set -e

# Creates an EKS cluster. Assumes Terraform, the aws-cli, profile credentials,
# kubectl and iam-eks-authenticator are already properly configured.
# WARNING: overwrites kube/config
function create_EKS_cluster() {
  pushd terraform-eks

  terraform init
  terraform plan
  terraform apply -auto-approve

  terraform output kubeconfig > ~/.kube/config
  terraform output config_map_aws_auth > config_map_aws_auth.yaml
  kubectl apply -f config_map_aws_auth.yaml

  popd
}

# Deploys LEMP stack Wordpress on K8S
function deploy_WP_LEMP() {
  pushd lemp-wp-docker

  ./deploy-local.sh

  popd
}

# Test pods for liveness probe success
function test_probe_results() {
  echo -n "Waiting for all pods to be ready... "
  kubectl wait --for=condition=Ready pods --all
  echo "done."
  echo -n "Waiting 10 seconds for next liveness round of testing... "
  sleep 10
  count=$(kubectl describe pods | grep -E "Liveness|#success=1" | wc -l)
  if [[ count -eq 6 ]]; then
    echo "succeeded."
  else
    echo "failed - expecting 6 records for liveness and readiness probes"
    exit 1
  fi
}

function setup_hpa() {
  # Install metrics server
  DOWNLOAD_URL=$(curl -Ls "https://api.github.com/repos/kubernetes-sigs/metrics-server/releases/latest" | jq -r .tarball_url)
  DOWNLOAD_VERSION=$(grep -o '[^/v]*$' <<< $DOWNLOAD_URL)
  curl -Ls $DOWNLOAD_URL -o metrics-server-$DOWNLOAD_VERSION.tar.gz
  mkdir metrics-server-$DOWNLOAD_VERSION
  tar -xzf metrics-server-$DOWNLOAD_VERSION.tar.gz --directory metrics-server-$DOWNLOAD_VERSION --strip-components 1
  kubectl apply -f metrics-server-$DOWNLOAD_VERSION/deploy/1.8+/

  # Verify that EKS metrics-server is deployed
  kubectl get deployment metrics-server -n kube-system
  # Create a simple HPA for the wordpress deployment
  kubectl autoscale deployment wordpress --cpu-percent=50 --min=1 --max=10
  kubectl get hpa

  # TODO test it?
}

cat << EOF
======================================
Starting Wordpress LEMP EKS deployment
======================================

EOF

create_EKS_cluster
deploy_WP_LEMP
test_probe_results
setup_hpa