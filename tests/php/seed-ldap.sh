#!/bin/sh

set -e

cd $(dirname $0)/../

CONTAINER_NAME=ldap.mail.williamdes.eu.org
docker exec -i ${CONTAINER_NAME} ldapwhoami -ZZ -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin

docker exec -i ${CONTAINER_NAME} ldapadd -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin < org.ldiff

docker exec -i ${CONTAINER_NAME} ldapadd -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin < email1.ldiff

docker exec -i ${CONTAINER_NAME} ldapadd -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin < email2.ldiff

docker exec -i ${CONTAINER_NAME} ldapsearch -LLL -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin "*" -b "dc=mail,dc=williamdes,dc=eu,dc=org"
