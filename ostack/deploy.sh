#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
# (but allow for the error trap)
set -eE

# keys exists at $PUBLIC_KEY, $PRIVATE_KEY and profile key at $ssh_key
export TF_VAR_public_key_path=$PUBLIC_KEY

set -e
# Provisions a virtual machine instance

# Local variables
export TF_VAR_deployment_path="${PORTAL_DEPLOYMENTS_ROOT}/${PORTAL_DEPLOYMENT_REFERENCE}"
echo "export TF_VAR_deployment_path=${TF_VAR_deployment_path}"

export DPL="${PORTAL_DEPLOYMENTS_ROOT}/${PORTAL_DEPLOYMENT_REFERENCE}/"
echo "export DPL=${DPL}"

export PRIV_KEY_PATH="${DPL}${PORTAL_DEPLOYMENT_REFERENCE}"
echo "export PRIV_KEY_PATH=${PRIV_KEY_PATH}"

export TF_VAR_key_path="${KEY_PATH}"
echo "export TF_VAR_key_path=${TF_VAR_key_path}"

# Export input variables in the bash environment
export TF_VAR_name="$(awk -v var="${PORTAL_DEPLOYMENT_REFERENCE}" 'BEGIN {print tolower(var)}')"
echo "export TF_VAR_name=${TF_VAR_name}"

export KEY_PATH="${DPL}${PORTAL_DEPLOYMENT_REFERENCE}.pub"
echo "export KEY_PATH=${KEY_PATH}"

export TF_STATE=${DPL}'terraform.tfstate'
echo "export TF_STATE=${TF_STATE}"

eval $(ssh-agent -s)
ssh-add $PRIVATE_KEY

echo "＼(＾O＾)／ Setting up Terraform creds" && \
  export TF_VAR_username=${OS_USERNAME} && \
  export TF_VAR_password=${OS_PASSWORD} && \
  export TF_VAR_tenant=${OS_TENANT_NAME} && \
  export TF_VAR_auth_url=${OS_AUTH_URL}

# make sure image is available in openstack
#ansible-playbook "$PORTAL_APP_REPO_FOLDER/playbooks/import-openstack-image.yml"
#ansible-playbook "$PORTAL_APP_REPO_FOLDER/playbooks/import-openstack-image.yml" \
#	-e img_version="current" \
#        -e img_prefix="Ubuntu-16.04" \
#	-e url_prefix="http://cloud-images.ubuntu.com/xenial/" \
#	-e url_suffix="xenial-server-cloudimg-amd64-disk1.img" \
#	-e compress_suffix=""

if [ -n ${K8S_MASTER_GX_PORT+x} ]; then echo "var is set"; fi

export KARGO_TERRAFORM_FOLDER=$PORTAL_APP_REPO_FOLDER'/kubespray/contrib/terraform/openstack'

echo "＼(＾O＾)／ Applying terraform"
cd $PORTAL_APP_REPO_FOLDER'/kubespray'
terraform apply --state=$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.tfstate' $KARGO_TERRAFORM_FOLDER

echo "＼(＾O＾)／ Digesting the hosts file"
cat $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/hosts'
cp contrib/terraform/terraform.py $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/hosts'
cp -r inventory/group_vars $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/'
cat $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/hosts'

# $PORTAL_DEPLOYMENT_REFERENCE is set by portal and makes it unique per deployments

echo "＼(＾O＾)／ Applying ansible playbooks"
# Provision kubespray
ansible-playbook --flush-cache -b --become-user=root -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/hosts' cluster.yml \
	--key-file "$PRIVATE_KEY" \
	-e bootstrap_os=ubuntu \
	-e host_key_checking=false \
	-e cloud_provider="openstack" \
	-e efk_enabled=false \
	-e kubelet_deployment_type=$KUBELET_DEPLOYMENT_TYPE \
	-e kube_api_pwd=$TF_VAR_kube_api_pwd \
	-e cluster_name=$TF_VAR_cluster_name \
	-e helm_enabled=true \
	-e kube_version=$KUBE_VERSION \
	-e kube_network_plugin="weave"


# Provision glusterfs
ansible-playbook -b --become-user=root -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/hosts' \
	./contrib/network-storage/glusterfs/glusterfs.yml \
	--key-file "$PRIVATE_KEY" \
	-e host_key_checking=false \
	-e bootstrap_os=ubuntu

# Set permissive access control and add '30700 open' security group
ansible-playbook -b --become-user=root -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/hosts' \
	../extra-playbooks/rbac/rbac.yml \
	--key-file "$PRIVATE_KEY"

# Start Galaxy, provision galaxy dataset, start workflow
ansible-playbook -b --become-user=root -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/hosts' \
	../extra-playbooks/k8s-galaxy/k8s-galaxy.yml \
	--key-file "$PRIVATE_KEY"
#  --write_to_/opt/galaxy_data/test.txt

# wait for write_to_/opt/galaxy_data/test.txt and write to local file
ansible-playbook -b --become-user=root -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/hosts' \
	../extra-playbooks/get-results/get-results.yml \
	--key-file "$PRIVATE_KEY" \
  --extra-vars "helm_test_param=789"
  #something like --extra-vars "helm_test_param=helm_test_param_in"

#https://github.com/EMBL-EBI-TSI/cpa-instance/blob/d103005a7500c8b85324e483da1974bfddac47d0/ostack/deploy.sh#L19

helm_test_param_out=`cat helm_test_param.txt`
#clean up afterwards!!!

# Extract the external IP of the instance
external_ip=$(terraform output -state=${DPL}'terraform.tfstate' external_ip)

#TF move to deployment parameters in portal and remove prefix
#see cpa instance.tf for how to define multiple types of flavours for one deployment
