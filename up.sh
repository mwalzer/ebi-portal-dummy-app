# set environment variables used by scripts in cloud-deploy/
export PUBLIC_KEY="/home/walzer/.ssh/id_rsa.pub"
export PRIVATE_KEY="/home/walzer/.ssh/id_rsa"
export PORTAL_DEPLOYMENTS_ROOT="$HOME/deployments"
export PORTAL_APP_REPO_FOLDER="$HOME/app"
export PORTAL_DEPLOYMENT_REFERENCE="deployment-ref-ubuntu"

deployment_dir="$PORTAL_DEPLOYMENTS_ROOT/$PORTAL_DEPLOYMENT_REFERENCE"
if [[ ! -d "$deployment_dir" ]]; then
    mkdir -p "$deployment_dir"
fi
printf 'Using deployment directory "%s"\n' "$deployment_dir"
printf 'Taking from repository directory "%s"\n' "$PORTAL_APP_REPO_FOLDER"

export TF_VAR_kube_api_pwd="kubeapipw"
export TF_VAR_cluster_name="kubespraytest"
export TF_VAR_number_of_etcd="0"
export TF_VAR_number_of_k8s_masters="1"
export TF_VAR_number_of_k8s_masters_no_floating_ip="0"
export TF_VAR_number_of_k8s_masters_no_etcd="0"
export TF_VAR_number_of_k8s_masters_no_floating_ip_no_etcd="0"
export TF_VAR_number_of_k8s_nodes_no_floating_ip="2"
export TF_VAR_number_of_k8s_nodes="0"
export TF_VAR_public_key_path="/home/walzer/.ssh/id_rsa.pub"
export TF_VAR_image="Ubuntu16.04"
#export TF_VAR_image="CentOS7-1612"
export TF_VAR_ssh_user="ubuntu"
#export TF_VAR_ssh_user="centos"
#export TF_VAR_flavor_k8s_node="e9ca7478-7957-4237-b3d0-d4767e1de65f" #ext5
export TF_VAR_flavor_k8s_node="11"
#export TF_VAR_flavor_etcd="12"
#export TF_VAR_flavor_k8s_master="91ba172b-cb4c-453c-b7fc-56cb79c78968" #ext5
export TF_VAR_flavor_k8s_master="11"
export TF_VAR_network_name="Elixir-Proteomics_private"
export TF_VAR_floatingip_pool="ext-net"
# missing for portal subnet_id

# GlusterFS variables
#export TF_VAR_flavor_gfs_node="e9ca7478-7957-4237-b3d0-d4767e1de65f" #ext5
export TF_VAR_flavor_gfs_node="11"
export TF_VAR_image_gfs="Ubuntu16.04"
export TF_VAR_number_of_gfs_nodes_no_floating_ip="3"
export TF_VAR_gfs_volume_size_in_gb="30"
export TF_VAR_ssh_user_gfs="ubuntu"

export KUBELET_DEPLOYMENT_TYPE="host"
export KUBE_VERSION="v1.8.2"

# this seems too unwieldy https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9
export K8S_MASTER_GX_PORT="30700"
if [ ! -z ${K8S_MASTER_GX_PORT+x} ]; then
	#echo $K8S_MASTER_GX_PORT;
	sed -i 's,description = "${var.cluster_name} - Kubernetes Master"','description = "${var.cluster_name} - Kubernetes Master"\n\trule {\n\t\tip_protocol = "tcp"\n\t\tfrom_port = "'$K8S_MASTER_GX_PORT'"\n\t\tto_port = "'$K8S_MASTER_GX_PORT'"\n\t\tcidr = "0.0.0.0/0"\n\t},' kubespray/contrib/terraform/openstack/kubespray.tf
fi
# this will stack the same rule in the .tf file which is benign but ugly

#1st customisation external_ip (in manifest and deploy.sh)
#ostack/deploy.sh
