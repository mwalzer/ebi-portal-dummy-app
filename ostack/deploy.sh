#!/usr/bin/env bash
set -euoEx pipefail

echo "＼(＾O＾)／ Setting up convenience OS_ENV"
# Git cloned application folder
export APP="${PORTAL_APP_REPO_FOLDER}"
echo "export APP=${APP}"
# Deployment folder
export DPL="${PORTAL_DEPLOYMENTS_ROOT}/${PORTAL_DEPLOYMENT_REFERENCE}/"
echo "export DPL=${DPL}"
export KEY_PATH=$PUBLIC_KEY
export PRIV_KEY_PATH=$PRIVATE_KEY

echo "＼(＾O＾)／ Setting up Terraform creds" && \
export TF_VAR_username=${OS_USERNAME} && \
export TF_VAR_password=${OS_PASSWORD} && \
export TF_VAR_tenant=${OS_TENANT_NAME} && \
export TF_VAR_auth_url=${OS_AUTH_URL}

### Terraform variables, can be used by terrarom without the `TF_VAR_` prefix
export TF_VAR_deployment_path="$DPL"
echo "export TF_VAR_deployment_path=${TF_VAR_deployment_path}"
export TF_VAR_name="$(awk -v var="${PORTAL_DEPLOYMENT_REFERENCE}" 'BEGIN {print tolower(var)}')"
echo "export TF_VAR_name=${TF_VAR_name}"
export TF_VAR_key_path="${KEY_PATH}"
echo "export TF_VAR_key_path=${TF_VAR_key_path}"
export TF_STATE=${DPL}'/kubespray/inventory/terraform.tfstate'
echo "export TF_STATE=${TF_STATE}"

echo "＼(＾O＾)／ Copy kubespray instructions for deployment customisations"
cp -rH $APP'/kubespray' $DPL'/kubespray'
cp $DPL'/kubespray/contrib/terraform/terraform.py' $DPL'/kubespray/inventory/terraform.py'
cp -rH $APP'/extra-playbooks' $DPL'/extra-playbooks'

echo "＼(＾O＾)／ Applying terraform"
cd $DPL'/kubespray'
export KUBESPRAY_TF=$DPL'/kubespray/contrib/terraform/openstack'
terraform apply --state=$TF_STATE $KUBESPRAY_TF

#echo "dyn inventory from terraform:"
#ls -lahR $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment'
#cd $PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment/'
#python terraform.py --list --root .

echo "＼(＾O＾)／ Giving cloudinit some more time (and avoid ssh unavailability)"
sleep 30

pkill -f 'ssh-agent -s'
#Seems the agent is critical for forwarding the PRIV_KEY_PATH to the endpoint host
eval $(ssh-agent -s)
ssh-add $PRIV_KEY_PATH

maxRetries=3
retryInterval=60

echo "＼(＾O＾)／ Applying ansible playbooks"
cd $DPL'/kubespray'
echo "cwd=$PWD"

#THIS playbook wants to write in the playbooks folder
# Provision kubespray
retry=0
until [ ${retry} -ge ${maxRetries} ]
do
  ansible-playbook --flush-cache -b --become-user=root -i $DPL'/kubespray/inventory/terraform.py' \
    $DPL'/kubespray/cluster.yml' \
    --key-file "$PRIV_KEY_PATH" \
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
  ansible-playbook -b --become-user=root \
    -i $DPL'/kubespray/inventory/terraform.py' \
    $DPL'/kubespray/contrib/network-storage/glusterfs/glusterfs.yml' \
    --key-file "$PRIV_KEY_PATH" \
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
    -i $DPL'/kubespray/inventory/terraform.py' \
    $DPL'/extra-playbooks/rbac/rbac.yml' \
    --key-file "$PRIV_KEY_PATH" && break
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
    -i $DPL'/kubespray/inventory/terraform.py' \
    $DPL'/extra-playbooks/k8s-galaxy/k8s-galaxy.yml' \
    --key-file "$PRIV_KEY_PATH" && break
    retry=$[${retry}+1]
    echo "Retrying [${retry}/${maxRetries}] in ${retryInterval}(s) "
    sleep ${retryInterval}
done
#  --write_to_/opt/galaxy_data/test.txt
if [ ${retry} -ge ${maxRetries} ]; then
  echo "Failed after ${maxRetries} attempts!"
  exit 1
fi

#THIS playbook wants to write in the playbooks folder
# wait for write_to_/opt/galaxy_data/test.txt and write to local file
until [ ${retry} -ge ${maxRetries} ]
do
  ansible-playbook -b --become-user=root \
    -i $DPL'/kubespray/inventory/terraform.py' \
    $DPL'/extra-playbooks/wf-controller/wf-controller.yml' \
    --key-file "$PRIV_KEY_PATH" && break
    #something like --extra-vars "helm_test_param=helm_test_param_in"
  retry=$[${retry}+1]
    echo "Retrying [${retry}/${maxRetries}] in ${retryInterval}(s) "
    sleep ${retryInterval}
done
if [ ${retry} -ge ${maxRetries} ]; then
  echo "Failed after ${maxRetries} attempts!"
  exit 1
fi

#clean up afterwards?
#destroy.sh
#rm -rf $DPL'/kubespray'

#Export results
# Extract the S3 url for user download
result_url=`cat /tmp/fetched`
# Extract the external IP of the instance
external_ip=$(terraform output -state=$TF_STATE external_ip)
