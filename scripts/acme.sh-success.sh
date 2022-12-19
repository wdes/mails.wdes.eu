#!/bin/sh

set -e

# shellcheck disable=SC2154
rm -rvf "/acme.sh/${DOMAIN_NAME}-mirror1"
mkdir -p "/acme.sh/${DOMAIN_NAME}-mirror1"
cp -v "/acme.sh/${DOMAIN_NAME}/"*.cer "/acme.sh/${DOMAIN_NAME}-mirror1"
cp -v "/acme.sh/${DOMAIN_NAME}/"*.key "/acme.sh/${DOMAIN_NAME}-mirror1"
echo 'Mirrors are done.'

chmod 777 -R "/acme.sh/${DOMAIN_NAME}-mirror1"

echo 'Mirrors permissions updated.'
