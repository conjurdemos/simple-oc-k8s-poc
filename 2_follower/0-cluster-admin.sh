#!/bin/bash
set -ou pipefail

source ../config/dap.config
source ../config/utils.sh

# As Cluster Admin, applies manifests to:
#  - create namespace
#  - create Follower service account
#  - create authenticator cluster role
#  - create authenticator cluster role binding
# and with cli:
#  - adds scc anyuid to Follower service account

./precheck_k8s_followers.sh

login_as $CLUSTER_ADMIN_USERNAME $CLUSTER_ADMIN_PASSWORD


announce "Applying Follower authn-k8s manifest..."

sed -e "s#{{ CONJUR_NAMESPACE_NAME }}#$CONJUR_NAMESPACE_NAME#g" \
     ./manifests/templates/dap-follower-authn.template.yaml  |
     sed -e "s#{{ CONJUR_SERVICEACCOUNT_NAME }}#$CONJUR_SERVICEACCOUNT_NAME#g" \
     > ./manifests/dap-follower-authn-$CONJUR_NAMESPACE_NAME.yaml

$CLI apply -f ./manifests/dap-follower-authn-$CONJUR_NAMESPACE_NAME.yaml -n $CONJUR_NAMESPACE_NAME

if [[ "$PLATFORM" != "openshift" ]]; then
  exit 0
fi

announce "Applying RBAC manifest..."

if [[ "$($CLI get user $DAP_ADMIN_USERNAME --no-headers)" == "" ]]; then
  $CLI create user $DAP_ADMIN_USERNAME
  $CLI create useridentitymapping anypassword:$DAP_ADMIN_USERNAME $DAP_ADMIN_USERNAME
fi

sed -e "s#{{ CONJUR_NAMESPACE_NAME }}#$CONJUR_NAMESPACE_NAME#g"   \
     ./manifests/templates/dap-user-rbac.template.yaml           |
    sed -e "s#{{ CONJUR_CONFIG_MAP }}#$CONJUR_CONFIG_MAP#g" |
    sed -e "s#{{ DAP_ADMIN_USERNAME }}#$DAP_ADMIN_USERNAME#g" \
    > ./manifests/dap-user-rbac-$CONJUR_NAMESPACE_NAME.yaml

$CLI apply -f ./manifests/dap-user-rbac-$CONJUR_NAMESPACE_NAME.yaml

# this requirement goes away w/ the deconstructed Follower architecture
$CLI adm policy add-scc-to-user anyuid -z $CONJUR_SERVICEACCOUNT_NAME -n $CONJUR_NAMESPACE_NAME

announce "Follower manifests applied."
