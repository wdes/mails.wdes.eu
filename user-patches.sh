#!/bin/sh

set -eu

##
# This user script will be executed between configuration and starting daemons
# To enable it you must save it in your config directory as "user-patches.sh"
##
echo ">>>>>>>>>>>>>>>>>>>>>>>Applying patches<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

cat >/etc/postfix/sasl/smtpd.conf << EOF
pwcheck_method: saslauthd
saslauthd_path: /var/run/saslauthd/mux
mech_list: PLAIN SRP
EOF

# Delete before set to localhost
sed -i '/^mydomain =/d' /etc/postfix/main.cf
sed -i '/^mydestination =/d' /etc/postfix/main.cf

# Delete this value to default as empty default
sed -i '/^smtpd_sasl_local_domain =/d' /etc/postfix/main.cf

printf '\nmydomain = %s\n' "localhost" >> /etc/postfix/main.cf
printf '\nmydestination = %s\n' "localhost" >> /etc/postfix/main.cf
# For: https://github.com/GermanCoding/Roundcube_TLS_Icon
printf '\nsmtpd_tls_received_header = yes\n' "localhost" >> /etc/postfix/main.cf

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

@local_domains_acl = ( ["."] );
@local_domains_maps = ( ["."] );

# add spam info headers if at, or above that level
\$sa_tag_level_deflt = -9999; # always add spam info headers

\$enable_dkim_verification = 1; # Check DKIM

\$virus_admin = "${VIRUS_ADMIN_EMAIL}";

\$X_HEADER_LINE = "${VIRUS_X_HEADER_LINE}";

#------------ Do not modify anything below this line -------------
1;  # ensure a defined return
EOF

if [ -f /etc/amavis/conf.d/60-dms_default_config ]; then
    echo 'Removed to fix (https://github.com/docker-mailserver/docker-mailserver/issues/2123)'
    rm /etc/amavis/conf.d/60-dms_default_config
fi

echo 'Tweak fail2ban config'

# Source: https://github.com/docker-mailserver/docker-mailserver/blob/v11.2.0/target/fail2ban/jail.local
cat <<EOF > /etc/fail2ban/jail.d/user-jail.local
[DEFAULT]

# "bantime" is the number of seconds that a host is banned.
# 86400s = 1 day
bantime  = 86400s
port = smtp,pop3,pop3s,imap,imaps,submission,submissions,sieve

# A host is banned if it has generated "maxretry" during the last "findtime"
# seconds.
findtime = 10m

# "maxretry" is the number of failures before a host get banned.
maxretry = 3

# "ignoreip" can be a list of IP addresses, CIDR masks or DNS hosts. Fail2ban
# will not ban a host which matches an address in this list. Several addresses
# can be defined using space (and/or comma) separator.
ignoreip = ${FAIL2BAN_IGNORE_IPS}

# default ban action
# nftables-multiport: block IP only on affected port
# nftables-allports:  block IP on all ports
banaction = nftables-allports

[dovecot]
enabled = true

[postfix]
enabled = true

[postfix-sasl]
enabled = true

# Email settings

destemail = ${FAIL2BAN_DST_EMAIL}
sender = ${FAIL2BAN_SENDER_EMAIL}
sendername = ${FAIL2BAN_SENDER_NAME}
mta = sendmail

# This jail is used for manual bans.
# To ban an IP address use: setup.sh fail2ban ban <IP>
[custom]
enabled = true
bantime = 180d
port = smtp,pop3,pop3s,imap,imaps,submission,submissions,sieve
EOF

echo 'Adjusting LDAP for replication'

sed -i '/^iterate_filter =/d' /etc/dovecot/dovecot-ldap.conf.ext
sed -i '/^iterate_attrs =/d' /etc/dovecot/dovecot-ldap.conf.ext

printf '\niterate_filter = (objectClass=PostfixBookMailAccount)\n' >> /etc/dovecot/dovecot-ldap.conf.ext
printf '\niterate_attrs = mail=user\n' >> /etc/dovecot/dovecot-ldap.conf.ext

# Check if configured
if [ "${DOVECOT_REPLICATION_SERVER:-}" != "" ]; then

    echo 'Enabling replication'
    echo 'Hint: doveadm replicator status'

    sed -i 's/^mail_plugins =.*/mail_plugins = \$mail_plugins quota notify replication/' /etc/dovecot/conf.d/10-mail.conf

    cat <<EOF > /etc/dovecot/conf.d/10-replication.conf
service doveadm {
	inet_listener {
		port = 4177
		ssl = yes
	}
}
protocol doveadm {
    ssl_cert = <${DOVECOT_REPLICATION_SSL_CERT_FILE}
    ssl_key = <${DOVECOT_REPLICATION_SSL_KEY_FILE}
    ssl_client_ca_file = ${DOVECOT_REPLICATION_SSL_CA_FILE}
    ssl_client_ca_dir = ${DOVECOT_REPLICATION_SSL_CA_DIR}
}
instance_name = ${OVERRIDE_HOSTNAME}
doveadm_ssl = ssl
doveadm_port = 4177
doveadm_password = ${DOVECOT_REPLICATION_ADM_PASS}
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

    # Open the config
    sed -i '/^}/d' /etc/dovecot/conf.d/90-plugin.conf
    # Remove a possible old value of mail_replica
    sed -i '/^mail_replica/d' /etc/dovecot/conf.d/90-plugin.conf
    # Insert the config and close it back
    printf '\nmail_replica = tcps:%s\n}\n' "${DOVECOT_REPLICATION_SERVER}" >> /etc/dovecot/conf.d/90-plugin.conf
else

    echo 'Disabling replication'

    # Remove a possible old value of mail_replica
    sed -i '/^mail_replica/d' /etc/dovecot/conf.d/90-plugin.conf
    rm -fv /etc/dovecot/conf.d/10-replication.conf
    sed -i 's/^mail_plugins =.*/mail_plugins = \$mail_plugins quota notify/' /etc/dovecot/conf.d/10-mail.conf
fi

echo ">>>>>>>>>>>>>>>>>>>>>>>Finished applying patches<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo ">>>>>>>>>>>>>>>>>>>>>>>Finished starting services<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
