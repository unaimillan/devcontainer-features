#!/bin/sh
# Runs on every container start as the container user (normally root).
# Some Docker setups (e.g. the containerd image store) create the named volume
# root-owned instead of copying the image's mountpoint, so hand it to the
# remote user here. Top level only: existing data keeps its owners.
# ensure.sh falls back to sudo if this could not run.
SHARE_DIR=/usr/local/share/hermes-agent
if [ "$(id -u)" = 0 ] && [ -r "$SHARE_DIR/user" ]; then
    user="$(cat "$SHARE_DIR/user")"
    home="$(. "$SHARE_DIR/env" && echo "$HERMES_HOME")"
    if [ -d "$home" ] && [ "$(stat -c %U "$home")" != "$user" ]; then
        chown "$user:$(id -gn "$user")" "$home" 2>/dev/null || true
    fi
fi
exec "$@"
