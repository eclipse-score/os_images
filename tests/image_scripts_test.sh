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
# Verifies the image build scripts without actually booting QEMU: the scripts
# are syntactically valid, they reject invalid invocations instead of producing
# a broken image, and the cloud-init user-data is rendered from the values in
# qemu_config.json.

set -euo pipefail

UBUNTU_BUILD_SCRIPT="scripts/build_ubuntu_x86_64_image.sh"
EBCLFSA_BUILD_SCRIPT="scripts/build_ebclfsa_aarch64_image.sh"
RENDERER="scripts/render_user_data.py"
UBUNTU_QEMU_CONFIG="ubuntu_x86_64/qemu_config.json"
EBCLFSA_QEMU_CONFIG="ebclfsa_aarch64/qemu_config.json"
USER_DATA="ubuntu_x86_64/cloud-init/user-data"
META_DATA="ubuntu_x86_64/cloud-init/meta-data"

failures=0

fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
}

for f in "${UBUNTU_BUILD_SCRIPT}" "${EBCLFSA_BUILD_SCRIPT}" "${RENDERER}" \
    "${UBUNTU_QEMU_CONFIG}" "${EBCLFSA_QEMU_CONFIG}" "${USER_DATA}" "${META_DATA}"; do
    [[ -f "${f}" ]] || fail "missing file: ${f}"
done
((failures == 0)) || exit 1

# The scripts must be parseable, otherwise the image genrules fail late.
for script in "${UBUNTU_BUILD_SCRIPT}" "${EBCLFSA_BUILD_SCRIPT}"; do
    bash -n "${script}" || fail "syntax error in ${script}"
done
python3 -m py_compile "${RENDERER}" || fail "syntax error in ${RENDERER}"

# Both build scripts must reject a wrong number of arguments.
if bash "${UBUNTU_BUILD_SCRIPT}" only-one-argument &>/dev/null; then
    fail "${UBUNTU_BUILD_SCRIPT} accepted a wrong number of arguments"
fi
if bash "${EBCLFSA_BUILD_SCRIPT}" only-one-argument &>/dev/null; then
    fail "${EBCLFSA_BUILD_SCRIPT} accepted a wrong number of arguments"
fi

# The QEMU configurations must be valid JSON providing a network the images are
# configured for.
for config in "${UBUNTU_QEMU_CONFIG}" "${EBCLFSA_QEMU_CONFIG}"; do
    python3 -c "
import json, sys
config = json.load(open(sys.argv[1], encoding='utf-8'))
network = config['networks'][0]
assert network['ip_address'] and network['gateway'], sys.argv[1]
assert config['ssh_port'] and config['qemu_machine'], sys.argv[1]
" "${config}" || fail "invalid QEMU config: ${config}"
done

# Rendering must substitute the placeholders with the configured addresses.
RENDERED="${TEST_TMPDIR:-/tmp}/user-data.rendered"
python3 "${RENDERER}" "${UBUNTU_QEMU_CONFIG}" "${USER_DATA}" "${RENDERED}" ||
    fail "rendering the cloud-init user-data failed"

if grep -q "__SCORE_ITF_" "${RENDERED}"; then
    fail "rendered user-data still contains placeholders"
fi

ip_address="$(python3 -c "
import json, sys
print(json.load(open(sys.argv[1], encoding='utf-8'))['networks'][0]['ip_address'])
" "${UBUNTU_QEMU_CONFIG}")"
grep -q "${ip_address}" "${RENDERED}" ||
    fail "rendered user-data does not configure ${ip_address}"

# A user-data without placeholders must be reported instead of silently
# producing an image without network configuration.
BROKEN_TEMPLATE="${TEST_TMPDIR:-/tmp}/user-data.broken"
echo "#cloud-config" > "${BROKEN_TEMPLATE}"
if python3 "${RENDERER}" "${UBUNTU_QEMU_CONFIG}" "${BROKEN_TEMPLATE}" "${RENDERED}" &>/dev/null; then
    fail "renderer accepted a user-data template without placeholders"
fi

((failures == 0)) || exit 1
echo "PASS"
