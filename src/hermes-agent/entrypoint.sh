#!/bin/sh
# Runs on every container start as the container user (normally root).
# Hands HERMES_HOME to the remote user when its owner uid differs:
# - some Docker setups (e.g. the containerd image store) create the named
#   volume root-owned instead of copying the image's mountpoint;
# - the dev container CLI may change the remote user's uid to match the host
#   (updateRemoteUserUID) after the image was built, leaving the seeded data
#   owned by the old uid. Code and tool store are covered by the hermes group.
# Recursive, but only when the top-level owner is wrong, so later starts are
# a no-op. ensure.sh falls back to sudo if this could not run.
SHARE_DIR=/usr/local/share/hermes-agent
if [ "$(id -u)" = 0 ] && [ -r "$SHARE_DIR/user" ]; then
    user="$(cat "$SHARE_DIR/user")"
    uid="$(id -u "$user")" gid="$(id -g "$user")"
    home="$(. "$SHARE_DIR/env" && echo "$HERMES_HOME")"
    if [ -d "$home" ] && [ "$(stat -c %u "$home")" != "$uid" ]; then
        chown -R "$uid:$gid" "$home" 2>/dev/null || true
    fi
fi
exec "$@"
