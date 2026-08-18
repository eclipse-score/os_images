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

load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

genrule(
    name = "itf-image",
    srcs = [
        "cloud-init/meta-data",
        "cloud-init/user-data",
        "qemu_config.json",
        "//scripts:build_ubuntu_x86_64_image.sh",
        "@ubuntu_noble_minimal_cloudimg_amd64//file",
    ],
    outs = ["ubuntu-x86_64-itf/ubuntu-24.04-minimal-cloudimg-amd64.img"],
    cmd = """
        bash $(location //scripts:build_ubuntu_x86_64_image.sh) \
            $(RULEDIR) \
            $(location @ubuntu_noble_minimal_cloudimg_amd64//file) \
            $(RULEDIR)/ubuntu-x86_64-itf/ubuntu-24.04-minimal-cloudimg-amd64.img \
            $(location cloud-init/user-data) \
            $(location cloud-init/meta-data) \
            $(location qemu_config.json)
    """,
    tags = [
        "manual",
    ],
    visibility = ["//visibility:private"],
)

filegroup(
    name = "image",
    srcs = [":ubuntu-x86_64-itf/ubuntu-24.04-minimal-cloudimg-amd64.img"],
    tags = [
        "manual",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "qemu_config",
    srcs = ["qemu_config.json"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "cloud_init",
    srcs = [
        "cloud-init/meta-data",
        "cloud-init/user-data",
    ],
    visibility = ["//visibility:public"],
)
