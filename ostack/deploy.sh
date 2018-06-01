#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
# (but allow for the error trap)
set -eE

# keys exists at $PUBLIC_KEY, $PRIVATE_KEY and profile key at $ssh_key
export TF_VAR_public_key_path=$PUBLIC_KEY
echo "export TF_VAR_public_key_path=${TF_VAR_public_key_path}"

export TF_VAR_key_path="${KEY_PATH}"
echo "export TF_VAR_key_path=${TF_VAR_key_path}"

export TF_VAR_deployment_path="${PORTAL_DEPLOYMENTS_ROOT}/${PORTAL_DEPLOYMENT_REFERENCE}"
echo "export TF_VAR_deployment_path=${TF_VAR_deployment_path}"

export TF_VAR_name="$(awk -v var="${PORTAL_DEPLOYMENT_REFERENCE}" 'BEGIN {print tolower(var)}')"
echo "export TF_VAR_name=${TF_VAR_name}"

export TF_STATE=${DPL}'terraform.tfstate'
echo "export TF_STATE=${TF_STATE}"

export DPL="${PORTAL_DEPLOYMENTS_ROOT}/${PORTAL_DEPLOYMENT_REFERENCE}/"
echo "export DPL=${DPL}"

export PRIV_KEY_PATH="${DPL}${PORTAL_DEPLOYMENT_REFERENCE}"
echo "export PRIV_KEY_PATH=${PRIV_KEY_PATH}"

export KEY_PATH="${DPL}${PORTAL_DEPLOYMENT_REFERENCE}.pub"
echo "export KEY_PATH=${KEY_PATH}"

if [ -n ${K8S_MASTER_GX_PORT+x} ]; then echo "GX port var set"; fi

export KARGO_TERRAFORM_FOLDER=$PORTAL_APP_REPO_FOLDER'/kubespray/contrib/terraform/openstack'
echo "KARGO_TERRAFORM_FOLDER=$KARGO_TERRAFORM_FOLDER"


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

echo "＼(＾O＾)／ Applying terraform"
cd $PORTAL_APP_REPO_FOLDER'/kubespray'
terraform apply --state=$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.tfstate' $KARGO_TERRAFORM_FOLDER

echo "＼(＾O＾)／ Prepare the deployment substructure and link infrastructure"
mkdir -p $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray'
cp $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/contrib/terraform/terraform.py' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.py'
ln -s $PORTAL_APP_REPO_FOLDER'/kubespray/inventory/group_vars' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/'

echo "＼(＾O＾)／ symlink the playbooks, the inventory files"
#for i in $PORTAL_APP_REPO_FOLDER'/kubespray/*'; do
#  echo $i;
#done
#cp -r $PORTAL_APP_REPO_FOLDER'/kubespray/*' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/'
#for i in $PORTAL_APP_REPO_FOLDER'/kubespray-2.3.0/*'; do
#  ln -s $i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/'${i##*/};
#done
# cp -r $PORTAL_APP_REPO_FOLDER'/kubespray-2.3.0/roles' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/roles'
# cp -r $PORTAL_APP_REPO_FOLDER'/kubespray-2.3.0/scripts' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/scripts'
# cp -r $PORTAL_APP_REPO_FOLDER'/kubespray-2.3.0/library' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/library'
# cp -r $PORTAL_APP_REPO_FOLDER'/kubespray-2.3.0/contrib' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/contrib'
# cp -r $PORTAL_APP_REPO_FOLDER'/kubespray-2.3.0/extra_playbooks' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/extra_playbooks'
# cp $PORTAL_APP_REPO_FOLDER'/kubespray-2.3.0/ansible.cfg' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/'
# cp $PORTAL_APP_REPO_FOLDER'/kubespray-2.3.0/setup.cfg' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/'
# cp $PORTAL_APP_REPO_FOLDER'/kubespray-2.3.0/setup.py' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/'
# cp $PORTAL_APP_REPO_FOLDER'/kubespray-2.3.0/cluster.yml' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/'
for i in $PORTAL_APP_REPO_FOLDER'/kubespray-2.3.0/*'; do
  if [[ -d $i ]]; then
        ln -s $i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/'${i##*/}
        ls -lah $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/'${i##*/}
  fi
  if [[ -f $i ]]; then
        ln -s $i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/'${i##*/}
        ls -lah $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/'${i##*/}
  fi
done
ls -lah $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE


# $PORTAL_DEPLOYMENT_REFERENCE is set by portal and makes it unique per deployments
#cwd=/mnt/ecp/data/be_applications_folder/usr-45868085-9b3e-46fb-a818-17464c6f1718/portal-dummy-app.git/kubespray
#export DPL=/mnt/ecp/data/be_deployments_folder/TSI1527335760407/
#terraform.py dyn inventory script looks recursive in . , . is cwd
#solution? cd to deployment folder and correct ansible paths into kubespray yaml files

echo "＼(＾O＾)／ Giving cloudinit some more time (and avoid ssh unavailability)"
sleep 10

echo "＼(＾O＾)／ Applying ansible playbooks"
cd $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray'
echo "cwd=$PWD"
# Provision kubespray
ansible-playbook --flush-cache -b --become-user=root \
  -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.py' \
  $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/cluster.yml' \
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
	$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/contrib/network-storage/glusterfs/glusterfs.yml' \
	--key-file "$PRIVATE_KEY" \
	-e host_key_checking=false \
	-e bootstrap_os=ubuntu

# Set permissive access control and add '30700 open' security group
ansible-playbook -b --become-user=root \
  -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.py' \
	$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/extra_playbooks/rbac/rbac.yml' \
	--key-file "$PRIVATE_KEY"

# Start Galaxy, provision galaxy dataset, start workflow
ansible-playbook -b --become-user=root \
  -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.py' \
	$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/extra_playbooks/k8s-galaxy/k8s-galaxy.yml' \
	--key-file "$PRIVATE_KEY"
#  --write_to_/opt/galaxy_data/test.txt

# wait for write_to_/opt/galaxy_data/test.txt and write to local file
ansible-playbook -b --become-user=root -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/terraform.py' \
	$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/extra_playbooks/get-results/get-results.yml' \
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
