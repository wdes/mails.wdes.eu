#!/bin/sh
LDAPTLS_REQCERT=never ldapwhoami -ZZ -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin


LDAPTLS_REQCERT=never ldapsearch -LLL -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin "(cn=*)" -b "dc=mail,dc=williamdes,dc=eu,dc=org"
