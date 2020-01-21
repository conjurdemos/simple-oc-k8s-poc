#!/bin/bash
set -euo pipefail

source ../config/dap.config
source ../config/utils.sh

login_as $CLUSTER_ADMIN_USERNAME

echo "Deleting instantiated manifests..."
rm -f manifests/*.yaml

echo "Deleting Follower pods."
$CLI delete --ignore-not-found deployment/conjur-follower --force=true --grace-period=0
$CLI delete --ignore-not-found svc/conjur-follower --force=true --grace-period=0

echo "Deleting server-certificate config map."
$CLI delete --ignore-not-found cm $CONJUR_CONFIG_MAP

echo "Deleting cluster roles, role bindings and service accounts."
$CLI delete --ignore-not-found clusterrole conjur-authenticator-$CONJUR_NAMESPACE_NAME
$CLI delete --ignore-not-found rolebinding conjur-authenticator-role-binding-$CONJUR_NAMESPACE_NAME
$CLI delete --ignore-not-found sa $CONJUR_SERVICEACCOUNT_NAME

echo "Waiting for Conjur pods to terminate..."
while [[ "$($CLI get pods -n $CONJUR_NAMESPACE_NAME 2>&1 | grep conjur-follower)" != "" ]]; do
  echo -n '.'
  sleep 3
done 
echo
echo "Followers deleted."

echo "Conjur environment cleaned."
