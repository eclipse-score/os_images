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

"""Public macro for using EBcLfSA release archives as QEMU images."""

load("//score/common/img_ebclfsa:defs.bzl", "img_ebclfsa_extract")
load("//score/common/qemu:qemu_config.bzl", "qemu_config")

_BUILD_SCRIPT = Label("//score/os/ebclfsa_aarch64_prebuild:build_image.sh")
_QEMU_TEMPLATE = Label("//score/os/ebclfsa_aarch64:qemu_config.template.json")

def ebclfsa_aarch64_prebuild(base_image, packages = [], ssh_target_key = None, visibility = None):
    """Defines the standard QEMU image targets for an EBcLfSA release archive.

    Args:
        base_image: Label of the pinned release archive file.
        packages: Optional labels of Debian packages in dependency order (i.e. more independent packages first) to install into the image.
        ssh_target_key: Optional key label for archives without a bundled key.
        visibility: Visibility applied to the five public image targets.
    """
    public_visibility = visibility if visibility != None else ["//visibility:public"]

    img_ebclfsa_extract(
        name = "extract_base_image",
        archive = base_image,
        without_key = ssh_target_key != None,
        prefix = "base",
    )

    native.filegroup(
        name = "vanilla-image",
        srcs = [":base.wic"],
        tags = ["manual"],
        visibility = public_visibility,
    )

    native.filegroup(
        name = "kernel",
        srcs = [":base-vmlinux"],
        tags = ["manual"],
        visibility = public_visibility,
    )

    if ssh_target_key == None:
        key_source = ":base-ssh-key"
    else:
        key_source = ssh_target_key

    native.filegroup(
        name = "ssh_target_key",
        srcs = [key_source],
        visibility = public_visibility,
    )

    if packages:
        package_locations = [
            " $(location %s)" % package
            for package in packages
        ]
        native.genrule(
            name = "build_custom_image",
            srcs = [
                ":vanilla-image",
                ":kernel",
                ":ssh_target_key",
                _BUILD_SCRIPT,
            ] + packages,
            outs = [
                "customized/image.wic",
                "customized/kernel-vmlinux",
            ],
            cmd = "bash $(location %s) $(RULEDIR) $(location :vanilla-image) $(location :kernel) $(RULEDIR)/customized $(location :ssh_target_key)%s" % (
                _BUILD_SCRIPT,
                "".join(package_locations),
            ),
            tags = ["manual"],
            visibility = ["//visibility:private"],
        )
        image_source = [
            "customized/image.wic",
        ]
    else:
        native.alias(
            name = "image",
            actual = ":vanilla-image",
            tags = ["manual"],
            visibility = public_visibility,
        )

    if packages:
        native.filegroup(
            name = "image",
            srcs = image_source,
            tags = ["manual"],
            visibility = public_visibility,
        )

    qemu_config(
        name = "qemu_config",
        out = "qemu_config.json",
        key = ":ssh_target_key",
        template = _QEMU_TEMPLATE,
        visibility = public_visibility,
    )
