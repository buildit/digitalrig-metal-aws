#!/bin/bash

echo 'Please fill in the config settings to store in your .make.'
echo 'Defaults are shown in parens.  <Enter> to accept.'
echo
read -p 'Owner of riglet: ' owner
read -p 'Project ("reference"): ' project
read -p 'AWS region ("us-east-1"): ' region
read -p 'AWS Profile ("default"): ' profile
echo

cat << EOF > .make
OWNER = ${owner}
PROJECT = ${project:-reference}
PROFILE = ${profile:-default}
REGION = ${region:-us-east-1}
EOF

echo 'Saved .make!'
echo 'Please verify with "make check-env"!'
echo
