#!/bin/sh

set -eu

ROOT_DIR="$(dirname $0)"

cd "${ROOT_DIR}/../../"

printf 'Running in: %s\n' ${PWD}

./dockerl ps

echo 'Get the container Id'
CONTAINER_ID="$(NO_VERBOSE=1 ./dockerl ps -q openldap)"

echo 'Checking LDAP access'
docker exec -i ${CONTAINER_ID} ldapwhoami -ZZ -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin
echo 'Seeding org'
docker exec -i ${CONTAINER_ID} ldapadd -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin < ${ROOT_DIR}/org.ldiff
echo 'Seeding email 1'
docker exec -i ${CONTAINER_ID} ldapadd -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin < ${ROOT_DIR}/email1.ldiff
echo 'Seeding email 2'
docker exec -i ${CONTAINER_ID} ldapadd -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin < ${ROOT_DIR}/email2.ldiff
echo 'Print results'
docker exec -i ${CONTAINER_ID} ldapsearch -LLL -Z -h localhost -D "cn=admin,dc=mail,dc=williamdes,dc=eu,dc=org" -w PasswordLdapAdmin "*" -b "dc=mail,dc=williamdes,dc=eu,dc=org"
