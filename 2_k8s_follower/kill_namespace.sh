#!/bin/bash
set -euo pipefail

source ../config/dap.config
source ../config/$PLATFORM.config
source ../config/utils.sh

set_namespace default

$CLI delete cm $CONJUR_CONFIG_MAP -n default --ignore-not-found

if has_namespace $CONJUR_NAMESPACE_NAME; then
  $CLI delete namespace $CONJUR_NAMESPACE_NAME >& /dev/null &

  printf "Waiting for $CONJUR_NAMESPACE_NAME namespace deletion to complete"

  while : ; do
    printf "..."
    
    if has_namespace "$CONJUR_NAMESPACE_NAME"; then
      sleep 5
    else
      break
    fi
  done

  echo ""
fi

echo "Conjur environment purged."
