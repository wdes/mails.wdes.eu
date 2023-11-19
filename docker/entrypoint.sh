#!/usr/bin/env sh
# shellcheck shell=dash

set -eu

CONFIG="$1"
shift

# If the configuration file does not exist wait until it does.
while [ ! -f "${CONFIG}" ]; do
    sleep 1
done

# If the configuration file exists, start the server.
exec "$@" --config "${CONFIG}"
