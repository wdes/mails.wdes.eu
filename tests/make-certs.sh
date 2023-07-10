#!/bin/sh

set -eux

ME=$(realpath $(dirname $0))

cd $ME

printf 'Running in: %s\n' "$ME"

SSL_PATH="$ME/data/acme.sh/mail.williamdes.eu.org"
CA_PATH="$SSL_PATH/ca"
KEYCERT_PATH="$SSL_PATH/mail.williamdes.eu.org"

# bake the keys
if [ ! -f $CA_PATH.key ]; then
    openssl genrsa -out $CA_PATH.key 4096
fi

if [ ! -f $KEYCERT_PATH.key ]; then
    openssl genrsa -out $KEYCERT_PATH.key 4096
fi

# bake the CA
openssl req -x509 -config $SSL_PATH/openssl.cnf -new -nodes -key $CA_PATH.key -sha256 -days 15 -out $CA_PATH.cer

# bake the CSR
#openssl req -new -config $SSL_PATH/openssl.cnf -key $KEYCERT_PATH.key -out $KEYCERT_PATH.csr

# bake the cert
openssl x509 -req -in $KEYCERT_PATH.csr -CA $CA_PATH.cer -CAkey $CA_PATH.key \
    -CAcreateserial -out $KEYCERT_PATH.cer -days 7 -sha256 -extfile $KEYCERT_PATH.csr.conf

cat $KEYCERT_PATH.cer > $SSL_PATH/fullchain.cer
cat $CA_PATH.cer >> $SSL_PATH/fullchain.cer
