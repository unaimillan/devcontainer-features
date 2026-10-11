#!/usr/bin/env bash
# Build-time part of the feature. Runs the upstream installer as the remote
# user, with code and tool store in the image and only data in HERMES_HOME,
# which the hermes-agent-config volume covers at runtime.
set -euo pipefail

VERSION="${VERSION:-latest}"
BROWSER="${BROWSER:-false}"
COMPUTER_USE="${COMPUTERUSE:-false}"
INSTALL_DIR="${INSTALLDIR:-/opt/hermes/agent}"
RUNTIME_DIR="${RUNTIMEDIR:-/opt/hermes/tools}"
HOME_DIR="${HOMEDIR:-/var/lib/hermes}"
LINK_USER_HOME="${LINKUSERHOME:-true}"

SHARE_DIR=/usr/local/share/hermes-agent
VOLUME_TARGET=/var/lib/hermes

for dir in "$INSTALL_DIR" "$RUNTIME_DIR" "$HOME_DIR"; do
    case "$dir" in
        /*) ;;
        *) echo "hermes-agent: '$dir' is not an absolute path" >&2; exit 1 ;;
    esac
done

if ! command -v apt-get >/dev/null; then
    echo "hermes-agent: only Debian/Ubuntu-based images (apt-get) are supported" >&2
    exit 1
fi

# The installer needs git and curl; the Node.js it fetches links libatomic.
pkgs=()
command -v curl >/dev/null || pkgs+=(curl)
[ -f /etc/ssl/certs/ca-certificates.crt ] || pkgs+=(ca-certificates)
command -v git  >/dev/null || pkgs+=(git)
command -v xz   >/dev/null || pkgs+=(xz-utils)
{ ldconfig -p 2>/dev/null || true; } | grep -q 'libatomic\.so\.1' || pkgs+=(libatomic1)
if [ ${#pkgs[@]} -gt 0 ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends "${pkgs[@]}"
    rm -rf /var/lib/apt/lists/*
fi

USERNAME="${_REMOTE_USER:-root}"
if ! id "$USERNAME" >/dev/null 2>&1; then
    echo "hermes-agent: remote user '$USERNAME' does not exist, installing for root"
    USERNAME=root
fi
USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
USER_GROUP="$(id -gn "$USERNAME")"

# A SHA is installed detached, so `hermes update` leaves it alone; 'latest'
# and branches stay on their branch, so `hermes update` can move them on.
# The commit actually installed is recorded below either way.
[ "$VERSION" = latest ] && VERSION=main
if [[ "$VERSION" =~ ^[0-9a-f]{7,40}$ ]]; then
    ref_args=(--commit "$VERSION")
elif [[ "$VERSION" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    ref_args=(--branch "$VERSION")
else
    echo "hermes-agent: invalid version '$VERSION' (expected 'latest', a commit SHA or a branch)" >&2
    exit 1
fi

install_args=(--non-interactive --dir "$INSTALL_DIR" "${ref_args[@]}")
[ "$BROWSER" = true ]      || install_args+=(--skip-browser)
[ "$COMPUTER_USE" = true ] || install_args+=(--skip-computer-use)

# The installer stages its clone next to INSTALL_DIR and moves it into place,
# so the user needs the parent directory. Hand it over only when we create it.
INSTALL_PARENT="$(dirname "$INSTALL_DIR")"
if [ ! -d "$INSTALL_PARENT" ]; then
    mkdir -p "$INSTALL_PARENT"
    chown "$USERNAME:$USER_GROUP" "$INSTALL_PARENT"
elif [ "$USERNAME" != root ] && ! su "$USERNAME" -s /bin/sh -c "test -w $(printf %q "$INSTALL_PARENT")"; then
    echo "hermes-agent: $INSTALL_PARENT is not writable by $USERNAME; pick an installDir whose parent does not exist yet" >&2
    exit 1
fi
mkdir -p "$SHARE_DIR" "$RUNTIME_DIR" "$HOME_DIR" "$VOLUME_TARGET"
chown "$USERNAME:$USER_GROUP" "$RUNTIME_DIR" "$HOME_DIR" "$VOLUME_TARGET"

# Take the installer from the same ref as the code it installs.
curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/$VERSION/scripts/install.sh" \
    -o "$SHARE_DIR/upstream-install.sh"
chmod 0755 "$SHARE_DIR/upstream-install.sh"

cmd="cd ~ && HERMES_HOME=$(printf %q "$HOME_DIR") HERMES_RUNTIME_DIR=$(printf %q "$RUNTIME_DIR")"
cmd+=" bash $SHARE_DIR/upstream-install.sh$(printf ' %q' "${install_args[@]}")"
if [ "$USERNAME" = root ]; then
    bash -c "$cmd"
else
    su "$USERNAME" -s /bin/bash -c "$cmd"
fi

# The dev container CLI may later change the user's uid to match the host
# (updateRemoteUserUID) and re-own only the home folder. Group access keeps
# code and tool store usable then (supplementary groups survive usermod -u);
# re-owning ~2 GB at start would copy it all into the container layer.
groupadd -f -r hermes  # system gid: never collides with a host gid the CLI remaps to
[ "$USERNAME" = root ] || usermod -aG hermes "$USERNAME"
chgrp -R hermes "$INSTALL_DIR" "$RUNTIME_DIR"
chmod -R g+rwX "$INSTALL_DIR" "$RUNTIME_DIR"
find "$INSTALL_DIR" "$RUNTIME_DIR" -type d -exec chmod g+s {} +
git config --system --add safe.directory "$INSTALL_DIR"

# Defaults for every caller; values already in the environment (e.g. a
# containerEnv in devcontainer.json) win. The agent dir is kept in a variable
# so the shim never names the checkout directly: Hermes's own launcher
# publishing (`hermes update`) would otherwise claim and overwrite it.
cat > "$SHARE_DIR/env" <<EOF
export HERMES_HOME="\${HERMES_HOME:-$HOME_DIR}"
export HERMES_RUNTIME_DIR="\${HERMES_RUNTIME_DIR:-$RUNTIME_DIR}"
HERMES_AGENT_DIR=$(printf %q "$INSTALL_DIR")
EOF
echo "$USERNAME" > "$SHARE_DIR/user"
COMMIT="$(git -c safe.directory="$INSTALL_DIR" -C "$INSTALL_DIR" rev-parse HEAD)"
echo "$COMMIT" > "$SHARE_DIR/version"
install -m 0755 "$(dirname "$0")/shim.sh" "$SHARE_DIR/shim"
install -m 0755 "$(dirname "$0")/ensure.sh" "$(dirname "$0")/entrypoint.sh" "$SHARE_DIR/"

for name in hermes hermes-acp hermes-agent; do
    ln -sfn "$SHARE_DIR/shim" "/usr/local/bin/$name"
    # Replace the upstream user-bin launchers (they carry no HERMES_* env) with
    # links to the shim; a foreign symlink is left alone by `hermes update`.
    if [ -e "$USER_HOME/.local/bin/$name" ] || [ -L "$USER_HOME/.local/bin/$name" ]; then
        ln -sfn "/usr/local/bin/$name" "$USER_HOME/.local/bin/$name"
        chown -h "$USERNAME:$USER_GROUP" "$USER_HOME/.local/bin/$name"
    fi
done

echo ". $SHARE_DIR/env" > /etc/profile.d/hermes-agent.sh
if [ -f /etc/bash.bashrc ] && ! grep -qF "$SHARE_DIR/env" /etc/bash.bashrc; then
    echo "[ -r $SHARE_DIR/env ] && . $SHARE_DIR/env" >> /etc/bash.bashrc
fi

if [ "$LINK_USER_HOME" = true ] && [ "$HOME_DIR" != "$USER_HOME/.hermes" ] \
    && [ ! -e "$USER_HOME/.hermes" ] && [ ! -L "$USER_HOME/.hermes" ]; then
    ln -s "$HOME_DIR" "$USER_HOME/.hermes"
    chown -h "$USERNAME:$USER_GROUP" "$USER_HOME/.hermes"
fi

# Build leftovers would otherwise be copied into every new volume.
rm -rf "$HOME_DIR/logs/install.log" "$HOME_DIR/telemetry"

if [ "$HOME_DIR" != "$VOLUME_TARGET" ]; then
    echo "hermes-agent: WARNING homeDir is $HOME_DIR, but the hermes-agent-config volume is mounted at $VOLUME_TARGET;" \
         "add your own mount for $HOME_DIR or its data is lost on rebuild" >&2
fi
echo "hermes-agent: installed $VERSION ($COMMIT) for $USERNAME (code $INSTALL_DIR, tools $RUNTIME_DIR, data $HOME_DIR)"
