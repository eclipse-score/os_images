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

load("@score_itf//:defs.bzl", "py_itf_test")

py_itf_test(
    name = "ubuntu_qemu_test",
    srcs = [
        "test_multicast.py",
        "test_ping.py",
    ],
    args = [
        "--qemu-config=$(location //ubuntu_x86_64:qemu_config)",
        "--qemu-rootfs=$(location //ubuntu_x86_64:image)",
    ],
    data = [
        "//ubuntu_x86_64:image",
        "//ubuntu_x86_64:qemu_config",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)

py_itf_test(
    name = "ebclfsa_qemu_test",
    srcs = [
        "test_multicast.py",
        "test_ping.py",
    ],
    args = [
        "--qemu-config=$(location //ebclfsa_aarch64:qemu_config)",
        "--qemu-kernel=$(location //ebclfsa_aarch64:kernel)",
        "--qemu-rootfs=$(location //ebclfsa_aarch64:image)",
    ],
    data = [
        "//ebclfsa_aarch64:image",
        "//ebclfsa_aarch64:kernel",
        "//ebclfsa_aarch64:qemu_config",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)
