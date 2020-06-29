#! /bin/bash

VER=0.0.1

usage () {
  echo "blarg"
  exit 1
}

requirements () {
  local httpieFound="FOUND"
  local jqFound="FOUND"
  local base64Found="FOUND"
  local opensslFound="FOUND"

  hash http 2>/dev/null || httpieFound="NOT FOUND"
  hash jq 2>/dev/null || jqFound="NOT FOUND"
  hash base64 2>/dev/null || base64Found="NOT FOUND"
  hash openssl 2>/dev/null || opensslFound="NOT FOUND"

  if [[ ${httpieFound} != "FOUND" || ${jqFound} != "FOUND" || ${base64Found} != "FOUND" || ${opensslFound} != "FOUND" ]]
    then
      echo "Some requirements are not met:"
      echo
      echo "base64 is ${base64Found}"
      echo "httpie is ${httpieFound}"
      echo "jq is ${jqFound}"
      echo "openssl is ${opensslFound}"
      echo
      echo "These tools can be installed with brew on mac."
      echo "for more information, go to: https://brew.sh"
      exit 1
  fi
}

api() {
    local endpoint=$1
    local request=$2

    result=$(http https://${OKTA_ORG}${endpoint} Authorization:"SSWS ${OKTA_API_TOKEN}")
}

apps() {
    api /api/v1/apps
    if [[ -n ${OKTA_APP_NAME} ]];
      then
        echo ${result} | jq -r --arg OKTA_APP_NAME "${OKTA_APP_NAME}" '.[] | select(.label | contains($OKTA_APP_NAME)) | "app id: " + .id + ", app label: " + .label + ", app name: " + .name'
    else
        echo ${result} | jq -r '.[] | "app id: " + .id + ", app label: " + .label + ", app name: " + .name'
    fi
}

while getopts ":o:t:a:" opt; do
  case ${opt} in
    o )
      OKTA_ORG=$OPTARG
      ;;
    t )
      OKTA_API_TOKEN=$OPTARG
      ;;
    a )
      OKTA_APP_NAME=$OPTARG
      ;;
    : )
      echo "Invalid option: -$OPTARG requires and argument" 1>&2
      echo
      usage
      ;;
    \? ) usage
      ;;
  esac
done
shift $((OPTIND -1))

if [[ -z ${OKTA_ORG} ]]
  then
    echo "-o is required"; echo; usage
fi

if [[ -z ${OKTA_API_TOKEN} ]]
  then
    echo "-t is required"; echo; usage
fi

apps