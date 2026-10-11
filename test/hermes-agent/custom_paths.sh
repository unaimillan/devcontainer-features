#!/bin/bash

# Scenario 'custom_paths' (see scenarios.json): every path option is honoured.

set -e

source dev-container-features-test-lib

check "checkout in installDir" test -d /srv/hermes/agent/.git
check "tool store in runtimeDir" bash -c '[ -n "$(ls -A /srv/hermes/tools)" ]'
check "dependency state in installsDir" bash -c '[ -f "$(echo /srv/hermes/installs/*/facts.json)" ] && [ -L "$(echo /srv/hermes/home/installs/*)" ]'
check "HERMES_HOME is homeDir" bash -c '. /usr/local/share/hermes-agent/env && [ "$HERMES_HOME" = /srv/hermes/home ]'
check "config.yaml in homeDir" test -f /srv/hermes/home/config.yaml
check "no code or tools in homeDir" bash -c '[ ! -e /srv/hermes/home/hermes-agent ] && [ ! -e /srv/hermes/home/tools ]'
check "~/.hermes not linked" bash -c '[ ! -L ~/.hermes ]'
check "hermes runs" hermes --version

reportResults
