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

# EBcLfSA aarch64 prebuild

`img_ebclfsa_extract()` extracts a WIC image, kernel, and optional SSH key from an
EBcLfSA release archive (`.tar.gz`). The archive must contain exactly one `.wic` file
and its matching `-vmlinux` kernel. A matching `-ssh-target-key` is required unless
`without_key = True`.

```starlark
load("@score_os_images//score/os/ebclfsa_aarch64_prebuild:defs.bzl", "img_ebclfsa_extract")

img_ebclfsa_extract(
    name = "release",
    archive = "@score_os_images_release_archive//file",
)
```

The macro creates `release.wic`, `release-vmlinux`, and `release-ssh-key`. With
`without_key = True`, the SSH-key output is omitted. The `prefix` argument can be used
to choose a different prefix for these output targets.
