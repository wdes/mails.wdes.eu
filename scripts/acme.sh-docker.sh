#!/bin/sh

set -e
touch /tmp/system.lock

# https://hub.docker.com/r/neilpang/acme.sh/dockerfile
if [ ! -f /acme.sh/account.conf ]; then
    echo 'First startup'
    acme.sh --register-account
    acme.sh --update-account --accountemail ${ACME_SH_EMAIL}
    echo 'Asking for certificates'
    acme.sh --issue ${ACME_COMMAND_ARGUMENTS} \
        -d "${DOMAIN_NAME}" -d "*.${DOMAIN_NAME}" \
        --dns dns_cf --reloadcmd "sh /scripts/acme.sh-success.sh"

fi

echo 'Listing certs'
acme.sh --list

rm /tmp/system.lock

# Make the container keep running
/entry.sh daemon
