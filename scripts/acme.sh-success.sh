#!/bin/sh

set -e

# shellcheck disable=SC2154
rm -rf "/acme.sh/${DOMAIN_NAME}-mirror1"
cp -rp "/acme.sh/${DOMAIN_NAME}/" "/acme.sh/${DOMAIN_NAME}-mirror1"
echo 'Mirrors are done.'

chmod 777 -R "/acme.sh/${DOMAIN_NAME}-mirror1"

echo 'Mirrors permissions updated.'
