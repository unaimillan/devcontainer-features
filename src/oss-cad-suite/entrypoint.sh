#!/bin/sh
# Runs on every container start as the container user (normally root).
# Some Docker setups (e.g. the containerd image store) create the named volume
# root-owned instead of copying the image's mountpoint mode, so open it up for
# the remote user here. ensure.sh falls back to sudo if this could not run.
VOLUME_DIR=/opt/oss-cad-suite
if [ "$(id -u)" = 0 ] && [ "$(stat -c %a "$VOLUME_DIR" 2>/dev/null)" != 1777 ]; then
    chmod 1777 "$VOLUME_DIR" 2>/dev/null || true
fi
exec "$@"
