#!/bin/bash
set -euo pipefail

source ../config/dap.config
source ../config/$PLATFORM.config
source ../config/utils.sh

set_namespace default

$CLI delete cm $CONJUR_CONFIG_MAP -n default --ignore-not-found
$CLI delete clusterrole conjur-authenticator --ignore-not-found
$CLI delete clusterrolebinding conjur-authenticator --ignore-not-found

if has_namespace $CONJUR_NAMESPACE_NAME; then
  if [[ "$PLATFORM" == "openshift" ]]; then
    $CLI delete project $CONJUR_NAMESPACE_NAME
  else
    $CLI delete namespace $CONJUR_NAMESPACE_NAME >& /dev/null &
  fi

  printf "Waiting for $CONJUR_NAMESPACE_NAME namespace deletion to complete"

  while : ; do
    printf "."
    
    if has_namespace "$CONJUR_NAMESPACE_NAME"; then
      sleep 2
    else
      break
    fi
  done

  echo ""
fi

set +e
conjur_appliance_image=$(repo_image_tag conjur-appliance $CONJUR_NAMESPACE_NAME)
seed_fetcher_image_tag=$(repo_image_tag seed-fetcher $CONJUR_NAMESPACE_NAME)
docker rmi $conjur_appliance_image $seed_fetcher_image_tag &> /dev/null

echo "Conjur environment purged."
