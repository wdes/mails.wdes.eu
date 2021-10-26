#!/bin/sh

set -e
touch /tmp/system.lock

# https://hub.docker.com/r/neilpang/acme.sh/dockerfile
if [ ! -f /acme.sh/account.conf ]; then
    echo 'First startup'
    acme.sh --register-account -m "${ACME_SH_EMAIL}" --server zerossl
    # shellcheck disable=SC2154
    acme.sh  --server zerossl --update-account --accountemail "${ACME_SH_EMAIL}"
fi

# shellcheck disable=SC2154
if [ ! -f "/acme.sh/${DOMAIN_NAME}/fullchain.cer" ]; then
    echo 'Asking for certificates'

    CLI_DOMAIN_NAMES=""
    # shellcheck disable=SC2154
    for domain in ${DOMAIN_NAMES}; do
        # shellcheck disable=SC2089
        CLI_DOMAIN_NAMES="${CLI_DOMAIN_NAMES} -d ${domain}"
    done

    # shellcheck disable=SC2086,SC2154,SC2090
    acme.sh --server zerossl --issue ${ACME_COMMAND_ARGUMENTS} \
        ${CLI_DOMAIN_NAMES} \
        --reloadcmd "sh /scripts/acme.sh-success.sh"

fi

echo 'Listing certs'
acme.sh --list

rm /tmp/system.lock

# Make the container keep running
/entry.sh daemon
