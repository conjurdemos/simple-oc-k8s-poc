#!/bin/bash 

source ../config/dap.config

DAP_IMAGES=(
  $CONJUR_APPLIANCE_IMAGE
  $CLI_IMAGE
  $HAPROXY_IMAGE
)

DAP_BINARIES=(
  jq
  summon
  base64
  openssl
  curl
)

DAP_RESOURCES=(
  /usr/local/lib/summon/summon-conjur
)

DAP_NODES=(
  "$CONJUR_MASTER_HOST_NAME"
)

DAP_PORTS=(
  "$CONJUR_MASTER_PORT"
  "$CONJUR_MASTER_PGSYNC_PORT"
  "$CONJUR_MASTER_PGAUDIT_PORT"
  "$CONJUR_FOLLOWER_PORT"
)

DAP_ENV_VARS=(
  "DOCKER_REGISTRY_URL"
  "CONJUR_APPLIANCE_IMAGE"
)

##############################
main() {
  clear
  check_loaded_images
  check_binaries
  check_resources
  check_ports
  check_env_vars
  read -n 1 -s -r -p "Review and press any key to continue..."
  echo
}

##############################
check_loaded_images() {
  echo "Checking for required images:"
  all_found=true
  for image in "${DAP_IMAGES[@]}"; do
    echo -n "  Checking $image: "
    if [[ "$(docker image ls $image | grep -v REPOSITORY)" == "" ]]; then
      echo "not found"
      all_found=false
    else
      echo "loaded"
    fi
  done
  if $all_found; then
    echo "  All images found."
  fi
  echo ""
}

##############################
check_binaries() {
  echo "Checking for required binaries:"
  all_found=true
  for binary in "${DAP_BINARIES[@]}"; do
    if ! command -v "$binary" > /dev/null 2>&1; then
      echo "  $binary - NOT FOUND"
      all_found=false
    fi
  done
  if $all_found; then
    echo "  All required binaries found."
  fi
  echo ""
}

##############################
check_resources() {
  echo "Checking for required resources:"
  all_found=true
  for resource in "${DAP_RESOURCES[@]}"; do
    if [[ ! -f $resource ]]; then
      echo "  $resource - NOT FOUND"
      all_found=false
    fi
  done
  if $all_found; then
    echo "  All required resources found."
  fi
  echo ""
}

##############################
check_ports() {
  echo "Checking for open ports:"
  all_found=true
  for port in "${DAP_PORTS[@]}"; do
    if [[ "$(curl -skS https://$CONJUR_MASTER_HOST_NAME:$port 2>&1 | grep 'Failed to connect')" != "" ]] ; then
      echo "  $node $port - Master not reachable (is it running?)"
      all_found=false
    fi
  done
  if $all_found; then
    echo "  All ports open."
  fi
  echo ""
}

##############################
check_env_vars() {
  echo "Checking environment variables:"
  all_found=true
  for var_name in "${DAP_ENV_VARS[@]}"; do
    if [ "${var_name}" = "" ]; then
      echo "You must set $var_name before running these scripts."
      exit 1
    fi
  done
  if $all_found; then
    echo "  All environment variables set."
  fi
  echo ""
}

main "$@"
