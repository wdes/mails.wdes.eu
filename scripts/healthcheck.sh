#!/bin/sh

set -e

if [ -f /tmp/system.lock ]; then
    echo 'System in lock state';
    exit 1;
fi

# shellcheck disable=SC2154
if [ ! -f "/acme.sh/${DOMAIN_NAME}-mirror1/fullchain.cer" ]; then
    echo 'Not ready';
    exit 1;
fi

echo 'Ready';
exit 0;
