#!/bin/sh

set -e

rm -rf /acme.sh/${DOMAIN_NAME}-mirror1
cp -rp /acme.sh/${DOMAIN_NAME}/ /acme.sh/${DOMAIN_NAME}-mirror1
rm -rf /acme.sh/${DOMAIN_NAME}-mirror2
cp -rp /acme.sh/${DOMAIN_NAME}/ /acme.sh/${DOMAIN_NAME}-mirror2
rm -rf /acme.sh/${DOMAIN_NAME}-mirror3
cp -rp /acme.sh/${DOMAIN_NAME}/ /acme.sh/${DOMAIN_NAME}-mirror3

echo 'Mirrors are done.'

chmod 777 -R /acme.sh/${DOMAIN_NAME}-mirror1
chmod 777 -R /acme.sh/${DOMAIN_NAME}-mirror2
chmod 777 -R /acme.sh/${DOMAIN_NAME}-mirror3

echo 'Mirrors permissions updated.'
