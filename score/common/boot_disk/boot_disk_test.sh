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
#
# Checks the boot_disk test images (see BUILD.bazel): partition table type and
# FAT contents, including files placed in a subdirectory via pkg_files. Also
# checks that build_image.sh rejects bad input.
#
# Usage: boot_disk_test.sh <build_image.sh> <mbr image> <gpt image> <fat16 image>

set -euo pipefail

script="$1"
mbr_img="$2"
gpt_img="$3"
fat16_img="$4"

for tool in mcopy mdir sfdisk; do
    if ! command -v "$tool" &>/dev/null; then
        echo "Error: required tool '$tool' is not installed." >&2
        exit 1
    fi
done

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

# Offset (bytes) of the FAT partition, the boot_disk default of 1024 KiB.
offset_bytes=$((1024 * 1024))

# Asserts FAT path $2 in image $1 exists and holds its own basename (see the
# test_fixtures genrule).
assert_file() {
    local img="$1" path="$2"
    if ! mcopy -i "$img@@$offset_bytes" -o "::$path" "$work/out" 2>/dev/null; then
        echo "Error: '$path' missing from FAT partition of $img" >&2
        mdir -i "$img@@$offset_bytes" -/ :: >&2 || true
        exit 1
    fi
    if [[ "$(cat "$work/out")" != "$(basename "$path")" ]]; then
        echo "Error: '$path' in $img has unexpected content" >&2
        exit 1
    fi
}

assert_contents() {
    assert_file "$1" u-boot.bin
    assert_file "$1" config.txt
    assert_file "$1" overlays/overlay.dtbo
}

# --- MBR + bootable FAT32 -----------------------------------------------------
table=$(sfdisk -d "$mbr_img")
grep -Fq 'label: dos' <<<"$table"
grep -Eq 'type=c\b' <<<"$table"
grep -Fq 'bootable' <<<"$table"
assert_contents "$mbr_img"

# --- GPT with a single EFI System Partition -----------------------------------
table=$(sfdisk -d "$gpt_img")
grep -Fq 'label: gpt' <<<"$table"
grep -Fiq 'C12A7328-F81F-11D2-BA4B-00A0C93EC93B' <<<"$table"
assert_contents "$gpt_img"

# --- MBR + FAT16 ----------------------------------------------------------------
table=$(sfdisk -d "$fat16_img")
grep -Eq 'type=e\b' <<<"$table"
assert_contents "$fat16_img"

# --- Bad input must fail --------------------------------------------------------
expect_failure() {
    if bash "$script" "$@" >"$work/bad.log" 2>&1; then
        echo "Error: build_image.sh accepted: $*" >&2
        exit 1
    fi
}
printf x >"$work/f"
expect_failure --out "$work/bad.img"
expect_failure --out "$work/bad.img" "$work/f"
expect_failure --out "$work/bad.img" --label TOOLONGLABEL1 "f=$work/f"
expect_failure --out "$work/bad.img" --size-mib 16 "f=$work/f"
expect_failure --out "$work/bad.img" --partition-table gpt --offset-kib 8 "f=$work/f"
expect_failure --out "$work/bad.img" "f=$work/missing"

echo "boot_disk tests passed"
