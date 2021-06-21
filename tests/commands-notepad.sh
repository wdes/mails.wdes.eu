#!/bin/sh
LDAPTLS_REQCERT=never ldapwhoami -ZZ -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin


LDAPTLS_REQCERT=never ldapsearch -LLL -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin "(cn=*)" -b "dc=mail,dc=williamdes,dc=eu,dc=org"

LDAPTLS_REQCERT=never ldapsearch -LLL -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin "*" -b "dc=mail,dc=williamdes,dc=eu,dc=org"

LDAPTLS_REQCERT=never ldapadd -LLL -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin -f newgroups.ldif


LDAPTLS_REQCERT=never ldapadd -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin -f tests/org.ldiff


LDAPTLS_REQCERT=never ldapadd -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin -f tests/email1.ldiff

mkpasswd -m sha512crypt 'JohnPassWord!645987zefdm'


mkpasswd -m sha512crypt 'PassCyrielle!ILoveDogs'


LDAPTLS_REQCERT=never ldapadd -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin -f tests/email2.ldiff


swaks --to cyrielle@mail.williamdes.eu.org -server localhost --from john@mail.williamdes.eu.org --protocol SMTPS --auth PLAIN --auth-user john@mail.williamdes.eu.org --auth-password 'JohnPassWord!645987zefdm' --header-X-Test "test email"


swaks --to cyrielle@mail.williamdes.eu.org --server localhost --from john@mail.williamdes.eu.org --protocol SSMTP --auth PLAIN --auth-user john@mail.williamdes.eu.org --auth-password 'JohnPassWord!645987zefdm' --attach-type text/plain --attach-body @LICENSE


swaks --port 587 --tls --auth PLAIN --server localhost --to cyrielle@mail.williamdes.eu.org --auth-user john@mail.williamdes.eu.org --auth-password 'JohnPassWord!645987zefdm' --header "Subject: A test email" --body "Hi\n:)\nBye" --from "John <john@mail.williamdes.eu.org>"

swaks --port 587 --tls --auth PLAIN --server localhost --to cyrielle@mail.williamdes.eu.org --auth-user cyrielle@mail.williamdes.eu.org --auth-password 'PassCyrielle!ILoveDogs' --header "Subject: A test email" --body "Hi\n:)\nBye" --from "John <john@mail.williamdes.eu.org>"

# No such object
LDAPTLS_REQCERT=never ldapsearch -LLL -Z -h localhost -D "cn=John Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org" -w 'JohnPassWord!645987zefdm' "*" -b "dc=mail,dc=williamdes,dc=eu,dc=org"

# Works
LDAPTLS_REQCERT=never ldapsearch -Z -h localhost -D "cn=John Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org" -w 'JohnPassWord!645987zefdm' "*" -b "cn=John Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org"


mutt -R -f 'imaps://cyrielle@mail.williamdes.eu.org:PassCyrielle!ILoveDogs@localhost:993/INBOX'


mutt -n -F .muttrc -R -f 'imaps://john@mail.williamdes.eu.org:JohnPassWord!645987zefdm@localhost:993/INBOX'



docker exec -i ldap.mail.williamdes.eu.org ldapmodify -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin <<EOF
dn: cn=John Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org
changetype: modify
replace: userPassword
userpassword: {SHA512-CRYPT}$6$cOMeAcso8M$leU6Peukc.poeeE.ld5Ks2Ey4VHuLSXjDJW3T41T3MxdKoyEVZq1MI1Q9hokcbtMjl6rFkNQjaIuoifwbMTRG/

EOF

# https://www.openldap.org/faq/data/cache/418.html
# slappasswd -h {SHA} -s secret
# Woking schemes: MD5, SMD5, SHA, SSHA, CRYPT

docker exec -i ldap.mail.williamdes.eu.org ldapmodify -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin <<EOF
dn: cn=Cyrielle Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org
changetype: modify
replace: sasluserpassword
sasluserpassword: {MD5}Xr4ilOzQ4PCOq3aQ0qbuaQ==

EOF

docker exec -i ldap.mail.williamdes.eu.org ldapmodify -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin <<EOF
dn: cn=Cyrielle Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org
changetype: modify
replace: sasluserpassword
sasluserpassword: {SMD5}mc0uWpXVVe5747A4pKhGJXNhbHQ=

EOF


docker exec -i ldap.mail.williamdes.eu.org ldapmodify -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin <<EOF
dn: cn=Cyrielle Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org
changetype: modify
replace: sasluserpassword
sasluserpassword: {SSHA}nly9LqB9vFSfpemuUCSFLnQZyZlzaD2v

EOF

docker exec -i ldap.mail.williamdes.eu.org ldapmodify -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin <<EOF
dn: cn=Cyrielle Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org
changetype: modify
replace: sasluserpassword
sasluserpassword: {CRYPT}HDWcdMgiW4DpE

EOF

testsaslauthd -u john@mail.williamdes.eu.org -p 'JohnPassWord!645987zefdm'


printf "{CRYPT}%s" "$(openssl passwd -2 -stdin <<< "secret")"


LDAP_BASE_DN="dc=mail,dc=williamdes,dc=eu,dc=org"

LDAPTLS_REQCERT=never ldapsearch -LLL -Z -h localhost -D "${LDAP_BIND_DN}" -w "${LDAP_BIND_PW}" "(mail=*)" -b "${LDAP_BASE_DN}" mail mailAlias | sed -n 's/^[ \t]*\(mail\|mailAlias\):[ \t]*.*@\(.*\)/\2/p'


# slappasswd -h {CRYPT} -s public
# slappasswd -h {SSHA} -s public

ldapmodify -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin <<EOF
dn: cn=John Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org
changetype: modify
replace: userPassword
userpassword: {CRYPT}lhmbbdbF0NefQ

EOF


# Saves as SSHA
ldappasswd -Z -h localhost -x -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin -S "cn=John Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org" -s public

