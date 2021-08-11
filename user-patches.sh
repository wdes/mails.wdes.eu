#!/bin/sh

set -eu

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

echo 'Add spam check config'

cat <<EOF > /etc/amavis/conf.d/50-user
use strict;

#
# Place your configuration directives here.  They will override those in
# earlier files.
#
# See /usr/share/doc/amavisd-new/ for documentation and examples of
# the directives you can use in this file
#

@local_domains_acl = ( "." );

@spam_scanners = ( ['SpamAssassin', 'Amavis::SpamControl::SpamAssassin'] );

# @bypass_virus_checks_maps = (1);
# @bypass_spam_checks_maps = (1);

\$sa_tag_level_deflt = -9999; # always add spam info headers

\$enable_dkim_verification = 1; # Check DKIM

\$virus_admin = "${VIRUS_ADMIN_EMAIL}";

\$X_HEADER_LINE = "${VIRUS_X_HEADER_LINE}";

#------------ Do not modify anything below this line -------------
1;  # ensure a defined return
EOF

echo 'Tweak spamassassin'

# Remove the possible line
sed -i '/^add_header all Report _REPORT_$/d' /etc/spamassassin/local.cf
# Add it back
printf '\nadd_header all Report _REPORT_\n' >> /etc/spamassassin/local.cf

echo 'Lint spamassassin'
spamassassin --lint

echo 'Run spamassassin'
service spamassassin start
sa-update -v

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
		user = dovecot
        group = dovecot
		mode = 0666
	}
}
service aggregator {
	fifo_listener replication-notify-fifo {
		user = dovecot
        group = dovecot
        mode = 0666
	}
	unix_listener replication-notify {
		user = dovecot
        group = dovecot
        mode = 0666
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

if [ -d /var/run/dovecot ]; then
    echo 'Changing owner of /var/run/dovecot'
    chown dovecot:postfix /var/run/dovecot
fi

if [ -f /var/run/dovecot/replication-notify-fifo ]; then
    echo 'Changing permissions of replication-notify-fifo'
    chown dovecot:postfix /var/run/dovecot/replication-notify-fifo
    chmod 0660 /var/run/dovecot/replication-notify-fifo
fi

echo ">>>>>>>>>>>>>>>>>>>>>>>Finished applying patches<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
