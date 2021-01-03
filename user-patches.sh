#!/bin/bash
##
# This user script will be executed between configuration and starting daemons
# To enable it you must save it in your config directory as "user-patches.sh"
##
echo ">>>>>>>>>>>>>>>>>>>>>>>Applying patches<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

# https://github.com/dovecot/core/blob/941668f5a0ca1733ceceae438092398bc08a7810/doc/example-config/dovecot-ldap.conf.ext#L47

printf '\ntls_ca_cert_file = %s\ntls_cert_file = %s\ntls_key_file = %s\ntls_require_cert = %s\n' \
    "${DOVECOT_TLS_CACERT_FILE}" \
    "${DOVECOT_TLS_CERT_FILE}" \
    "${DOVECOT_TLS_KEY_FILE}" \
    "${DOVECOT_TLS_VERIFY_CLIENT}" >> /etc/dovecot/dovecot-ldap.conf.ext

# shellcheck disable=SC2016
sed -i 's|mydestination = $myhostname, |mydestination = |' /etc/postfix/main.cf

# shellcheck disable=SC2016
sed -i 's|smtpd_sasl_local_domain = $mydomain||' /etc/postfix/main.cf

printf '\nvirtual_alias_domains = %s\n' "${POSTFIX_VIRTUAL_ALIAS_DOMAINS}" >> /etc/postfix/main.cf

echo ">>>>>>>>>>>>>>>>>>>>>>>Finished applying patches<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
