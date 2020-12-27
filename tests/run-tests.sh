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


LDAPTLS_REQCERT=never ldapsearch -LLL -Z -h localhost -D "cn=John Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org" -w 'JohnPassWord!645987zefdm' "*" -b "dc=mail,dc=williamdes,dc=eu,dc=org"


LDAPTLS_REQCERT=never ldapsearch -Z -h localhost -D "cn=John Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org" -w 'JohnPassWord!645987zefdm' "*" -b "cn=John Pondu,ou=people,dc=mail,dc=williamdes,dc=eu,dc=org"
