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

load(":defs.bzl", "ebclfsa_aarch64_prebuild")

exports_files(
    [
        "build_image.sh",
        "defs.bzl",
        "extract_release_archive.py",
    ],
    visibility = ["//visibility:public"],
)

# The toolkit archive predates the S-CORE release archive layout and does not
# contain its own SSH key, so keep the separately pinned key as an override.
ebclfsa_aarch64_prebuild(
    base_image = "@eb_corbos_toolkit_fastdev_archive//file",
    packages = [
        "//ebclfsa_aarch64:network_config_deb",
        "//ebclfsa_aarch64:sshd_config_deb",
    ],
    ssh_target_key = "@eb_corbos_toolkit_target_key//file",
)
