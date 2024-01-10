#!/bin/sh

set -eu

ME=$(realpath $(dirname $0))

if [ ! -f $ME/.env ]; then
    echo "Missing env: $ME/.env"
    exit 1
fi

# Load up .env
set -o allexport
# Source the file
. $ME/.env
set +o allexport

CONTAINER_NAME="${DOCKER_PROJECT_NAME}-mailserver-1"

# See: https://serverfault.com/a/577766/336084
for q in active  bounce  corrupt  defer  deferred  flush  hold  incoming  maildrop; do
    zabbix_sender -z $ZABBIX_HOST -s $ZABBIX_HOST_NAME -k "email-monitoring.servers.mx" -o "$(printf '{"data":[{"{#MX_HOST}":"%s", "{#QUEUE_NAME}":"%s"}]}' ${OVERRIDE_HOSTNAME} ${q})" 1>/dev/null
done

# See: https://serverfault.com/a/577766/336084
for q in active  bounce  corrupt  defer  deferred  flush  hold  incoming  maildrop; do
    count=$(docker exec $CONTAINER_NAME find /var/spool/postfix/$q ! -type d -print | wc -l)

    if [ ! -z "${1:-}" ]; then
        echo $q $count
    fi
    zabbix_sender -z $ZABBIX_HOST -s $ZABBIX_HOST_NAME -k "email-monitoring.servers.mx.queue[${OVERRIDE_HOSTNAME},$q]" -o "$count" 1>/dev/null
done
