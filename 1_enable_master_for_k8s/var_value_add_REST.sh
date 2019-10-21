#!/bin/bash

source ../config/dap.config

# Authenticates as admin user and sets value of a specified variable

AUTHN_USERNAME=admin
AUTHN_PASSWORD=$CONJUR_ADMIN_PASSWORD
AUTHN_TOKEN=""

################  MAIN   ################
# $1 - name of variable
# $2 - value to assign
main() {

  if [[ $# -ne 2 ]] ; then
    printf "\nUsage: %s <variable-name> <variable-value>\n" $0
    exit -1
  fi
  local variable_name=$1
  local variable_value=$2

  authn_user   # authenticate user
  if [[ "$AUTHN_TOKEN" == "" ]]; then
    echo "Authentication failed..."
    exit -1
  fi

  urlify "$variable_name"
  variable_name=$URLIFIED

  curl -sk \
	-H "Content-Type: application/json" \
	-H "Authorization: Token token=\"$AUTHN_TOKEN\"" \
     --data "$variable_value" \
     $CONJUR_APPLIANCE_URL/secrets/$CONJUR_ACCOUNT/variable/$variable_name
}

##################
# AUTHN USER - sets AUTHN_TOKEN globally
# - no arguments
authn_user() {
  # Login user, authenticate and set authn token
  local api_key=$(curl \
                    -sk \
                    --user $AUTHN_USERNAME:$AUTHN_PASSWORD \
                    $CONJUR_APPLIANCE_URL/authn/$CONJUR_ACCOUNT/login)

  local response=$(curl -sk \
                     --data $api_key \
                     $CONJUR_APPLIANCE_URL/authn/$CONJUR_ACCOUNT/$AUTHN_USERNAME/authenticate)
  AUTHN_TOKEN=$(echo -n $response| base64 | tr -d '\r\n')
}

################
# URLIFY - url encodes input string
# in: $1 - string to encode
# out: URLIFIED - global variable containing encoded string
urlify() {
        local str=$1; shift
        str=$(echo $str | sed 's= =%20=g')
        str=$(echo $str | sed 's=/=%2F=g')
        str=$(echo $str | sed 's=:=%3A=g')
        str=$(echo $str | sed 's=+=%2B=g')
        str=$(echo $str | sed 's=&=%26=g')
        str=$(echo $str | sed 's=@=%40=g')
        URLIFIED=$str
}

main "$@"
