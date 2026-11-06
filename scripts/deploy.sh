#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

for command_name in az azd kubectl envsubst openssl base64; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "${command_name}" >&2
    exit 1
  fi
done

AZURE_SUBSCRIPTION_ID="$(azd env get-value AZURE_SUBSCRIPTION_ID)"
AZURE_RESOURCE_GROUP="$(azd env get-value AZURE_RESOURCE_GROUP)"
AZURE_AKS_CLUSTER_NAME="$(azd env get-value AZURE_AKS_CLUSTER_NAME)"
AZURE_LOCATION="$(azd env get-value AZURE_LOCATION)"

if [[ -z "${AZURE_SUBSCRIPTION_ID}" || -z "${AZURE_RESOURCE_GROUP}" || -z "${AZURE_AKS_CLUSTER_NAME}" || -z "${AZURE_LOCATION}" ]]; then
  printf 'Run azd provision successfully before deploying the Kubernetes workloads.\n' >&2
  exit 1
fi

az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
AZURE_NODE_RESOURCE_GROUP="$(az group list \
  --query "[?name=='MC_${AZURE_RESOURCE_GROUP}_${AZURE_AKS_CLUSTER_NAME}_${AZURE_LOCATION}'].name | [0]" \
  -o tsv)"
if [[ -z "${AZURE_NODE_RESOURCE_GROUP}" || "${AZURE_NODE_RESOURCE_GROUP}" == "None" ]]; then
  printf 'Could not find the AKS managed resource group for cluster %s.\n' "${AZURE_AKS_CLUSTER_NAME}" >&2
  exit 1
fi

az aks get-credentials \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --name "${AZURE_AKS_CLUSTER_NAME}" \
  --overwrite-existing
kubectl wait --for=condition=Ready nodes --all --timeout=10m

get_secret_value() {
  local secret_name="$1"
  local namespace="$2"
  local key="$3"
  kubectl get secret "${secret_name}" -n "${namespace}" \
    -o "go-template={{index .data \"${key}\"}}" | base64 --decode
}

apply_wordpress_secret() {
  local existing_secret
  if existing_secret="$(kubectl get secret wordpress-credentials -n wordpress --ignore-not-found -o name)" \
    && [[ -n "${existing_secret}" ]]; then
    WORDPRESS_DB_ROOT_PASSWORD="$(get_secret_value wordpress-credentials wordpress mariadb-root-password)"
    WORDPRESS_DB_PASSWORD="$(get_secret_value wordpress-credentials wordpress mariadb-password)"
    WORDPRESS_ADMIN_USER="$(get_secret_value wordpress-credentials wordpress wordpress-admin-user)"
    WORDPRESS_ADMIN_PASSWORD="$(get_secret_value wordpress-credentials wordpress wordpress-admin-password)"
    WORDPRESS_ADMIN_EMAIL="$(get_secret_value wordpress-credentials wordpress wordpress-admin-email)"
  else
    WORDPRESS_DB_ROOT_PASSWORD="$(openssl rand -hex 32)"
    WORDPRESS_DB_PASSWORD="$(openssl rand -hex 32)"
    WORDPRESS_ADMIN_USER="wpadmin"
    WORDPRESS_ADMIN_PASSWORD="$(openssl rand -hex 32)"
    WORDPRESS_ADMIN_EMAIL="${WORDPRESS_ADMIN_EMAIL:-admin@example.invalid}"
  fi

  export WORDPRESS_DB_ROOT_PASSWORD WORDPRESS_DB_PASSWORD
  export WORDPRESS_DB_USER="wp_user"
  export WORDPRESS_DB_NAME="wordpress"
  export WORDPRESS_ADMIN_USER WORDPRESS_ADMIN_PASSWORD WORDPRESS_ADMIN_EMAIL
  envsubst '${WORDPRESS_DB_ROOT_PASSWORD} ${WORDPRESS_DB_USER} ${WORDPRESS_DB_PASSWORD} ${WORDPRESS_DB_NAME} ${WORDPRESS_ADMIN_USER} ${WORDPRESS_ADMIN_PASSWORD} ${WORDPRESS_ADMIN_EMAIL}' \
    < "${PROJECT_ROOT}/kubernetes/wordpress/secret.yaml" \
    | kubectl apply -f -
}

apply_prestashop_secret() {
  local domain="$1"
  local existing_secret
  if existing_secret="$(kubectl get secret prestashop-credentials -n prestashop --ignore-not-found -o name)" \
    && [[ -n "${existing_secret}" ]]; then
    PRESTASHOP_DB_ROOT_PASSWORD="$(get_secret_value prestashop-credentials prestashop mariadb-root-password)"
    PRESTASHOP_DB_PASSWORD="$(get_secret_value prestashop-credentials prestashop mariadb-password)"
    PRESTASHOP_ADMIN_PASSWORD="$(get_secret_value prestashop-credentials prestashop prestashop-admin-password)"
    PRESTASHOP_ADMIN_EMAIL="$(get_secret_value prestashop-credentials prestashop prestashop-admin-email)"
  else
    PRESTASHOP_DB_ROOT_PASSWORD="$(openssl rand -hex 32)"
    PRESTASHOP_DB_PASSWORD="$(openssl rand -hex 32)"
    PRESTASHOP_ADMIN_PASSWORD="$(openssl rand -hex 32)"
    PRESTASHOP_ADMIN_EMAIL="${PRESTASHOP_ADMIN_EMAIL:-admin@example.invalid}"
  fi

  export PRESTASHOP_DB_ROOT_PASSWORD PRESTASHOP_DB_PASSWORD PRESTASHOP_ADMIN_PASSWORD
  export PRESTASHOP_DB_USER="ps_user"
  export PRESTASHOP_DB_NAME="prestashop"
  export PRESTASHOP_ADMIN_EMAIL
  export PRESTASHOP_DOMAIN="${domain}"
  envsubst '${PRESTASHOP_DB_ROOT_PASSWORD} ${PRESTASHOP_DB_USER} ${PRESTASHOP_DB_PASSWORD} ${PRESTASHOP_DB_NAME} ${PRESTASHOP_ADMIN_EMAIL} ${PRESTASHOP_ADMIN_PASSWORD} ${PRESTASHOP_DOMAIN}' \
    < "${PROJECT_ROOT}/kubernetes/prestashop/secret.yaml" \
    | kubectl apply -f -
}

wait_for_external_ip() {
  local namespace="$1"
  local service="$2"
  local address=""

  for attempt in $(seq 1 60); do
    address="$(kubectl get service "${service}" -n "${namespace}" -o 'jsonpath={.status.loadBalancer.ingress[0].ip}')"
    if [[ -n "${address}" ]]; then
      printf '%s' "${address}"
      return 0
    fi
    if (( attempt % 6 == 0 )); then
      printf 'Waiting for public IP of %s/%s (%s/60)...\n' "${namespace}" "${service}" "${attempt}" >&2
    fi
    sleep 5
  done

  printf 'Timed out waiting for the LoadBalancer IP of %s/%s.\n' "${namespace}" "${service}" >&2
  return 1
}

kubectl apply -f "${PROJECT_ROOT}/kubernetes/namespaces/namespace-wordpress.yaml"
kubectl apply -f "${PROJECT_ROOT}/kubernetes/namespaces/namespace-prestashop.yaml"
kubectl apply -f "${PROJECT_ROOT}/kubernetes/wordpress/pvc.yaml"
kubectl apply -f "${PROJECT_ROOT}/kubernetes/prestashop/pvc.yaml"
apply_wordpress_secret
apply_prestashop_secret localhost

kubectl apply -f "${PROJECT_ROOT}/kubernetes/wordpress/mariadb-service.yaml"
kubectl apply -f "${PROJECT_ROOT}/kubernetes/wordpress/mariadb-deployment.yaml"
kubectl apply -f "${PROJECT_ROOT}/kubernetes/prestashop/mariadb-service.yaml"
kubectl apply -f "${PROJECT_ROOT}/kubernetes/prestashop/mariadb-deployment.yaml"
kubectl rollout status deployment/mariadb -n wordpress --timeout=10m
kubectl rollout status deployment/mariadb -n prestashop --timeout=10m

kubectl apply -f "${PROJECT_ROOT}/kubernetes/wordpress/wordpress-service.yaml"
WORDPRESS_IP="$(wait_for_external_ip wordpress wordpress)"
WORDPRESS_PIP_NAME="$(az network public-ip list \
  --resource-group "${AZURE_NODE_RESOURCE_GROUP}" \
  --query "[?ipAddress=='${WORDPRESS_IP}'].name | [0]" -o tsv)"
if [[ -z "${WORDPRESS_PIP_NAME}" || "${WORDPRESS_PIP_NAME}" == "None" ]]; then
  printf 'Could not find the Azure public IP resource for WordPress address %s.\n' "${WORDPRESS_IP}" >&2
  exit 1
fi
export AZURE_NODE_RESOURCE_GROUP WORDPRESS_PIP_NAME
envsubst '${AZURE_NODE_RESOURCE_GROUP} ${WORDPRESS_PIP_NAME}' \
  < "${PROJECT_ROOT}/kubernetes/prestashop/prestashop-service.yaml" \
  | kubectl apply -f -
PRESTASHOP_IP="$(wait_for_external_ip prestashop prestashop)"

apply_prestashop_secret "${PRESTASHOP_IP}:8080"
kubectl apply -f "${PROJECT_ROOT}/kubernetes/wordpress/wordpress-deployment.yaml"
kubectl apply -f "${PROJECT_ROOT}/kubernetes/prestashop/prestashop-deployment.yaml"
kubectl rollout status deployment/wordpress -n wordpress --timeout=20m
kubectl rollout status deployment/prestashop -n prestashop --timeout=20m

printf '\nWordPress:  http://%s\n' "${WORDPRESS_IP}"
printf 'PrestaShop: http://%s:8080\n' "${PRESTASHOP_IP}"
printf 'PrestaShop admin email: %s\n' "${PRESTASHOP_ADMIN_EMAIL}"
printf 'Generated passwords are stored in Kubernetes Secrets. See README.md to retrieve the PrestaShop admin password.\n'
