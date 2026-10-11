#!/bin/bash

# Runs against an auto-generated devcontainer.json that includes the
# 'hermes-agent' feature with default options.
#
#    devcontainer features test -f hermes-agent -i debian:latest .

set -e

# Provides the 'check' and 'reportResults' commands.
source dev-container-features-test-lib

check "installed commit recorded" bash -c '[[ "$(cat /usr/local/share/hermes-agent/version)" =~ ^[0-9a-f]{40}$ ]]'
check "checkout at recorded commit" bash -c '[ "$(git -C /opt/hermes/agent rev-parse HEAD)" = "$(cat /usr/local/share/hermes-agent/version)" ]'
check "hermes runs" hermes --version
check "hermes resolves to the shim" bash -c '[ "$(readlink -f "$(command -v hermes)")" = /usr/local/share/hermes-agent/shim ]'
check "HERMES_HOME default" bash -c '. /usr/local/share/hermes-agent/env && [ "$HERMES_HOME" = /var/lib/hermes ]'
check "HERMES_RUNTIME_DIR default" bash -c '. /usr/local/share/hermes-agent/env && [ "$HERMES_RUNTIME_DIR" = /opt/hermes/tools ]'
check "data dir writable" test -w /var/lib/hermes
check "config.yaml seeded" test -f /var/lib/hermes/config.yaml
check ".env is private" bash -c '[ "$(stat -c %a /var/lib/hermes/.env)" = 600 ]'
# Code and tool store must stay out of the persisted volume.
check "no code in data dir" test ! -e /var/lib/hermes/hermes-agent
check "no tools in data dir" test ! -e /var/lib/hermes/tools
check "dependency state in image" bash -c '[ -f "$(echo /opt/hermes/installs/*/facts.json)" ]'
check "data dir links to dependency state" bash -c 'for s in /opt/hermes/installs/*; do [ "$(readlink "/var/lib/hermes/installs/${s##*/}")" = "$s" ] || exit 1; done'
# A volume from an older image or a manual install holds a stale copy instead.
check "ensure.sh relinks a stale volume" bash -c 's=$(echo /opt/hermes/installs/*) l=/var/lib/hermes/installs/${s##*/} && rm "$l" && mkdir "$l" && /usr/local/share/hermes-agent/ensure.sh >/dev/null && [ "$(readlink "$l")" = "$s" ] && hermes --version'
check "tool store in image" bash -c '[ -n "$(ls -A /opt/hermes/tools)" ]'
check "tool store writable" test -w /opt/hermes/tools
check "git reads the checkout" git -C /opt/hermes/agent status --short
check "~/.hermes links to data dir" bash -c '[ "$(readlink -f ~/.hermes)" = /var/lib/hermes ]'

reportResults
