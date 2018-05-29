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
#ansible-playbook "$PORTAL_APP_REPO_FOLDER/playbooks/import-openstack-image.yml" \
#	-e img_version="current" \
#        -e img_prefix="Ubuntu-16.04" \
#	-e url_prefix="http://cloud-images.ubuntu.com/xenial/" \
#	-e url_suffix="xenial-server-cloudimg-amd64-disk1.img" \
#	-e compress_suffix=""

if [ -n ${K8S_MASTER_GX_PORT+x} ]; then echo "var is set"; fi

export KARGO_TERRAFORM_FOLDER=$PORTAL_APP_REPO_FOLDER'/kubespray/contrib/terraform/openstack'
echo "KARGO_TERRAFORM_FOLDER=$KARGO_TERRAFORM_FOLDER"

echo "＼(＾O＾)／ Applying terraform"
cd $PORTAL_APP_REPO_FOLDER'/kubespray'
terraform apply --state=$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.tfstate' $KARGO_TERRAFORM_FOLDER

echo "＼(＾O＾)／ Supply the inventory files"
cp contrib/terraform/terraform.py $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.py'
cp -r inventory/group_vars $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/'

echo "＼(＾O＾)／ symlink the playbooks the inventory files"
ls $PORTAL_APP_REPO_FOLDER'/kubespray/*'
for i in $PORTAL_APP_REPO_FOLDER'/kubespray/*'; do
  ln -s $i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/'${i##*/};
done

# $PORTAL_DEPLOYMENT_REFERENCE is set by portal and makes it unique per deployments
#cwd=/mnt/ecp/data/be_applications_folder/usr-45868085-9b3e-46fb-a818-17464c6f1718/portal-dummy-app.git/kubespray
#export DPL=/mnt/ecp/data/be_deployments_folder/TSI1527335760407/
#terraform.py dyn inventory script looks recursive in . , . is cwd
#solution? cd to deployment folder and correct ansible paths into kubespray yaml files
cd $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE

echo "＼(＾O＾)／ Applying ansible playbooks"
echo "cwd=$PWD"
# Provision kubespray
ansible-playbook --flush-cache -b --become-user=root \
  -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.py' \
  $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/cluster.yml' \
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
ansible-playbook -b --become-user=root \
  -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.py' \
	$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/contrib/network-storage/glusterfs/glusterfs.yml' \
	--key-file "$PRIVATE_KEY" \
	-e host_key_checking=false \
	-e bootstrap_os=ubuntu

# Set permissive access control and add '30700 open' security group
ansible-playbook -b --become-user=root \
  -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.py' \
	$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/extra-playbooks/rbac/rbac.yml' \
	--key-file "$PRIVATE_KEY"

# Start Galaxy, provision galaxy dataset, start workflow
ansible-playbook -b --become-user=root \
  -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.py' \
	$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/extra-playbooks/k8s-galaxy/k8s-galaxy.yml' \
	--key-file "$PRIVATE_KEY"
#  --write_to_/opt/galaxy_data/test.txt

# wait for write_to_/opt/galaxy_data/test.txt and write to local file
ansible-playbook -b --become-user=root -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.py' \
	$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/extra-playbooks/get-results/get-results.yml' \
	--key-file "$PRIVATE_KEY" \
  --extra-vars "helm_test_param=789"
  #something like --extra-vars "helm_test_param=helm_test_param_in"

#seems ansible is not using a bastion, maybe because subroles are not detectable
#solution? symlink or kopy kubespray into the deployment
#also where are the group vars?
#also
#  Ansible v2.4 (or newer) and python-netaddr is installed on the machine that will run Ansible commands
#  Jinja 2.9 (or newer) is required to run the Ansible Playbooks

helm_test_param_out=`cat helm_test_param.txt`
#clean up afterwards!!!

# Extract the external IP of the instance
external_ip=$(terraform output -state=${DPL}'terraform.tfstate' external_ip)

#TF move to deployment parameters in portal and remove prefix
#see cpa instance.tf for how to define multiple types of flavours for one deployment
