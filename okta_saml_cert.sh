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
    local body=$2

    if [[ -z ${body} ]]
      then
        result=$(http https://${OKTA_ORG}${endpoint} Authorization:"SSWS ${OKTA_API_TOKEN}")
    else
        result=$(echo ${body} | http POST https://${OKTA_ORG}${endpoint} Authorization:"SSWS ${OKTA_API_TOKEN}")
    fi
}

apps() {
    api "/api/v1/apps?limit=100"
    if [[ -n ${OKTA_APP_NAME} ]];
      then
        echo ${result} | jq -r --arg OKTA_APP_NAME "${OKTA_APP_NAME}" '.[] | select(.label | contains($OKTA_APP_NAME)) | "app id: " + .id + ", app label: " + .label + ", app name: " + .name'
    else
        echo ${result} | jq -r '.[] | "app id: " + .id + ", app label: " + .label + ", app name: " + .name'
    fi
}

do_csr() {
  api /api/v1/apps/${OKTA_APP_ID}/sso/saml/metadata
  CERT=$(echo ${result} | sed -e "s/^.*<ds:X509Certificate/<ds:X509Certificate/" | sed -e "s/<ds:X509Certificate>//g" | sed -e "s/<\/ds:X509Certificate>//g" | awk -F"<" '{print $1}' | tr " " "\n")
  echo "Current Cert Info:"
  echo $'-----BEGIN CERTIFICATE-----\n'"${CERT}"$'\n-----END CERTIFICATE-----\n' | openssl x509 -text -noout

  echo
  echo "Please supply the following information to generate a new Certificate Signing Request:"
  read -p "country name (ex: US): " COUNTRY_NAME
  read -p "state or province name (ex: California): " STATE_NAME
  read -p "locality name (ex: San Francisco): " LOCALITY_NAME
  read -p "organization name: " ORG_NAME
  read -p "organlizational unit name: " ORG_UNIT_NAME
  read -p "common name (ex: login.example.com): " COMMON_NAME

  read -r -d '' JSON <<EOF
{
      "subject": {
        "countryName": "${COUNTRY_NAME}",
        "stateOrProvinceName": "${STATE_NAME}",
        "localityName": "${LOCALITY_NAME}",
        "organizationName": "${ORG_NAME}",
        "organizationalUnitName": "${ORG_UNIT_NAME}",
        "commonName": "${COMMON_NAME}"
      },
      "subjectAltNames": {
        "dnsNames": ["${COMMON_NAME}"]
      }
}
EOF

  echo "About to submit the following json to the csrs endpoint:"
  echo "${JSON}"

  JSON_COMPACT=$(echo ${JSON} | tr "\n" " ")
  api "/api/v1/apps/${OKTA_APP_ID}/credentials/csrs" "${JSON_COMPACT}"
  
  echo "Here's your CSR:"
  echo
  echo ${result} | jq -r .csr
  echo
  echo Use this CSR at the SSL Certificate Authority of your choice to get it signed by them.
  echo Download the certificates and re-run this script with the -c param to upload to Okta.
}

while getopts ":o:t:a:i:" opt; do
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
    i )
      OKTA_APP_ID=$OPTARG
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

if [[ -n ${OKTA_APP_ID} && -n ${OKTA_APP_NAME} ]]
  then
    echo "specify either -a or -i, not both"; echo; usage
fi

if [[ -n ${OKTA_APP_ID} ]]
  then
    do_csr  
else
    apps
fi