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

load("@rules_pkg//pkg:deb.bzl", "pkg_deb")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

# Debian packages installed in the image in addition to the toolkit's fastdev
# packages.
IMAGE_PACKAGES = [
    ":network_config_deb",
]

# Selected in kas.yml through EBCLFSA_FASTDEV_NETWORK_CONFIG, so it replaces the
# toolkit's ebclfsa-fastdev-network package instead of conflicting with it.
pkg_deb(
    name = "network_config_deb",
    architecture = "all",
    conffiles = ["/etc/config/network"],
    data = "//ebclfsa_aarch64:network_config_tar",
    description = "Eclipse S-CORE network configuration for EB corbos Linux for Safety Applications",
    homepage = "https://github.com/eclipse-score/os_images",
    maintainer = "Eclipse S-CORE contributors <score-dev@eclipse.org>",
    package = "score-network-config",
    version = "1.0",
    visibility = ["//visibility:public"],
)

# Builds the image with KAS/Isar in a privileged container. This takes a long
# time, so the target is only built when explicitly requested.
genrule(
    name = "build-image",
    srcs = [
        "kas.yml",
        "@eb_corbos_toolkit//:BUILD.bazel",
        "@eb_corbos_toolkit//:sources",
    ] + IMAGE_PACKAGES + glob(["meta-score/**"]),
    outs = [
        "fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux",
        "fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic",
    ],
    cmd = "bash $(location build_image.sh) " +
          "$$(dirname $(location @eb_corbos_toolkit//:BUILD.bazel)) " +
          "$(location kas.yml) " +
          "$(RULEDIR) " +
          " ".join(["\"$(location %s)\"" % package for package in IMAGE_PACKAGES]),
    local = True,
    tags = ["manual"],
    tools = ["build_image.sh"],
    visibility = ["//visibility:private"],
)

filegroup(
    name = "image",
    srcs = [":fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic"],
    tags = ["manual"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "kernel",
    srcs = [":fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux"],
    tags = ["manual"],
    visibility = ["//visibility:public"],
)

sh_test(
    name = "build_image_test",
    size = "small",
    srcs = ["build_image_test.sh"],
    args = [
        "$(location :network_config_deb)",
        "$(location //ebclfsa_aarch64:config-overlay/etc/config/network)",
    ],
    data = [
        "build_image.sh",
        "kas.yml",
        ":network_config_deb",
        "//ebclfsa_aarch64:config-overlay/etc/config/network",
    ] + glob(["meta-score/**"]),
)
