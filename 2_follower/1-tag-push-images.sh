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

precheck.sh

login_as $DAP_ADMIN_USERNAME

registry_login

announce "Tagging & pushing local docker images to registry"

docker tag $CONJUR_APPLIANCE_IMAGE $CONJUR_APPLIANCE_REG_IMAGE

if ! $MINIKUBE; then
  docker push $CONJUR_APPLIANCE_REG_IMAGE
fi

announce "Images pushed to registry"
