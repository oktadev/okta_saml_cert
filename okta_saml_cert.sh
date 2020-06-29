#! /bin/bash

VER=0.0.1

usage () {
  cmd=$(basename $0)
  echo "This tool automates most of the process of updating the certificate for your SAML app."
  echo
  echo "Step 1:"
  echo "${cmd} -o <okta org> -t <api token> [-a <all or part of app label to search for>]"
  echo
  echo This returns a list of the first 50 apps or apps matching a label that you pass in with the -a param.
  echo
  echo "    Ex:"
  echo "    ${cmd} -o micah.okta.com -t aaabbbcccddd -a Palo"
  echo "    app id: 0oaeocdejh75p718F1t7, app label: Palo Alto Networks - GlobalProtect, app name: panw_globalprotect"
  echo
  echo "Step 2:"
  echo "${cmd} -o <okta org> -t <api token> -i <okta app id>"
  echo
  echo This returns information about the current cert for the app and generates a new certificate signing Request
  echo
  echo "    Ex:"
  echo "    ${cmd} -o micah.okta.com -t aaabbbcccddd -i 0oaeod519znhwlx7o1t7"
  cat <<EOF
    Current Cert Info:
    Certificate:
        Data:
            Version: 3 (0x2)
            Serial Number: 1498186828971 (0x15cd2e4ccab)
        Signature Algorithm: sha256WithRSAEncryption
            Issuer: C=US, ST=California, L=San Francisco, O=Okta, OU=SSOProvider, CN=micah/emailAddress=info@okta.com
            Validity
                Not Before: Jun 23 02:59:28 2017 GMT
                Not After : Jun 23 03:00:28 2027 GMT
            Subject: C=US, ST=California, L=San Francisco, O=Okta, OU=SSOProvider, CN=micah/emailAddress=info@okta.com
    ...

    Here's the id for your CSR:
    sLtFipH36rCsefZ0jITKrJL6zhI9h4wlgM17mQGnDZk

    Here's your CSR:
    MIIC5TCCAc0CAQAwdjELMAkGA1UEBhMCVVMxETAPBgNVBAgMCFZpcmdpbmlhMRcwFQY...

    Use this CSR at the SSL Certificate Authority of your choice to get it signed by them.
    Download the certificates and re-run this script with the -c and -d params to upload to Okta.
EOF
  echo "Step 3:"
  echo "${cmd} -o <okta org> -t <api token> -i <okta app id> -c <cert file name> -d <csr id from step 2>"
  echo 
  echo This uploads the new cert for your app and switches the app to use this cert instead of the original
  echo
  echo "    Ex:"
  echo "    ${cmd} -o micah.okta.com -t aaabbbcccddd -i 0oaeod519znhwlx7o1t7"
  cat <<EOF
    Uploading new cert:
    -----BEGIN CERTIFICATE-----
    MIIGdjCCBF6gAwIBAgIQBuS2o/B8gSSMTRBKfbJVRzANBgkqhkiG9w0BAQwFADBL
    ...
    -----END CERTIFICATE-----

    Here is the new key id:
    bb0IebuhX1o94YvcS6ghZotDB0_8q0eqpz0_c-T24MU

    Please supply the following information in order to update your application to use the new key:
    app name (ex: panw_globalprotect): panw_globalprotect
    app label (ex: Palo Alto Networks - GlobalProtect): Palo Alto Networks - GlobalProtect
    About to submit the following json to the apps endpoint:
    {
      "name": "panw_globalprotect",
      "label": "Palo Alto Networks - GlobalProtect",
      "signOnMode": "SAML_2_0",
      "credentials": {
        "signing": {
          "kid": "bb0IebuhX1o94YvcS6ghZotDB0_8q0eqpz0_c-T24MU"
        }
      }
    }

    Current Cert Info:
    Certificate:
        Data:
            Version: 3 (0x2)
            Serial Number:
                06:e4:b6:a3:f0:7c:81:24:8c:4d:10:4a:7d:b2:55:47
        Signature Algorithm: sha384WithRSAEncryption
            Issuer: C=AT, O=ZeroSSL, CN=ZeroSSL RSA Domain Secure Site CA
            Validity
                Not Before: Jun 29 00:00:00 2020 GMT
                Not After : Sep 27 23:59:59 2020 GMT
            Subject: CN=afitnerd.com
    ...
    Please make sure that the new cert information matches what you expect.
EOF
  exit 1
}

requirements () {
  local httpieFound="FOUND"
  local jqFound="FOUND"
  local opensslFound="FOUND"

  hash http 2>/dev/null || httpieFound="NOT FOUND"
  hash jq 2>/dev/null || jqFound="NOT FOUND"
  hash openssl 2>/dev/null || opensslFound="NOT FOUND"

  if [[ ${httpieFound} != "FOUND" || ${jqFound} != "FOUND" || ${opensslFound} != "FOUND" ]]
    then
      echo "Some requirements are not met:"
      echo
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
    local method=$3
    local content_type=$4

    if [[ -z ${content_type} ]]
      then
        content_type="application/json"
    fi

    if [[ -z ${method} ]]
      then
        method="POST"
    fi

    if [[ -z ${body} ]]
      then
        result=$(http https://${OKTA_ORG}${endpoint} Authorization:"SSWS ${OKTA_API_TOKEN}")
    else
        result=$(echo "${body}" | http ${method} https://${OKTA_ORG}${endpoint} Authorization:"SSWS ${OKTA_API_TOKEN}" Content-Type:"${content_type}")
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

    echo
    echo NOTE: Take note of the app id, app label and app name as you will need them later.
}

check_input() {
  local error_text=$1
  local val=$2

  if [[ -z ${val} ]]
    then
      echo "${error_text} is required"
      exit 1
  fi
}

metadata() {
  api /api/v1/apps/${OKTA_APP_ID}/sso/saml/metadata
  CERT=$(echo ${result} | sed -e "s/^.*<ds:X509Certificate/<ds:X509Certificate/" | sed -e "s/<ds:X509Certificate>//g" | sed -e "s/<\/ds:X509Certificate>//g" | awk -F"<" '{print $1}' | tr " " "\n")
  echo "Current Cert Info:"
  echo $'-----BEGIN CERTIFICATE-----\n'"${CERT}"$'\n-----END CERTIFICATE-----\n' | openssl x509 -text -noout
}

do_csr() {
  metadata
  echo
  echo "Please supply the following information to generate a new Certificate Signing Request:"
  read -p "country name (ex: US): " COUNTRY_NAME
  check_input "country name" ${COUNTRY_NAME}
  read -p "state or province name (ex: California): " STATE_NAME
  check_input "state or province name" ${STATE_NAME}
  read -p "locality name (ex: San Francisco): " LOCALITY_NAME
  check_input "locality name" ${LOCALITY_NAME}
  read -p "organization name: " ORG_NAME
  check_input "organization name" ${ORG_NAME}
  read -p "organlizational unit name: " ORG_UNIT_NAME
  check_input "organlizational unit name" ${ORG_UNIT_NAME}
  read -p "common name (ex: login.example.com): " COMMON_NAME
  check_input "common name" ${COMMON_NAME}

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
  
  echo
  echo "Here's the id for your CSR:"
  echo ${result} | jq -r .id
  echo
  echo "Here's your CSR:"
  echo ${result} | jq -r .csr
  echo
  echo Use this CSR at the SSL Certificate Authority of your choice to get it signed by them.
  echo Download the certificates and re-run this script with the -c and -d params to upload to Okta.
}

do_cert_upload() {
  CERT=$(cat ${CERT_FILE_NAME})

  echo "Uploading new cert:"
  echo "${CERT}"
  echo

  api /api/v1/apps/${OKTA_APP_ID}/credentials/csrs/${OKTA_CSR_ID}/lifecycle/publish "${CERT}" POST "application/x-pem-file"

  KID=$(echo ${result} | jq -r .kid)

  echo "Here is the new key id:"
  echo ${KID}
  echo

  echo "Please supply the following information in order to update your application to use the new key:"
  read -p "app name (ex: panw_globalprotect): " APP_NAME
  check_input "app name" ${APP_NAME}
  read -p "app label (ex: Palo Alto Networks - GlobalProtect): " APP_LABEL
  check_input "app labe" ${APP_LABEL}

  read -r -d '' JSON <<EOF
{
  "name": "${APP_NAME}",
  "label": "${APP_LABEL}",
  "signOnMode": "SAML_2_0",
  "credentials": {
    "signing": {
      "kid": "${KID}"
    }
  }
}
EOF

  echo "About to submit the following json to the apps endpoint:"
  echo "${JSON}"

  JSON_COMPACT=$(echo ${JSON} | tr "\n" " ")

  api "/api/v1/apps/${OKTA_APP_ID}" "${JSON_COMPACT}" "PUT"

  echo
  metadata

  echo "Please make sure that the new cert information matches what you expect."
}

while getopts ":o:t:a:i:c:d:" opt; do
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
    d)
      OKTA_CSR_ID=$OPTARG
      ;;
    c )
      CERT_FILE_NAME=$OPTARG
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

requirements

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

if [[ -n ${CERT_FILE_NAME} ]] && [[ -z ${OKTA_APP_ID} || -z ${OKTA_CSR_ID} ]]
  then
    echo "if you specify a certificate file name with -c you must also have an okta app id with -i and a csr id with -d"; echo; usage
fi

if [[ -n ${OKTA_APP_ID} && -z ${CERT_FILE_NAME} ]]
  then
    do_csr
elif [[ -n ${OKTA_APP_ID} && -n ${CERT_FILE_NAME} && -n ${OKTA_CSR_ID} ]]
  then
    do_cert_upload
else
    apps
fi