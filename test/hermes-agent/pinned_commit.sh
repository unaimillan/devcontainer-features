#!/bin/bash

# Scenario 'pinned_commit' (see scenarios.json): an explicit SHA is installed as-is.

set -e

source dev-container-features-test-lib

check "pinned version recorded" bash -c '[ "$(cat /usr/local/share/hermes-agent/version)" = a174341a8971c3597a5f76011a4ac6730727b564 ]'
check "checkout at pinned commit" bash -c '[ "$(git -C /opt/hermes/agent rev-parse HEAD)" = a174341a8971c3597a5f76011a4ac6730727b564 ]'
check "hermes runs" hermes --version

reportResults
