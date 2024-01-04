#!/bin/sh

set -eux

ME=$(realpath $(dirname $0))

cd $ME

printf 'Running in: %s\n' "$ME"

DOMAIN="emails.mail-server.intranet"
SSL_PATH="$ME/data/acme.sh/${DOMAIN}_ecc"
CA_PATH="$SSL_PATH/ca"
KEYCERT_PATH="$SSL_PATH/${DOMAIN}"

# bake the keys
if [ ! -f $CA_PATH.key ]; then
    openssl ecparam -out $CA_PATH.key -name prime256v1 -genkey
fi

if [ ! -f $KEYCERT_PATH.key ]; then
    openssl ecparam -out $KEYCERT_PATH.key -name prime256v1 -genkey
fi

# bake the CA
openssl req -x509 -config $SSL_PATH/openssl.cnf -new -nodes -key $CA_PATH.key -sha384 -days 15 -out $CA_PATH.cer

# bake the CSR
if [ ! -f $KEYCERT_PATH.csr ]; then
    openssl req -new -config $KEYCERT_PATH.csr.conf -key $KEYCERT_PATH.key -out $KEYCERT_PATH.csr
fi

# bake the cert
openssl x509 -req -extensions ext_cert -extfile $KEYCERT_PATH.csr.conf -in $KEYCERT_PATH.csr -CA $CA_PATH.cer -CAkey $CA_PATH.key \
    -CAcreateserial -out $KEYCERT_PATH.cer -days 7 -sha384

openssl req -in $KEYCERT_PATH.csr -noout -text
openssl x509 -in $KEYCERT_PATH.cer -noout -text

cat $KEYCERT_PATH.cer > $SSL_PATH/fullchain.cer
cat $CA_PATH.cer >> $SSL_PATH/fullchain.cer
