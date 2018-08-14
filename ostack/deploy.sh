#!/usr/bin/env bash
set -euo pipefail

# keys exists at $PUBLIC_KEY, $PRIVATE_KEY and profile key at $ssh_key
export TF_VAR_public_key_path=$PUBLIC_KEY
echo "export TF_VAR_public_key_path=${TF_VAR_public_key_path}"

export TF_VAR_key_path="${KEY_PATH}"
echo "export TF_VAR_key_path=${TF_VAR_key_path}"

export TF_VAR_deployment_path="${PORTAL_DEPLOYMENTS_ROOT}/${PORTAL_DEPLOYMENT_REFERENCE}/deployment"
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


echo "＼(＾O＾)／ Prepare the deployment substructure and link infrastructure"
cd $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE
mkdir 'deployment'
cp -Lr $PORTAL_APP_REPO_FOLDER'/kubespray' '.'
cp -Lr $PORTAL_APP_REPO_FOLDER'/extra-playbooks' '.'

echo "＼(＾O＾)／ Applying terraform"
cd $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray'
export KARGO_TERRAFORM_FOLDER=$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray/contrib/terraform/openstack'
terraform apply --state=$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment/terraform.tfstate' $KARGO_TERRAFORM_FOLDER
export DYNAMICINVENTORY=$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment'

#all dangling symlinks fixed?
echo "＼(＾O＾)／ Fixing the inventory"
cd $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray'
cp 'contrib/terraform/terraform.py' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment/terraform.py'
cp -r 'contrib/terraform/openstack/group_vars' $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment'
cp -r 'contrib/terraform/openstack/group_vars' 'contrib/network-storage/glusterfs'
cp -r 'contrib/terraform/openstack/group_vars' 'extra_playbooks'
cp -r 'contrib/terraform/openstack/group_vars' 'inventory'

echo "dyn inventory from terraform:"
ls -lahR $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment'
cd $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment/'
python terraform.py --list --root .

echo "ansible-playbook --version"
ansible-playbook --version
#  Ansible v2.4 (or newer) and python-netaddr is installed on the machine that will run Ansible commands
#  Jinja 2.9 (or newer) is required to run the Ansible Playbooks

echo "＼(＾O＾)／ Giving cloudinit some more time (and avoid ssh unavailability)"
sleep 10

maxRetries=3
retryInterval=10

echo "＼(＾O＾)／ Applying ansible playbooks"
cd $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/kubespray'
echo "cwd=$PWD"

# Provision kubespray
retry=0
until [ ${retry} -ge ${maxRetries} ]
do
  ansible-playbook --flush-cache -b --become-user=root -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment/terraform.py' cluster.yml \
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
  	-e kube_network_plugin="weave" && break
	retry=$[${retry}+1]
	echo "Retrying [${retry}/${maxRetries}] in ${retryInterval}(s) "
	sleep ${retryInterval}
done
if [ ${retry} -ge ${maxRetries} ]; then
  echo "Failed after ${maxRetries} attempts!"
  exit 1
fi

# Provision glusterfs
until [ ${retry} -ge ${maxRetries} ]
do
  ansible-playbook -b --become-user=root -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment/terraform.py' contrib/network-storage/glusterfs/glusterfs.yml \
  	--key-file "$PRIVATE_KEY" \
  	-e host_key_checking=false \
  	-e bootstrap_os=ubuntu && break
	retry=$[${retry}+1]
	echo "Retrying [${retry}/${maxRetries}] in ${retryInterval}(s) "
	sleep ${retryInterval}
done
if [ ${retry} -ge ${maxRetries} ]; then
  echo "Failed after ${maxRetries} attempts!"
  exit 1
fi

# Set permissive access control and add '30700 open' security group
until [ ${retry} -ge ${maxRetries} ]
do
  ansible-playbook -b --become-user=root \
    -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment/terraform.py' \
  	$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/extra_playbooks/rbac/rbac.yml' \
  	--key-file "$PRIVATE_KEY" && break
	retry=$[${retry}+1]
	echo "Retrying [${retry}/${maxRetries}] in ${retryInterval}(s) "
	sleep ${retryInterval}
done
if [ ${retry} -ge ${maxRetries} ]; then
  echo "Failed after ${maxRetries} attempts!"
  exit 1
fi

# Start Galaxy, provision galaxy dataset, start workflow
until [ ${retry} -ge ${maxRetries} ]
do
  ansible-playbook -b --become-user=root \
    -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment/terraform.py' \
  	$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/extra_playbooks/k8s-galaxy/k8s-galaxy.yml' \
  	--key-file "$PRIVATE_KEY" && break
	retry=$[${retry}+1]
	echo "Retrying [${retry}/${maxRetries}] in ${retryInterval}(s) "
	sleep ${retryInterval}
done
#  --write_to_/opt/galaxy_data/test.txt
if [ ${retry} -ge ${maxRetries} ]; then
  echo "Failed after ${maxRetries} attempts!"
  exit 1
fi


# wait for write_to_/opt/galaxy_data/test.txt and write to local file
until [ ${retry} -ge ${maxRetries} ]
do
  ansible-playbook -b --become-user=root -i $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment/terraform.py' \
  	$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/extra_playbooks/get-results/get-results.yml' \
  	--key-file "$PRIVATE_KEY" \

    --extra-vars "helm_test_param=789" && break
	#something like --extra-vars "helm_test_param=helm_test_param_in"
  retry=$[${retry}+1]
	echo "Retrying [${retry}/${maxRetries}] in ${retryInterval}(s) "
	sleep ${retryInterval}
done
if [ ${retry} -ge ${maxRetries} ]; then
  echo "Failed after ${maxRetries} attempts!"
  exit 1
fi



helm_test_param_out=`cat helm_test_param.txt`
#clean up afterwards!!!

# Extract the external IP of the instance
external_ip=$(terraform output -state=${DPL}'terraform.tfstate' external_ip)

#TF move to deployment parameters in portal and remove prefix
#see cpa instance.tf for how to define multiple types of flavours for one deployment
