#!/usr/bin/env bash
# Create-time part of the feature: make sure the pinned release exists in the
# shared volume. Instant when another container already downloaded it.
set -euo pipefail

SHARE_DIR=/usr/local/share/oss-cad-suite
VERSION="$(cat "$SHARE_DIR/version")"
ARCH="$(cat "$SHARE_DIR/arch")"
VOLUME_DIR=/opt/oss-cad-suite
DEST="$VOLUME_DIR/$VERSION"

if [ ! -f "$DEST/.complete" ]; then
    if [ ! -w "$VOLUME_DIR" ] && ! sudo -n chmod 1777 "$VOLUME_DIR" 2>/dev/null; then
        echo "oss-cad-suite: $VOLUME_DIR is not writable by $(id -un) and passwordless sudo is unavailable." >&2
        echo "oss-cad-suite: fix once with: docker run --rm -v oss-cad-suite:/v alpine chmod 1777 /v" >&2
        exit 1
    fi
    # Lock the volume directory itself: no lock file whose owner could block
    # containers running as a different user.
    exec 9<"$VOLUME_DIR"
    flock 9
    # Re-check: a concurrent container may have finished while we waited.
    if [ ! -f "$DEST/.complete" ]; then
        URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${VERSION}/oss-cad-suite-linux-${ARCH}-${VERSION//-/}.tgz"
        TMP="$VOLUME_DIR/.tmp-$VERSION"
        trap 'rm -rf "$TMP"' EXIT
        rm -rf "$TMP" "$DEST"
        mkdir -p "$TMP"
        echo "oss-cad-suite: downloading $VERSION ($ARCH) into shared volume (one-time per Docker host)..."
        curl -fL --retry 3 "$URL" | tar -xz -C "$TMP"
        mv "$TMP/oss-cad-suite" "$DEST"
        touch "$DEST/.complete"
    fi
fi

echo "oss-cad-suite $VERSION ready at $DEST"
"$DEST/bin/verilator" --version
"$DEST/bin/yosys" -V
