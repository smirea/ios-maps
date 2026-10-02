#!/bin/sh
set -eu
bridge_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
scripts_dir=${GOOGLE_MAPS_SCRIPTS_DIR:-"$HOME/code/scripts"}
exec bun --no-env-file --env-file "$scripts_dir/.env" --env-file "$scripts_dir/.env.local" "$bridge_dir/service.ts" --script "$scripts_dir/src/google-maps.ts" "$@"
