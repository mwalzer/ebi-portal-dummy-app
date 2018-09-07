#!/usr/bin/env bash
set -e

echo "\(^O^)/ Setting up convenience OS_ENV"
# Git cloned application folder
export APP="${PORTAL_APP_REPO_FOLDER}"
echo "export APP=${APP}"
# Deployment folder
export DPL="${PORTAL_DEPLOYMENTS_ROOT}/${PORTAL_DEPLOYMENT_REFERENCE}/"
echo "export DPL=${DPL}"

echo "\(^O^)/ Will destroy the following"
# Export input variable in the bash environment
export TF_VAR_name="$(awk -v var="$PORTAL_DEPLOYMENT_REFERENCE" 'BEGIN {print tolower(var)}')"
echo $TF_VAR_name

export TF_STATE=${DPL}'/kubespray/inventory/terraform.tfstate'
echo "export TF_STATE=${TF_STATE}"

echo "\(^O^)/ ICH MUSS ZERSTOEREN ...!"
# Destroys a virtual machine instance
terraform destroy --force --input=false --state=$TF_STATE
