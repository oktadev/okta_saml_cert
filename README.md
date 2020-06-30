This tool automates most of the process of updating the certificate for your SAML app to a new certificate from a Certificate Authority (CA)

## Requirements

You need to install the following packages:

* [HttPie](https://httpie.org)
* [jq](https://stedolan.github.io/jq/)
* [openssl](https://www.openssl.org/)

### MacOs

Each of these packages can be installed using [Homebrew](https://brew.sh/)

* `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"`
* `brew install httpie`
* `brew install jq`

**Note:** Installing `httpie` automatically installs `openssl`

### Linux

You can use Homebrew with Linux as well. Or, you can use the package manager in your distribution. Here are the commands you would use with Ubuntu and others:

* sudo apt-get install jq
* sudo apt-get install httpie
* openssl is already installed on Linux

### Windows

Running on Windows requires enabling the **Windows Subsystem for Linux**.

Go to: Control Panel > Programs > Turn Windows Features On Or Off. Enable the "Windows Subsystem for Linux" option in the list, and then click the "OK" button.

You'll need to restart Windows.

Then, choose "Get the apps" unter the "Linux on Windows?" banner. There's a number of Linux distributions to choose from. I reccommend Ubuntu. 
Choose a distro and click "Get".

You can then launch the Linux distro by searching for it from the Start menu.

After some one-time setup, you'll be at a bash shell. You can now use the instructions for installing on Linux as above.

## Running
  
### Step 1:

`./okta_saml_cert.sh -o <okta org> -t <api token> [-a <all or part of app label to search for>]`
  
This returns a list of the first 50 apps or apps matching a label that you pass in with the -a param.
  
Ex:
```
./okta_saml_cert.sh -o micah.okta.com -t aaabbbcccddd -a Palo

app id: 0oaeocdejh75p718F1t7, app label: Palo Alto Networks - GlobalProtect, app name: panw_globalprotect

NOTE: Take note of the app id, app label and app name as you will need them later.
```
  
### Step 2:

`./okta_saml_cert.sh -o <okta org> -t <api token> -i <okta app id>`
  
This returns information about the current cert for the app and generates a new certificate signing Request
  
Ex:
```
./okta_saml_cert.sh  -o micah.okta.com -t aaabbbcccddd -i 0oaeod519znhwlx7o1t7"

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
```

**NOTE:** You'll need to use a Certificate Authority (CA) to sign the CSR and get the new certificate. 
https://zerossl.com is one option.

### Step 3 (continues automatically from step 2):

Enter the name of your certificate file (ex: certificate.crt): certificate.crt
Working with: certificate.crt
Is this correct? y
Working with app name: panw_globalprotect and app label: Palo Alto Networks - GlobalProtect

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