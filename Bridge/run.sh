#!/bin/sh
set -eu
bridge_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
scripts_dir=${GOOGLE_MAPS_SCRIPTS_DIR:-"$HOME/code/scripts"}
bun_bin=$(command -v bun || printf '%s' "$HOME/.bun/bin/bun")
if [ ! -x "$bun_bin" ]; then
    echo 'Install Bun or add it to PATH to run the search bridge.' >&2
    exit 1
fi
exec "$bun_bin" --no-env-file --env-file "$scripts_dir/.env" --env-file "$scripts_dir/.env.local" "$bridge_dir/service.ts" --script "$scripts_dir/src/google-maps.ts" "$@"
