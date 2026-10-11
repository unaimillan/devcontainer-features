#!/usr/bin/env bash
# Create-time part of the feature: make sure HERMES_HOME is writable and holds
# the config skeleton the installer would create (a volume first created
# without the image's seed starts empty). Never overwrites existing files.
set -euo pipefail

SHARE_DIR=/usr/local/share/hermes-agent
# shellcheck source=/dev/null
. "$SHARE_DIR/env"

if [ ! -w "$HERMES_HOME" ] && ! sudo -n chown "$(id -u):$(id -g)" "$HERMES_HOME" 2>/dev/null; then
    echo "hermes-agent: $HERMES_HOME is not writable by $(id -un) and passwordless sudo is unavailable." >&2
    echo "hermes-agent: fix once with: docker run --rm -v hermes-agent-config:/v alpine chown $(id -u):$(id -g) /v" >&2
    exit 1
fi

mkdir -p "$HERMES_HOME"/{cron,sessions,logs,pairing,hooks,image_cache,audio_cache,memories,skills}
if [ ! -f "$HERMES_HOME/.env" ]; then
    cp "$HERMES_AGENT_DIR/.env.example" "$HERMES_HOME/.env" 2>/dev/null || touch "$HERMES_HOME/.env"
fi
chmod 600 "$HERMES_HOME/.env"
if [ ! -f "$HERMES_HOME/config.yaml" ] && [ -f "$HERMES_AGENT_DIR/cli-config.yaml.example" ]; then
    cp "$HERMES_AGENT_DIR/cli-config.yaml.example" "$HERMES_HOME/config.yaml"
fi

echo "hermes-agent $(cat "$SHARE_DIR/version") ready, data in $HERMES_HOME"
hermes --version
echo "hermes-agent: run 'hermes setup' once; the result persists in $HERMES_HOME"
