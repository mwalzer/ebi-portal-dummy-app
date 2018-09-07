# set environment variables used by scripts in cloud-deploy/

# PORTAL presets
export PORTAL_APP_REPO_FOLDER="/data"
export PORTAL_DEPLOYMENTS_ROOT="$HOME/deployments"
export PORTAL_DEPLOYMENT_REFERENCE="deployment-ref-ubuntu"

# Private Key
export PRIV_KEY_PATH="/home/user/.ssh/id_rsa"
echo "export PRIV_KEY_PATH=${PRIV_KEY_PATH}"
export PRIVATE_KEY="/home/user/.ssh/id_rsa"
echo "export PRIVATE_KEY=${PRIVATE_KEY}"


# Public Key
export KEY_PATH="/home/user/.ssh/id_rsa.pub"
echo "export KEY_PATH=${KEY_PATH}"
export PUBLIC_KEY="/home/user/.ssh/id_rsa.pub"
echo "export PUBLIC_KEY=${PUBLIC_KEY}"



# Git cloned application folder
export APP="${PORTAL_APP_REPO_FOLDER}"
echo "export APP=${APP}"
# Deployment folder
export DPL="${PORTAL_DEPLOYMENTS_ROOT}/${PORTAL_DEPLOYMENT_REFERENCE}/"
echo "export DPL=${DPL}"

if [[ ! -d "$DPL" ]]; then
    mkdir -p "$DPL"
fi
printf 'Using deployment directory "%s"\n' "$DPL"
printf 'Taking from repository directory "%s"\n' "$PORTAL_APP_REPO_FOLDER"

# Variables as set by the deployment parameters
# Terraform variables
export TF_VAR_kube_api_pwd="kubeapipw"
export TF_VAR_cluster_name="kubespraytest"
export TF_VAR_number_of_etcd="0"
export TF_VAR_number_of_k8s_masters="1"
export TF_VAR_number_of_k8s_masters_no_floating_ip="0"
export TF_VAR_number_of_k8s_masters_no_etcd="0"
export TF_VAR_number_of_k8s_masters_no_floating_ip_no_etcd="0"
export TF_VAR_number_of_k8s_nodes_no_floating_ip="2"
export TF_VAR_number_of_k8s_nodes="0"
export TF_VAR_public_key_path=$PUBLIC_KEY
export TF_VAR_image="Ubuntu16.04"
export TF_VAR_ssh_user="ubuntu"
export TF_VAR_flavor_k8s_node="11"
export TF_VAR_flavor_k8s_master="11"
export TF_VAR_network_name="Elixir-Proteomics_private"
export TF_VAR_floatingip_pool="ext-net"

# GlusterFS variables
export TF_VAR_flavor_gfs_node="11"
export TF_VAR_image_gfs="Ubuntu16.04"
export TF_VAR_number_of_gfs_nodes_no_floating_ip="3"
export TF_VAR_gfs_volume_size_in_gb="30"
export TF_VAR_ssh_user_gfs="ubuntu"

# Kubespray settings
export KUBELET_DEPLOYMENT_TYPE="host"
export KUBE_VERSION="v1.8.2"

# this will stack the same rule in the .tf file which is benign but ugly

#eval $(ssh-agent -s)
#ssh-add $PRIVATE_KEY
#1st customisation external_ip (in manifest and deploy.sh)
$APP/ostack/deploy.sh
