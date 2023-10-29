#!/usr/bin/env sh
# shellcheck shell=dash

set -eu

exec /usr/local/bin/stalwart-install --docker --component "$STALWART_COMPONENT" --path /opt/stalwart-mail "$@"
