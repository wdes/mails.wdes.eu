#!/bin/sh

set -e

if [ -f /tmp/system.lock ]; then
    echo 'System in lock state';
    exit 1;
fi

if [ ! -f /acme.sh/${DOMAIN_NAME}-mirror3/dhparam.pem ]; then
    echo 'Not ready';
    exit 1;
fi

echo 'Ready';
exit 0;
