#!/bin/bash
# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
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

# Checks the workspace staging of build_image.sh without a privileged container
# or network access, and the content of the network configuration package.
# Arguments: NETWORK_CONFIG_DEB NETWORK_CONFIG_FILE

set -euo pipefail

[[ $# == 2 ]]
network_deb=$(realpath "$1")
network_config=$(realpath "$2")
sources="$TEST_SRCDIR/_main/ebclfsa_aarch64_from_scratch"
fixture="$TEST_TMPDIR/fixture"
output="$TEST_TMPDIR/output"
mkdir -p "$fixture/"{kas,layers/isar,.devcontainer,prebuilt} "$output"
echo "must not use a prebuilt image" > "$fixture/prebuilt/image.wic"
echo "KAS configuration" > "$fixture/kas/public.yml"
echo "bundled Isar" > "$fixture/layers/isar/isar-init-build-env"
echo "container configuration" > "$fixture/.devcontainer/devcontainer.json"
package_names=(first-package second-package third-package fourth-package)
debs=()
for name in "${package_names[@]}"; do
    package="$TEST_TMPDIR/packages/$name"
    mkdir -p "$package/root/DEBIAN"
    cat > "$package/root/DEBIAN/control" <<EOF
Package: $name
Version: 2.3
Architecture: all
Maintainer: Test <test@example.com>
Description: Image staging test fixture
EOF
    debs+=("$package/input package.deb")
    dpkg-deb --build "$package/root" "${debs[-1]}" >/dev/null
done

docker() {
    if [[ $1 == info ]]; then
        return 0
    fi
    touch "$TEST_TMPDIR/docker-ran"
    local mount work deploy
    while [[ $# -gt 0 ]]; do
        if [[ $1 == --mount ]]; then
            mount=$2
            break
        fi
        shift
    done
    work=${mount#type=bind,src=}
    work=${work%,dst=/workspace}
    [[ ! -e "$work/prebuilt" ]]
    cmp "$TEST_TMPDIR/fixture/kas/public.yml" "$work/kas/public.yml"
    cmp "$TEST_TMPDIR/fixture/layers/isar/isar-init-build-env" "$work/layers/isar/isar-init-build-env"
    cmp "$TEST_TMPDIR/fixture/.devcontainer/devcontainer.json" "$work/.devcontainer/devcontainer.json"
    local name count=0
    for name in $EXPECTED_PACKAGE_NAMES; do
        cmp "$TEST_TMPDIR/packages/$name/input package.deb" \
            "$work/meta-score/recipes-score/$name/files/$name.deb"
        grep -qx 'inherit dpkg-prebuilt' "$work/meta-score/recipes-score/$name/${name}_1.0.bb"
        grep -qx "SRC_URI = \"file://$name.deb\"" \
            "$work/meta-score/recipes-score/$name/${name}_1.0.bb"
        count=$((count + 1))
    done
    [[ $(find "$work/meta-score" -name '*.deb' | wc -l) -eq $count ]]
    [[ $(find "$work/meta-score" -name '*.bb' | wc -l) -eq $count ]]
    grep -Fxq "    IMAGE_INSTALL:append = \" $EXPECTED_PACKAGE_NAMES\"" "$work/kas/score-packages.yml"
    cmp "$sources/kas.yml" "$work/kas/score.yml"
    if [[ ${MOCK_DOCKER_FAIL:-0} == 1 ]]; then
        return 17
    fi
    deploy="$work/build/tmp/deploy/images/ebcl-qemuarm64"
    mkdir -p "$deploy"
    echo kernel > "$deploy/fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux"
    if [[ ${MOCK_MISSING_IMAGE:-0} != 1 ]]; then
        echo disk > "$deploy/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic"
    fi
}
export -f docker

build_image() {
    bash "$sources/build_image.sh" "$fixture" "$sources/kas.yml" "$output" "$@"
}

for count in 0 1 2 4; do
    export EXPECTED_PACKAGE_NAMES="${package_names[*]:0:count}"
    build_image "${debs[@]:0:count}"
done

# The network package must be selected in kas.yml and carry the shared config.
[[ $(dpkg-deb --field "$network_deb" Package) == score-network-config ]]
[[ $(dpkg-deb --field "$network_deb" Architecture) == all ]]
grep -Fxq '    EBCLFSA_FASTDEV_NETWORK_CONFIG = "score-network-config"' "$sources/kas.yml"
installed="$TEST_TMPDIR/installed"
dpkg-deb --extract "$network_deb" "$installed"
cmp "$network_config" "$installed/etc/config/network"
[[ $(stat -c %a "$installed/etc/config/network") == 644 ]]
dpkg-deb --control "$network_deb" "$TEST_TMPDIR/network-control"
grep -Fxq /etc/config/network "$TEST_TMPDIR/network-control/conffiles"
mkdir -p "$TEST_TMPDIR/packages/score-network-config"
cp "$network_deb" "$TEST_TMPDIR/packages/score-network-config/input package.deb"
export EXPECTED_PACKAGE_NAMES="score-network-config"
build_image "$network_deb"

[[ ! -e "$fixture/kas/score.yml" ]]
[[ ! -e "$fixture/meta-score" ]]
[[ $(cat "$output/fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux") == kernel ]]
[[ $(cat "$output/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic") == disk ]]

expect_rejected_package() {
    rm -f "$TEST_TMPDIR/docker-ran"
    if build_image "$@" > "$TEST_TMPDIR/rejected.log" 2>&1; then
        echo "Error: invalid package input was accepted: $*" >&2
        exit 1
    fi
    [[ ! -e "$TEST_TMPDIR/docker-ran" ]]
}

expect_rejected_package "$TEST_TMPDIR/missing.deb"
echo "not a Debian archive" > "$TEST_TMPDIR/invalid.deb"
expect_rejected_package "$TEST_TMPDIR/invalid.deb"
expect_rejected_package "${debs[0]}" "${debs[0]}"
grep -q 'Error: duplicate package or existing recipe for: first-package' "$TEST_TMPDIR/rejected.log"

export EXPECTED_PACKAGE_NAMES="${package_names[*]}"
export MOCK_DOCKER_FAIL=1
status=0
build_image "${debs[@]}" || status=$?
if [[ $status != 17 ]]; then
    echo "Error: container failure was not propagated" >&2
    exit 1
fi
export MOCK_DOCKER_FAIL=0 MOCK_MISSING_IMAGE=1
if build_image "${debs[@]}"; then
    echo "Error: missing image artifact was not rejected" >&2
    exit 1
fi
if find "$output" -maxdepth 1 -name 'kas-work.*' | grep -q .; then
    echo "Error: temporary KAS workspace was not cleaned up" >&2
    exit 1
fi
