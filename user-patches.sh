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

# Check if configured
if [ "${FAIL2BAN_BLOCKLIST_DE_API_KEY:-}" != "" ]; then
    sed -i '/^apikey =/d' /etc/fail2ban/action.d/blocklist_de.conf
    printf '\napikey = %s\n' "${FAIL2BAN_BLOCKLIST_DE_API_KEY}" >> /etc/fail2ban/action.d/blocklist_de.conf
else
    sed -i '/^apikey =/d' /etc/fail2ban/action.d/blocklist_de.conf
fi

# Check if configured
if [ "${FAIL2BAN_BLOCKLIST_DE_EMAIL:-}" != "" ]; then
    sed -i '/^email =/d' /etc/fail2ban/action.d/blocklist_de.conf
    printf '\nemail = %s\n' "${FAIL2BAN_BLOCKLIST_DE_EMAIL}" >> /etc/fail2ban/action.d/blocklist_de.conf
else
    sed -i '/^email =/d' /etc/fail2ban/action.d/blocklist_de.conf
fi

# Check if configured
if [ "${FAIL2BAN_IPTHREAT_API_KEY:-}" != "" ]; then
    sed -i '/^ipthreat_apikey =/d' /etc/fail2ban/action.d/ipthreat.conf
    printf '\nipthreat_apikey = %s\n' "${FAIL2BAN_IPTHREAT_API_KEY}" >> /etc/fail2ban/action.d/ipthreat.conf
else
    sed -i '/^ipthreat_apikey =/d' /etc/fail2ban/action.d/ipthreat.conf
fi

# Check if configured
if [ "${FAIL2BAN_IPTHREAT_SYSTEM_NAME:-}" != "" ]; then
    sed -i '/^ipthreat_system =/d' /etc/fail2ban/action.d/ipthreat.conf
    printf '\nipthreat_system = %s\n' "${FAIL2BAN_IPTHREAT_SYSTEM_NAME}" >> /etc/fail2ban/action.d/ipthreat.conf
else
    sed -i '/^ipthreat_system =/d' /etc/fail2ban/action.d/ipthreat.conf
fi

# Check if configured
if [ "${FAIL2BAN_ABUSEIPDB_API_KEY:-}" != "" ]; then
    sed -i '/^abuseipdb_apikey =/d' /etc/fail2ban/action.d/abuseipdb.conf
    printf '\nabuseipdb_apikey = %s\n' "${FAIL2BAN_ABUSEIPDB_API_KEY}" >> /etc/fail2ban/action.d/abuseipdb.conf
else
    sed -i '/^abuseipdb_apikey =/d' /etc/fail2ban/action.d/abuseipdb.conf
fi

# Check if configured
if [ "${FAIL2BAN_IGNORE_IPS:-}" != "" ]; then

# Source: https://github.com/docker-mailserver/docker-mailserver/blob/v12.1.0/target/fail2ban/jail.local
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

# Email settings

destemail = ${FAIL2BAN_DST_EMAIL}
sender = ${FAIL2BAN_SENDER_EMAIL}
sendername = ${FAIL2BAN_SENDER_NAME}
mta = sendmail

# Report block via blocklist.de fail2ban reporting service API
#
# See the IMPORTANT note in action.d/blocklist_de.conf for when to use this action.
# Specify expected parameters in file action.d/blocklist_de.local or if the interpolation
# "action_blocklist_de" used for the action, set value of "blocklist_de_apikey"
# in your "jail.local" globally (section [DEFAULT]) or per specific jail section (resp. in
# corresponding jail.d/my-jail.local file).
#
action_blocklist_de  = blocklist_de[email="%(sender)s", service="%(__name__)s", apikey="%(blocklist_de_apikey)s", agent="%(fail2ban_agent)s"]

# Report ban via abuseipdb.com.
#
# See action.d/abuseipdb.conf for usage example and details.
#
action_abuseipdb = abuseipdb

# Ban IP and report to AbuseIPDB for Brute-Forcing
action = %(action_)s
         %(action_abuseipdb)s[abuseipdb_category="18"]
         ipthreat[]

[dovecot]
enabled = true

[postfix]
enabled = true
# For a reference on why this mode was chose, see
# https://github.com/docker-mailserver/docker-mailserver/issues/3256#issuecomment-1511188760
mode = extra

[postfix-sasl]
enabled = true

# This jail is used for manual bans.
# To ban an IP address use: setup.sh fail2ban ban <IP>
[custom]
enabled = true
bantime = 180d
port = smtp,pop3,pop3s,imap,imaps,submission,submissions,sieve
EOF
fi

# Check if configured
if [ "${DOVECOT_REPLICATION_SERVER:-}" != "" ]; then

    echo 'Enabling replication'
    echo 'Hint: doveadm replicator status'
    echo "Hint: doveadm user '*'"
    echo 'Hint: doveadm replicator dsync-status'
    echo 'Hint: rspamc uptime'

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
