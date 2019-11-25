#!/bin/bash

######################
# Use a cap-D for decoding on Macs
if [[ "$(uname -s)" == "Linux" ]]; then
  BASE64D="base64 -d"
else
  BASE64D="base64 -D"
fi

######################
check_env_var() {
  var_name=$1

  if [ "${var_name}" = "" ]; then
    echo "You must set $1 before running these scripts."
    exit 1
  fi
}

######################
# Login with username parameter if in OpenShift
#
login_as() {
  local user=$1
  if [[ "$PLATFORM" == "openshift" ]]; then
    oc login -u $user
  fi
}

######################
registry_login() {
  if [[ "${PLATFORM}" = "openshift" ]]; then
    docker login -u _ -p $(oc whoami -t) $DOCKER_REGISTRY_URL
  else
    if ! [ "${DOCKER_EMAIL}" = "" ]; then
      $CLI delete --ignore-not-found secret dockerpullsecret
      $CLI create secret docker-registry dockerpullsecret \
           --docker-server=$DOCKER_REGISTRY_URL \
           --docker-username=$DOCKER_USERNAME \
           --docker-password=$DOCKER_PASSWORD \
           --docker-email=$DOCKER_EMAIL
    fi
  fi
}

######################
announce() {
  echo "++++++++++++++++++++++++++++++++++++++"
  echo ""
  echo "$@"
  echo ""
  echo "++++++++++++++++++++++++++++++++++++++"
}

######################
has_namespace() {
  if $CLI get namespace "$1" &> /dev/null; then
    true
  else
    false
  fi
}

######################
has_serviceaccount() {
  $CLI get serviceaccount "$1" &> /dev/null;
}

######################
copy_file_to_container() {
  local from=$1
  local to=$2
  local pod_name=$3

  $CLI cp "$from" $pod_name:"$to"
}

######################
get_master_pod_name() {
  pod_list=$($CLI get pods -l app=conjur-master-node --no-headers | awk '{ print $1 }')
  echo $pod_list | awk '{print $1}'
}

######################
get_master_service_ip() {
  echo $($CLI get service conjur-master -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
}

######################
get_conjur_cli_pod_name() {
  pod_list=$($CLI get pods -l app=conjur-cli --no-headers | awk '{ print $1 }')
  echo $pod_list | awk '{print $1}'
}

######################
set_namespace() {
  if [[ $# != 1 ]]; then
    printf "Error in %s/%s - expecting 1 arg.\n" $(pwd) $0
    exit -1
  fi

  $CLI config set-context $($CLI config current-context) --namespace="$1" > /dev/null
}

######################
wait_for_node() {
  wait_for_it -1 "$CLI describe pod $1 | grep Status: | grep -q Running"
}

######################
wait_for_service() {
  wait_for_it -1 "$CLI get service $1 --no-headers | grep -q -v pending"
}

######################
wait_for_it() {
  local timeout=$1
  local spacer=2
  shift

  if ! [ $timeout = '-1' ]; then
    local times_to_run=$((timeout / spacer))

    echo "Waiting for '$@' up to $timeout s"
    for i in $(seq $times_to_run); do
      eval $@ && echo 'Success!' && break
      echo -n .
      sleep $spacer
    done

    eval $@
  else
    echo "Waiting for '$@' forever"

    while ! eval $@; do
      echo -n .
      sleep $spacer
    done
    echo 'Success!'
  fi
}

######################
rotate_api_key() {
  set_namespace $CONJUR_NAMESPACE_NAME

  master_pod_name=$(get_master_pod_name)

  $CLI exec $master_pod_name -- conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD > /dev/null
  api_key=$($CLI exec $master_pod_name -- conjur user rotate_api_key)
  $CLI exec $master_pod_name -- conjur authn logout > /dev/null

  echo $api_key
}

######################
wait_for_running_pod() {
  local pod_name=$1; shift
  local pod_namespace=$1; shift
  # until there's at least one pod with that substring in its name that's Running
  until [ "" != "$($CLI get pods -n $pod_namespace --no-headers | grep $pod_name | grep Running)" ]; do
    echo -n '.'
    sleep 2
  done
  echo
}

