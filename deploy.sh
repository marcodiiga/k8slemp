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

cat << EOF
======================================
Starting Wordpress LEMP EKS deployment
======================================

EOF

#create_EKS_cluster
deploy_WP_LEMP