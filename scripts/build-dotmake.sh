#!/bin/bash

echo 'Please fill in the config settings to store in your .make.'
echo 'Defaults are shown in parens.  <Enter> to accept.'
echo
read -p 'Domain ("buildit.tools"): ' domain
read -p 'AWS SSH keyname: ' keyname
read -p 'Owner of riglet: ' owner
read -p 'AWS Profile ("default"): ' profile
read -p 'Project ("reference"): ' project
read -p 'AWS region ("us-east-1"): ' region
read -p 'AWS Certificate Manager GUID (NO DEFAULT.  Use buildit.tools cert GUID for your region.): ' domain_guid
echo

cat << EOF > .make
DOMAIN = ${domain:-buildit.tools}
KEY_NAME = ${keyname}
OWNER = ${owner}
PROFILE = ${profile:-default}
PROJECT = ${project:-reference}
REGION = ${region:-us-east-1}
DOMAIN_CERT = ${domain_guid}
EOF

echo 'Saved .make!'
echo 'Please verify with "make check-env"!'
echo

