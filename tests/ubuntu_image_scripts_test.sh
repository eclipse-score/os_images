#!/bin/bash
# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************
#
# Verifies the Ubuntu image build script without booting QEMU: the script is
# syntactically valid, it rejects invalid invocations, and cloud-init user-data
# is rendered from qemu_config.json.

set -euo pipefail

BUILD_SCRIPT="scripts/build_ubuntu_x86_64_image.sh"
RENDERER="scripts/render_user_data.py"
QEMU_CONFIG="ubuntu_x86_64/qemu_config.json"
USER_DATA="ubuntu_x86_64/cloud-init/user-data"
META_DATA="ubuntu_x86_64/cloud-init/meta-data"

failures=0

fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
}

for f in "${BUILD_SCRIPT}" "${RENDERER}" "${QEMU_CONFIG}" "${USER_DATA}" "${META_DATA}"; do
    [[ -f "${f}" ]] || fail "missing file: ${f}"
done
((failures == 0)) || exit 1

bash -n "${BUILD_SCRIPT}" || fail "syntax error in ${BUILD_SCRIPT}"
python3 -m py_compile "${RENDERER}" || fail "syntax error in ${RENDERER}"

if bash "${BUILD_SCRIPT}" only-one-argument &>/dev/null; then
    fail "${BUILD_SCRIPT} accepted a wrong number of arguments"
fi

python3 -c "
import json, sys
config = json.load(open(sys.argv[1], encoding='utf-8'))
network = config['networks'][0]
assert network['ip_address'] and network['gateway'], sys.argv[1]
assert config['ssh_port'] and config['qemu_machine'], sys.argv[1]
" "${QEMU_CONFIG}" || fail "invalid QEMU config: ${QEMU_CONFIG}"

RENDERED="${TEST_TMPDIR:-/tmp}/user-data.rendered"
python3 "${RENDERER}" "${QEMU_CONFIG}" "${USER_DATA}" "${RENDERED}" ||
    fail "rendering the cloud-init user-data failed"

if grep -q "__SCORE_ITF_" "${RENDERED}"; then
    fail "rendered user-data still contains placeholders"
fi

ip_address="$(python3 -c "
import json, sys
print(json.load(open(sys.argv[1], encoding='utf-8'))['networks'][0]['ip_address'])
" "${QEMU_CONFIG}")"
grep -q "${ip_address}" "${RENDERED}" ||
    fail "rendered user-data does not configure ${ip_address}"

BROKEN_TEMPLATE="${TEST_TMPDIR:-/tmp}/user-data.broken"
echo "#cloud-config" > "${BROKEN_TEMPLATE}"
if python3 "${RENDERER}" "${QEMU_CONFIG}" "${BROKEN_TEMPLATE}" "${RENDERED}" &>/dev/null; then
    fail "renderer accepted a user-data template without placeholders"
fi

((failures == 0)) || exit 1
echo "PASS"
