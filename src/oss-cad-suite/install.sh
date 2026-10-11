#!/usr/bin/env bash
# Build-time part of the feature. The shared volume is NOT mounted yet here;
# we only prepare the image so that ensure.sh can populate the volume on create.
set -euo pipefail

VERSION="${VERSION:-latest}"
REMOTE_USER="${_REMOTE_USER:-root}"
SHARE_DIR=/usr/local/share/oss-cad-suite
VOLUME_DIR=/opt/oss-cad-suite
REPO=YosysHQ/oss-cad-suite-build

case "$(uname -m)" in
    x86_64)  ARCH=x64 ;;
    aarch64) ARCH=arm64 ;;
    *) echo "oss-cad-suite: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac

if ! command -v apt-get >/dev/null; then
    echo "oss-cad-suite: only Debian/Ubuntu-based images (apt-get) are supported" >&2
    exit 1
fi

# Download tools, plus Verilator's host prerequisites: its bin/ wrapper is a
# Perl script (needs full perl, not perl-base), and models build with make/g++.
pkgs=()
command -v curl  >/dev/null || pkgs+=(curl)
[ -f /etc/ssl/certs/ca-certificates.crt ] || pkgs+=(ca-certificates)
command -v tar   >/dev/null || pkgs+=(tar)
command -v gzip  >/dev/null || pkgs+=(gzip)
command -v flock >/dev/null || pkgs+=(util-linux)
perl -MFindBin -e1 2>/dev/null || pkgs+=(perl)
command -v make  >/dev/null || pkgs+=(make)
command -v g++   >/dev/null || pkgs+=(g++)
if [ ${#pkgs[@]} -gt 0 ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends "${pkgs[@]}"
    rm -rf /var/lib/apt/lists/*
fi

# Resolve 'latest' now, so the image stays pinned to one concrete release.
if [ "$VERSION" = "latest" ]; then
    VERSION="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep -oP '"tag_name":\s*"\K[^"]+')"
    echo "oss-cad-suite: resolved 'latest' to $VERSION"
fi
if ! [[ "$VERSION" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "oss-cad-suite: invalid version '$VERSION' (expected YYYY-MM-DD or 'latest')" >&2
    exit 1
fi

mkdir -p "$SHARE_DIR"
echo "$VERSION" > "$SHARE_DIR/version"
echo "$ARCH" > "$SHARE_DIR/arch"
install -m 0755 "$(dirname "$0")/ensure.sh" "$SHARE_DIR/ensure.sh"

# Docker copies owner/mode of this dir into the empty named volume on first
# mount, so the remote user can populate it without sudo.
mkdir -p "$VOLUME_DIR"
chown "$REMOTE_USER:" "$VOLUME_DIR"

# Stable path for PATH; dangles until ensure.sh has populated the volume.
ln -sfn "$VOLUME_DIR/$VERSION" /usr/local/oss-cad-suite

echo "oss-cad-suite: pinned to $VERSION ($ARCH), populated into the shared volume on container create"
