#!/bin/sh
set -eu
bridge_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$bridge_dir/../.." && pwd)
scripts_dir=${GOOGLE_MAPS_SCRIPTS_DIR:-"$HOME/code/scripts"}
bun_bin=$(command -v bun || printf '%s' "$HOME/.bun/bin/bun")
if [ ! -x "$bun_bin" ]; then
    echo 'Install Bun or add it to PATH to run the search bridge.' >&2
    exit 1
fi
if [ -f "$scripts_dir/.env" ] && [ -f "$scripts_dir/.env.local" ]; then
    export MAPS_SERVER_ENV_LOADED=1
    exec "$bun_bin" --no-env-file --env-file "$scripts_dir/.env" --env-file "$scripts_dir/.env.local" "$repo_dir/server/index.ts" "$@"
fi
if [ -f "$scripts_dir/.env" ]; then
    export MAPS_SERVER_ENV_LOADED=1
    exec "$bun_bin" --no-env-file --env-file "$scripts_dir/.env" "$repo_dir/server/index.ts" "$@"
fi
if [ -f "$scripts_dir/.env.local" ]; then
    export MAPS_SERVER_ENV_LOADED=1
    exec "$bun_bin" --no-env-file --env-file "$scripts_dir/.env.local" "$repo_dir/server/index.ts" "$@"
fi
exec "$bun_bin" --no-env-file "$repo_dir/server/index.ts" "$@"
