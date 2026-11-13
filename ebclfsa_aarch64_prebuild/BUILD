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

exports_files(
    [
        "build_image.sh",
    ],
    visibility = ["//visibility:public"],
)

# Preserve the base image's SSH configuration and root password.
IMAGE_PACKAGES = [
    "//ebclfsa_aarch64:network_config_deb",
]

genrule(
    name = "extract-fastdev-image",
    srcs = ["@eb_corbos_toolkit_fastdev_archive//file"],
    outs = [
        "ebcl-qemuarm64/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic",
        "ebcl-qemuarm64/fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux",
    ],
    cmd = "mkdir -p $(RULEDIR)/ebcl-qemuarm64 && tar xzf $(location @eb_corbos_toolkit_fastdev_archive//file) -C $(RULEDIR)/ebcl-qemuarm64 && chmod +w $(RULEDIR)/ebcl-qemuarm64/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic",
    tags = [
        "manual",
    ],
    visibility = ["//visibility:private"],
)

genrule(
    name = "itf-image",
    srcs = [
        ":extract-fastdev-image",
        ":ssh_target_key",
        "build_image.sh",
    ] + IMAGE_PACKAGES,
    outs = [
        "ebcl-qemuarm64-itf/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic",
        "ebcl-qemuarm64-itf/fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux",
    ],
    cmd = """
        bash $(location :build_image.sh) \
            $(RULEDIR) \
            $(RULEDIR)/ebcl-qemuarm64 \
            $(RULEDIR)/ebcl-qemuarm64-itf \
            $(location :ssh_target_key) \
            $(location //ebclfsa_aarch64:network_config_deb)
    """,
    tags = [
        "manual",
    ],
    visibility = ["//visibility:private"],
)

filegroup(
    name = "image",
    srcs = [":ebcl-qemuarm64-itf/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic"],
    tags = [
        "manual",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "vanilla-image",
    srcs = ["ebcl-qemuarm64/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic"],
    tags = [
        "manual",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "kernel",
    srcs = [":ebcl-qemuarm64/fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux"],
    tags = [
        "manual",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "ssh_target_key",
    srcs = ["@eb_corbos_toolkit_target_key//file"],
    visibility = ["//visibility:public"],
)

genrule(
    name = "qemu_config",
    srcs = [
        ":ssh_target_key",
        "//ebclfsa_aarch64:qemu_config.json",
    ],
    outs = ["qemu_config.json"],
    # ITF resolves the key from the test's runfiles working directory.
    cmd = """sed '1a\\    "ssh_auth": {"pkey_path": "$(rootpath :ssh_target_key)"},' $(location //ebclfsa_aarch64:qemu_config.json) > $@""",
    visibility = ["//visibility:public"],
)
