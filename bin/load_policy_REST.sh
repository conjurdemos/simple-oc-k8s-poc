#!/bin/bash

		# magic that sets DAP_HOME to parent directory of this script
DAP_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
source $DAP_HOME/config/dap.config

# Authenticates as admin user and loads policy file 

AUTHN_USERNAME=admin
AUTHN_PASSWORD=$CONJUR_ADMIN_PASSWORD
AUTHN_TOKEN=""

################  MAIN   ################
# $1 - name of policy file to load
main() {

  if [[ $# < 2 ]] ; then
    printf "\nUsage: %s <policy-branch-id> <policy-filename> [ delete | replace ]\n" $0
    printf "\nExamples:\n"
    printf "\t$> %s root /tmp/policy.yml\n" $0
    printf "\t$> %s dev/my-app /tmp/policy.yml\n" $0
    printf "\nDefault is append mode, unless 'delete' or 'replace' is specified\n"
    exit -1
  fi
  local policy_branch=$1
  local policy_file=$2

  local LOAD_MODE="POST"
  if [[ $# == 3 ]]; then
    case $3 in
      delete)   LOAD_MODE="PATCH"
		;;
      replace)  LOAD_MODE="PUT"
		;;
      *)	printf "\nSpecify 'delete' or 'replace' as load mode options.\n\n"
		exit -1
    esac
  fi

  authn_user   # authenticate user
  if [[ "$AUTHN_TOKEN" == "" ]]; then
    echo "Authentication failed..."
    exit -1
  fi

  # The are SIGNIFICANT differences between PUT, POST and PATCH request methods:
  #
  # - POST implements the default CLI policy load APPEND semantics. It adds data to 
  #     the existing Conjur policy. Deletions are not allowed. Any policy 
  #     objects that exist on the server but that are omitted from the policy 
  #     file will not be deleted, and any explicit deletions in the policy 
  #     file will result in an error. While not destructive, use of this method
  #     can result in a policy file that does not reflect the actual policy
  #     in effect.
  # - PATCH implements the CLI policy load DELETE flag semantics. It modifies an
  #     existing Conjur policy. Data may be explicitly deleted using the 
  #     !delete, !revoke, and !deny statements. Unlike “replace” mode, no 
  #     data is ever implicitly deleted. Use of this method makes all policy
  #     changes explicit, supporting a kind of audit trail that shows the
  #     evolution of the policy.
  # - PUT implements the CLI policy load REPLACE flag semantics. Any policy data 
  #     which already exists on the server at the policy branch but that is not
  #     EXPLICITLY specified in the new policy file WILL BE DELETED. It is
  #     potentially very destructive and should be used with caution.

  curl -sk \
     -H "Content-Type: application/json" \
     -H "Authorization: Token token=\"$AUTHN_TOKEN\"" \
     -X $LOAD_MODE -d "$(< $policy_file)" \
     $CONJUR_APPLIANCE_URL/policies/$CONJUR_ACCOUNT/policy/$policy_branch
  echo
}

##################
# AUTHN USER - sets AUTHN_TOKEN globally
# - no arguments
authn_user() {
  # Login user, authenticate and get API key for session
  local api_key=$(curl \
                    -sk \
                    --user $AUTHN_USERNAME:$AUTHN_PASSWORD \
                    $CONJUR_APPLIANCE_URL/authn/$CONJUR_ACCOUNT/login)

  local response=$(curl -sk \
                     --data $api_key \
                     $CONJUR_APPLIANCE_URL/authn/$CONJUR_ACCOUNT/$AUTHN_USERNAME/authenticate)
  AUTHN_TOKEN=$(echo -n $response| base64 | tr -d '\r\n')
}

main "$@"
