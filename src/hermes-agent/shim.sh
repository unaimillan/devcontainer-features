#!/bin/sh
# Launcher for hermes, hermes-acp and hermes-agent: applies the feature's
# HERMES_* defaults, then hands over to the checkout's own launchers.
. /usr/local/share/hermes-agent/env
case "$(basename "$0")" in
    hermes-agent) exec "$HERMES_AGENT_DIR/.hermes/bin/hermes" --run-module run_agent "$@" ;;
    hermes-acp)   exec "$HERMES_AGENT_DIR/.hermes/bin/hermes-acp" "$@" ;;
    *)            exec "$HERMES_AGENT_DIR/.hermes/bin/hermes" "$@" ;;
esac
