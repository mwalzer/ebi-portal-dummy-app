#!/usr/bin/env bash
set -e

export TF_VAR_deployment_path="${PORTAL_DEPLOYMENTS_ROOT}/${PORTAL_DEPLOYMENT_REFERENCE}/deployment"
echo "export TF_VAR_deployment_path=${TF_VAR_deployment_path}"

# Export input variable in the bash environment
export TF_VAR_name="$(awk -v var="$PORTAL_DEPLOYMENT_REFERENCE" 'BEGIN {print tolower(var)}')"

# Destroys a virtual machine instance
terraform destroy --force --input=false --state=$PORTAL_DEPLOYMENTS_ROOT'/'$PORTAL_DEPLOYMENT_REFERENCE'/deployment/terraform.tfstate'
