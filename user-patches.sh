#!/bin/bash

set -e

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

# Delete before set to localhost
sed -i '/^mydomain =/d' /etc/postfix/main.cf
sed -i '/^mydestination =/d' /etc/postfix/main.cf

# Delete this value to default as empty default
sed -i '/^smtpd_sasl_local_domain =/d' /etc/postfix/main.cf

printf '\nmydomain = %s\n' "localhost" >> /etc/postfix/main.cf
printf '\nmydestination = %s\n' "localhost" >> /etc/postfix/main.cf

sed -i '/^smtp_helo_name =/d' /etc/postfix/main.cf
printf '\nsmtp_helo_name = %s\n' "${OVERRIDE_HOSTNAME}" >> /etc/postfix/main.cf

echo 'Enabling replication'

sed -i '/^iterate_filter =/d' /etc/dovecot/dovecot-ldap.conf.ext
sed -i '/^iterate_attrs =/d' /etc/dovecot/dovecot-ldap.conf.ext

printf '\niterate_filter = (objectClass=PostfixBookMailAccount)\n' >> /etc/dovecot/dovecot-ldap.conf.ext
printf '\niterate_attrs = mail=user\n' >> /etc/dovecot/dovecot-ldap.conf.ext

sed -i 's/^mail_plugins =.*/mail_plugins = \$mail_plugins notify replication/' /etc/dovecot/conf.d/10-mail.conf

cat <<EOF > /etc/dovecot/conf.d/10-replication.conf
service doveadm {
	inet_listener {
		port = 4177
		ssl = yes
	}
}
ssl = required
ssl_verify_client_cert = no
auth_ssl_require_client_cert = no
ssl_cert = <${SSL_CERT_PATH}
ssl_key = <${SSL_KEY_PATH}
ssl_client_ca_file = ${DOVECOT_TLS_CACERT_FILE}
ssl_client_ca_dir = /etc/ssl/certs/
doveadm_port = 4177
doveadm_password = ${DOVECOT_ADM_PASS}
service replicator {
	process_min_avail = 1
	unix_listener replicator-doveadm {
		mode = 0600
	}
}
service aggregator {
	fifo_listener replication-notify-fifo {
		user = dovecot
	}
	unix_listener replication-notify {
		user = dovecot
	}
}
EOF

# Check if configured
if [ -n "${DOVECOT_REPLICA_SERVER}" ]; then
    # Open the config
    sed -i '/^}/d' /etc/dovecot/conf.d/90-plugin.conf
    # Remove a possible old value of mail_replica
    sed -i '/^mail_replica/d' /etc/dovecot/conf.d/90-plugin.conf
    # Insert the config and close it back
    printf '\nmail_replica = tcps:%s\n}\n' "${DOVECOT_REPLICA_SERVER}" >> /etc/dovecot/conf.d/90-plugin.conf
fi

echo ">>>>>>>>>>>>>>>>>>>>>>>Finished applying patches<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
