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

# EBcLfSA release archive extraction

`img_ebclfsa_extract()` extracts a WIC image, kernel, and optional SSH key from an
EBcLfSA release archive (`.tar.gz`). The archive must contain exactly one `.wic` file,
a matching `-vmlinux` kernel, and optionally a matching `-ssh-target-key`.

```starlark
load("@score_os_images//score/common/img_ebclfsa:defs.bzl", "img_ebclfsa_extract")

img_ebclfsa_extract(
    name = "release",
    archive = "@score_os_images_release_archive//file",
)
```

Outputs:
- `release.wic`: the WIC image (if `include_wic=True`, default)
- `release-vmlinux`: the kernel (if `include_kernel=True`, default)
- `release-ssh-key`: the SSH key (if `include_key=True` and `without_key=False`, default)

Use `include_*` and `without_key` to control which outputs are extracted.
