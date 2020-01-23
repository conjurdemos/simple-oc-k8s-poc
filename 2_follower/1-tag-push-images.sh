#!/bin/bash
set -ou pipefail

source ../config/dap.config
source ../config/utils.sh

# As DAP Admin:
#  - tags local appliance image and pushes to registry.
#
# Registry image tags are:
#   - $CONJUR_APPLIANCE_REG_IMAGE
# defined in the $PLATFORM.config file and referenced in deployment manifests.

./precheck_k8s_followers.sh

login_as $DAP_ADMIN_USERNAME $DAP_ADMIN_PASSWORD

registry_login

announce "Tagging & pushing local docker images to registry"

docker tag $CONJUR_APPLIANCE_IMAGE $CONJUR_APPLIANCE_REG_IMAGE
#docker tag $SEED_FETCHER_IMAGE $SEED_FETCHER_REG_IMAGE 

if ! $MINIKUBE; then
  docker push $CONJUR_APPLIANCE_REG_IMAGE
#  docker push $SEED_FETCHER_REG_IMAGE
fi

announce "Images pushed to registry"
