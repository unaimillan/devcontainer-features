#!/bin/bash

# Scenario 'pinned_version' (see scenarios.json): an explicit date tag is used as-is.

set -e

source dev-container-features-test-lib

check "pinned version recorded" bash -c '[ "$(cat /usr/local/share/oss-cad-suite/version)" = 2026-10-11 ]'
check "release populated in volume" test -f /opt/oss-cad-suite/2026-10-11/.complete
check "yosys runs" yosys -V
check "verilator runs" verilator --version

reportResults
