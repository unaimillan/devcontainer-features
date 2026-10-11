#!/bin/bash

# Runs against an auto-generated devcontainer.json that includes the
# 'oss-cad-suite' feature with default options (version: latest).
#
#    devcontainer features test -f oss-cad-suite -i debian:latest .

set -e

# Provides the 'check' and 'reportResults' commands.
source dev-container-features-test-lib

VERSION="$(cat /usr/local/share/oss-cad-suite/version)"

check "version is a concrete tag" bash -c "[[ '$VERSION' =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]"
check "symlink points at pinned release" bash -c "[ \"\$(readlink /usr/local/oss-cad-suite)\" = /opt/oss-cad-suite/$VERSION ]"
check "release populated in volume" test -f "/opt/oss-cad-suite/$VERSION/.complete"
# Appended, not prepended: system tools must keep priority over the suite's.
check "suite bin on PATH after /usr/bin" bash -c 'p=":$PATH:"; s=${p%%:/usr/local/oss-cad-suite/bin:*}; u=${p%%:/usr/bin:*}; [ "$s" != "$p" ] && [ ${#u} -lt ${#s} ]'
check "yosys runs" yosys -V
check "verilator runs" verilator --version
check "iverilog runs" bash -c "iverilog -V 2>&1 | grep -i 'Icarus Verilog'"

reportResults
