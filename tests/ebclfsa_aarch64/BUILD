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
load("//bazel:copy_files_onto_image.bzl", "copy_files_onto_image")

pkg_tar(
    name = "overlay_files",
    srcs = ["overlay/score_itf_overlay_marker"],
    mode = "0644",
    package_dir = "/etc/score_itf",
    visibility = ["//tests:__pkg__"],
)

copy_files_onto_image(
    name = "image_with_overlay",
    srcs = [":overlay_files"],
    out = "fastdev-ubuntu-ebclfsa-ebcl-qemuarm64.overlay.qcow2",
    image = "//ebclfsa_aarch64:image",
    tags = ["manual"],
    visibility = ["//tests:__pkg__"],
)
