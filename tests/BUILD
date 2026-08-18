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

load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "ubuntu_image_scripts_test",
    size = "small",
    srcs = ["ubuntu_image_scripts_test.sh"],
    data = [
        "//scripts:build_ubuntu_x86_64_image.sh",
        "//scripts:render_user_data.py",
        "//ubuntu_x86_64:cloud_init",
        "//ubuntu_x86_64:qemu_config",
    ],
    target_compatible_with = ["@platforms//os:linux"],
)

sh_test(
    name = "ebclfsa_image_scripts_test",
    size = "small",
    srcs = ["ebclfsa_image_scripts_test.sh"],
    data = [
        "//ebclfsa_aarch64:qemu_config",
        "//scripts:build_ebclfsa_aarch64_image.sh",
    ],
    target_compatible_with = ["@platforms//os:linux"],
)

# Verifies that everything which can be built without QEMU and network access
# still builds. The image targets themselves are tagged "manual" because they
# boot QEMU; they are built by the "Images: Build" workflow.
build_test(
    name = "image_packaging_build_test",
    targets = [
        "//ebclfsa_aarch64:network_config_tar",
    ],
)
