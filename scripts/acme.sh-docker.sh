#!/bin/sh

set -e
touch /tmp/system.lock

# https://hub.docker.com/r/neilpang/acme.sh/dockerfile
if [ ! -f /acme.sh/account.conf ]; then
    echo 'First startup'
    #acme.sh --register-account --server letsencrypt -m "${ACME_SH_EMAIL}"
    acme.sh --set-default-ca --server zerossl
    if [ ! -z "${ACME_SH_EMAIL}" ]; then
        acme.sh --register-account --server zerossl -m "${ACME_SH_EMAIL}"
    else
        # shellcheck disable=SC2154
        acme.sh --register-account --server zerossl --eab-kid "${ACME_SH_EAB_KID}" --eab-hmac-key "${ACME_SH_EAB_HMAC}"
    fi
fi

# shellcheck disable=SC2154
if [ ! -f "/acme.sh/${DOMAIN_NAME}_ecc/fullchain.cer" ]; then
    echo 'Asking for certificates'

    CLI_DOMAIN_NAMES=""
    # shellcheck disable=SC2154
    for domain in ${DOMAIN_NAMES}; do
        # shellcheck disable=SC2089
        CLI_DOMAIN_NAMES="${CLI_DOMAIN_NAMES} -d ${domain} --challenge-alias no --dns ${DNS_API}"
    done

    # shellcheck disable=SC2086,SC2154,SC2090
    acme.sh --server zerossl \
        ${ACME_COMMAND_ARGUMENTS} \
        --reloadcmd "sh /scripts/acme.sh-success.sh" \
        --issue \
        ${CLI_DOMAIN_NAMES} \
        ${ACME_ISSUE_ARGUMENTS}

fi

echo 'Listing certs'
acme.sh --list

rm /tmp/system.lock

# Make the container keep running
# /entry.sh daemon
# New method
crond -n -s -m off
