#!/bin/bash 
set -euo pipefail

source ../config/dap.config
source ../config/$PLATFORM.config
source ../config/utils.sh

if has_namespace $TEST_APP_NAMESPACE_NAME; then
  if [[ "$PLATFORM" == "openshift" ]]; then
    $CLI delete project $TEST_APP_NAMESPACE_NAME 
  else
    $CLI delete namespace $TEST_APP_NAMESPACE_NAME >& /dev/null &
  fi

  printf "Waiting for $TEST_APP_NAMESPACE_NAME namespace deletion to complete"

  while : ; do
    printf "."
    
    if has_namespace $TEST_APP_NAMESPACE_NAME; then
      sleep 2
    else
      break
    fi
  done

  echo ""
fi

set +e
test_sidecar_app_docker_image=$(repo_image_tag test-sidecar-app $TEST_APP_NAMESPACE_NAME)
test_init_app_docker_image=$(repo_image_tag test-init-app $TEST_APP_NAMESPACE_NAME)
docker rmi $test_sidecar_app_docker_image $test_init_app_docker_image &> /dev/null

echo "Test app environment purged."
