!/bin/bash 
set -uo pipefail

source ../config/dap.config
source ../config/utils.sh

main() {
  precheck.sh
  check_dependencies

  login_as $DAP_ADMIN_USERNAME $DAP_ADMIN_PASSWORD
  ./stop

  initialize_variables
  if $CONJUR_FOLLOWERS_IN_CLUSTER; then
    initialize_config_maps
    registry_login
    deploy_follower_pods
  fi
}

###########################
# Verifies critical environment variables have values
#
check_dependencies() {
  check_env_var "CONJUR_APPLIANCE_IMAGE"
  check_env_var "CONJUR_APPLIANCE_REG_IMAGE"
  check_env_var "CONJUR_NAMESPACE_NAME"
  check_env_var "AUTHENTICATOR_ID"
  check_env_var "DOCKER_REGISTRY_URL"
  check_env_var "CONJUR_MASTER_PORT"
  check_env_var "CONJUR_SEED_FILE_URL"
  check_env_var "SEED_FETCHER_REG_IMAGE"
  if [[ "$(which jq)" == "" ]]; then
    echo "jq not installed."
    exit -1
  fi
}

###################################
initialize_variables() {
  announce "Initializing K8s API variables in DAP Master..."

  TOKEN_SECRET_NAME="$($CLI get secrets -n $CONJUR_NAMESPACE_NAME \
    | grep "${CONJUR_SERVICEACCOUNT_NAME}.*service-account-token" \
    | head -n1 \
    | awk '{print $1}')"

  echo "Initializing cluster ca cert..."
  var_value_add_REST.sh \
    conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/ca-cert \
    "$($CLI get secret -n $CONJUR_NAMESPACE_NAME $TOKEN_SECRET_NAME -o json \
      | jq -r '.data["ca.crt"]' \
      | $BASE64D)"

  echo "Initializing service-account token..."
  var_value_add_REST.sh \
    conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/service-account-token \
    "$($CLI get secret -n $CONJUR_NAMESPACE_NAME $TOKEN_SECRET_NAME -o json \
      | jq -r .data.token \
      | $BASE64D)"

  echo "Initializing cluster API URL..."
  var_value_add_REST.sh \
    conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/api-url \
    "$($CLI config view --minify -o yaml | grep server | awk '{print $2}')"

  verify_k8s_api_access

  echo "K8s API variables initialized."
}

###################################
# Validates access to K8s API with service account credentials in DAP Master.
# This function does three things:
#   - tests secrets retrieval from the DAP Master
#   - ensures the K8s API variables have correctly been populate
#   - validates those credentials actually enable service account authentication
#
verify_k8s_api_access() {
  echo -n "Verifying service account access to K8s API..."

  echo "$(var_value_get_REST.sh conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/ca-cert)" > k8s.crt
  TOKEN=$(var_value_get_REST.sh conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/service-account-token)
  API=$(var_value_get_REST.sh conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/api-url)

  if [[ "$(curl -s --cacert k8s.crt --header "Authorization: Bearer ${TOKEN}" $API/healthz)" == "ok" ]]; then
    echo " VERIFIED."
  else
    echo " >>> NOT VERIFIED. <<<"
    echo "  Values retrieved from DAP Master:"
    echo "   api-url: $API"
    echo "   service-account-token: $TOKEN"
    echo "   ca-cert:"
    cat k8s.crt
    echo
    exit -1
  fi
  rm k8s.crt
}

###################################
# Create config maps for the initial Follower deployment
# Once Follower(s) are deployed, the Conjur config map will be updated w/ Follower URL & cert
#
initialize_config_maps() {
  echo "Creating Conjur config map." 

  # get cert and echo to file for later use
  echo "$(get_cert_REST.sh $CONJUR_MASTER_HOST_NAME $CONJUR_MASTER_PORT)" > $MASTER_CERT_FILE

  # Set Conjur Master URL to DNS hostname & port
  CONJUR_MASTER_URL="https://$CONJUR_MASTER_HOST_NAME:$CONJUR_MASTER_PORT"

  # CONJUR_CONFIG_MAP holds config info for apps in all namespaces
  # Access is gained via rolebinding to a clusterrole
  $CLI delete --ignore-not-found=true -n $CONJUR_NAMESPACE_NAME configmap $CONJUR_CONFIG_MAP
  cat << EOL1 | $CLI -n $CONJUR_NAMESPACE_NAME apply -f - 
apiVersion: v1
kind: ConfigMap
metadata:
  name: "${CONJUR_CONFIG_MAP}"
data:
  FOLLOWER_NAMESPACE_NAME: "${CONJUR_NAMESPACE_NAME}"
  CONJUR_ACCOUNT: "${CONJUR_ACCOUNT}"
  CONJUR_VERSION: "${CONJUR_VERSION}"
  CONJUR_MASTER_URL: "${CONJUR_MASTER_URL}"
  CONJUR_MASTER_PORT: "${CONJUR_MASTER_PORT}"
  CONJUR_MASTER_CERTIFICATE: |
$(cat "${MASTER_CERT_FILE}" | awk '{ print "    " $0 }')
  CONJUR_AUTHN_LOGIN_CLUSTER: "${CONJUR_CLUSTER_LOGIN}"
  CONJUR_AUTHENTICATORS: "${CONJUR_AUTHENTICATORS}"
  AUTHENTICATOR_ID: "${AUTHENTICATOR_ID}"
  CONJUR_APPLIANCE_URL: "https://${CONJUR_FOLLOWER_SERVICE_NAME}"
  CONJUR_AUTHN_URL: "https://${CONJUR_FOLLOWER_SERVICE_NAME}/api/authn-k8s/${AUTHENTICATOR_ID}"
  CONJUR_AUTHN_TOKEN_FILE: "/run/conjur/access-token"
  CONJUR_AUTHN_TOKEN_FILE_INJECTED: "/run/conjur/conjur-access-token"
  CONJUR_SSL_CERTIFICATE: |
$(cat "${FOLLOWER_CERT_FILE}" | awk '{ print "    " $0 }')
EOL1

  # FOLLOWER_CONFIG_MAP holds config info needed by Followers only
  $CLI delete configmap $FOLLOWER_CONFIG_MAP --ignore-not-found=true -n $CONJUR_NAMESPACE_NAME
  cat << EOL | $CLI -n $CONJUR_NAMESPACE_NAME apply -f - 
apiVersion: v1
kind: ConfigMap
metadata:
  name: "${FOLLOWER_CONFIG_MAP}"
data:
  FOLLOWER_HOSTNAME: "conjur-follower" # this should be the same value as the service name
  SEED_FILE_DIR: "/tmp/seedfile"
  CONJUR_SEED_FILE_URL: "${CONJUR_SEED_FILE_URL}"
  CONJUR_AUTHN_LOGIN_CLUSTER: "${CONJUR_CLUSTER_LOGIN}"
  CONJUR_AUTHENTICATORS: "${CONJUR_AUTHENTICATORS}"
EOL

  echo "Conjur & Follower config maps created."
}

###########################
deploy_follower_pods() {
  announce "Deploying Follower pod(s)..."

  sed -e "s#{{ CONJUR_APPLIANCE_IMAGE }}#$CONJUR_APPLIANCE_REG_IMAGE#g" \
     "./manifests/templates/dap-follower-seedfetcher.template.yaml" |
    sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed -e "s#{{ CONJUR_MASTER_HOST_NAME }}#$CONJUR_MASTER_HOST_NAME#g" |
    sed -e "s#{{ CONJUR_MASTER_HOST_IP }}#$CONJUR_MASTER_HOST_IP#g" |
    sed -e "s#{{ CONJUR_MASTER_PORT }}#$CONJUR_MASTER_PORT#g" |
    sed -e "s#{{ CONJUR_SERVICEACCOUNT_NAME }}#$CONJUR_SERVICEACCOUNT_NAME#g" |
    sed -e "s#{{ CONJUR_SEED_FETCHER_IMAGE }}#$SEED_FETCHER_REG_IMAGE#g" |
    sed -e "s#{{ CONJUR_CONFIG_MAP }}#$CONJUR_CONFIG_MAP#g" |
    sed -e "s#{{ FOLLOWER_CONFIG_MAP }}#$FOLLOWER_CONFIG_MAP#g" \
    > ./manifests/dap-follower-$CONJUR_NAMESPACE_NAME.yaml
    $CLI apply -n $CONJUR_NAMESPACE_NAME -f ./manifests/dap-follower-$CONJUR_NAMESPACE_NAME.yaml

  sleep 3
  follower_pod_name=$($CLI get pods -n $CONJUR_NAMESPACE_NAME | grep conjur-follower | tail -1 | awk '{print $1}')
  # Wait for Follower to initialize
  echo "Waiting until Follower is ready (about 40 secs)."
  sleep 3
  while [[ 'True' != $($CLI get po "$follower_pod_name" -n $CONJUR_NAMESPACE_NAME -o 'jsonpath={.status.conditions[?(@.type=="Ready")].status}') ]]; do
    echo -n "."; sleep 3
  done
  echo ""
}

main "$@"
