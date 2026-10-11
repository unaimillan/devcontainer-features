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
    exec 9>"$VOLUME_DIR/.lock"
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
