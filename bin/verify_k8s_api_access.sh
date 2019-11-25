#!/bin/bash
				# set DAP_HOME to parent directory of this script
DAP_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
source $DAP_HOME/config/dap.config
source $DAP_HOME/config/$PLATFORM.config

# if not using DAP demo framework, set these values:
# CONJUR_APPLIANCE_URL
# CONJUR_ACCOUNT
# AUTHENTICATOR_ID

###################################
# Usage: verify_k8s_api_access.sh [ <api-string> [ <rep-count> [ <sleep-secs> ] ] ]
#
# Authenticates as admin user and uses service account credentials in DAP Master
# to validate access to K8s API. If no API string is provided, dumps list of K8s APIs.
#
# Note that this script does NOT use the DAP server cert to encrypt wire traffic.
#
# This script does four things:
#   - Tests secrets retrieval from the DAP Master.
#   - Ensures the K8s API connection variables have been correctly populated.
#   - Confirms those credentials actually enable service account authentication.
#   - Supports testing of API throttling by specifying rep count and sleep pauses.

AUTHN_USERNAME=admin
AUTHN_PASSWORD=$CONJUR_ADMIN_PASSWORD
AUTHN_TOKEN=""

main() {
  API_STRING=""
  if [[ $# > 0 ]]; then		# Arg 1 (if any) is the api string
    API_STRING=$1
  fi
  REP_COUNT=1
  if [[ $# > 1 ]]; then		# Arg 2 (if any) is the rep count
    REP_COUNT=$2
  fi
  SLEEP_SECS=0
  if [[ $# > 2 ]]; then		# Arg 3 (if any) is the sleep seconds
    SLEEP_SECS=$3
  fi
  authn_user $AUTHN_USERNAME $AUTHN_PASSWORD
  verify_k8s_api_access 
}

###################################
verify_k8s_api_access() {
  echo "$(var_value_get conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/ca-cert)" > k8s.crt
  TOKEN=$(var_value_get conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/service-account-token)
  API=$(var_value_get conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/api-url)

  for ((i = 0 ; i <= $REP_COUNT ; i++)); do
    status=$(curl -s --cacert k8s.crt --header "Authorization: Bearer ${TOKEN}" $API/$API_STRING) 
    sleep $SLEEP_SECS
  done
  if [[ $status == {* ]]; then	# if output starts w/ curly brace, assume JSON
    echo $status | jq 
  else
    echo "$status"
  fi
  rm k8s.crt
}

##################
var_value_get() {
  local var_name=$1; shift
  local urlified_var_name=$(urlify "$var_name")

  curl -sk \
        -H "Content-Type: application/json" \
        -H "Authorization: Token token=\"$AUTHN_TOKEN\"" \
     $CONJUR_APPLIANCE_URL/secrets/$CONJUR_ACCOUNT/variable/$urlified_var_name
}

##################
# AUTHN USER - sets AUTHN_TOKEN globally
#
authn_user() {
  local username=$1; shift
  local pwd=$1; shift

  # Login user, authenticate and get API key for session
  local api_key=$(curl \
                    -sk \
                    --user $username:$pwd \
                    $CONJUR_APPLIANCE_URL/authn/$CONJUR_ACCOUNT/login)

  local response=$(curl -sk \
                     --data $api_key \
                     $CONJUR_APPLIANCE_URL/authn/$CONJUR_ACCOUNT/$username/authenticate)
  AUTHN_TOKEN=$(echo -n $response| base64 | tr -d '\r\n')
}

################
# URLIFY - url encodes input string
# in: $1 - string to encode
# out: urlified string echoed to stdout
urlify() {
        local str=$1; shift
        str=$(echo $str | sed 's= =%20=g')
        str=$(echo $str | sed 's=&=%26=g')
        str=$(echo $str | sed 's=+=%2B=g')
        str=$(echo $str | sed 's=/=%2F=g')
        str=$(echo $str | sed 's=:=%3A=g')
        str=$(echo $str | sed 's=@=%40=g')
        echo $str
}

main "$@"
