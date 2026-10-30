<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->
# EB corbos Linux for Safety Applications: image from scratch

Builds a new `fastdev` aarch64 disk image with KAS/Isar from a Git checkout of the
[EB corbos Toolkit v2.0.0-beta3 tag](https://github.com/Elektrobit/eb_corbos_toolkit/tree/v2.0.0-beta3),
pinned to its commit in `MODULE.bazel`. Unlike [`//ebclfsa_aarch64`](../ebclfsa_aarch64),
it neither downloads nor boots the toolkit's prebuilt disk image. The toolkit
still supplies precompiled system packages, including the kernel; this is an
image build from packages, not a source rebuild of the entire OS.

```console
$ bazel build //ebclfsa_aarch64_from_scratch:image //ebclfsa_aarch64_from_scratch:kernel
```

The build takes a long time, so all image targets are tagged `manual` and are
only built when selected explicitly. The kernel and `.wic` disk image are written
to `bazel-bin/ebclfsa_aarch64_from_scratch/`.

| Target | Content |
| --- | --- |
| `:image` | The `.wic` disk image |
| `:kernel` | The kernel required to boot the image |
| `:network_config_deb` | The `score-network-config` Debian package |

## Requirements

- An x86_64 Linux host with Docker, `dpkg-deb` (from `dpkg`), and permission to
  run privileged containers. The Docker daemon must see the Bazel output
  directory at the same absolute path as the build process (no remote daemon).
- Network access to GitHub, GHCR and the package repositories referenced by the
  toolkit, and substantial free disk space for the Isar build.

The build runs the toolkit's digest-pinned development container. It registers
its aarch64 binfmt interpreter if none is registered; this requires privileged
access and affects the host kernel's binfmt registry. KAS/Isar needs privileges
for chroots and mounts, so the action cannot run in a Bazel sandbox or on a
remote executor.

## Network configuration

The image uses the same network configuration as `//ebclfsa_aarch64`
([`network`](../ebclfsa_aarch64/config-overlay/etc/config/network)): static
address `169.254.158.190/16` on `eth0`, gateway `169.254.21.88`, and a multicast
route. The file is packaged as `score-network-config`, which [kas.yml](kas.yml)
selects through `EBCLFSA_FASTDEV_NETWORK_CONFIG` in place of the toolkit's
`ebclfsa-fastdev-network` package. It therefore matches the addresses in
[`qemu_config.json`](../ebclfsa_aarch64/qemu_config.json).

## Root SSH login

Like `//ebclfsa_aarch64:image`, the image permits passwordless root SSH login for
integration testing. It must never be used in production.

- The `score-itf-sshd-config` package installs
  [`99-integration-test.conf`](sshd-config/99-integration-test.conf) into
  `/etc/ssh/sshd_config.d`.
- [`fastdev_%.bbappend`](meta-score/recipes-images/fastdev/fastdev_%.bbappend)
  clears the root password at the end of the rootfs post-processing, after the
  toolkit has set its default password `linux`.

The `/opt` mount of `//ebclfsa_aarch64:image` is not applied to this image.

## Selecting packages

Edit `IMAGE_PACKAGES` in [BUILD](BUILD) to select the Debian packages installed in
the image. The [build script](build_image.sh) accepts zero or more Debian package
paths after its three fixed arguments:

```console
$ bash ebclfsa_aarch64_from_scratch/build_image.sh \
    /path/to/toolkit ebclfsa_aarch64_from_scratch/kas.yml \
    /existing/output/directory \
    /path/to/first.deb "/path/to/another package.deb"
```

Each package is copied into its own generated `dpkg-prebuilt` recipe in a
temporary workspace, and a generated KAS fragment adds all package names, read
from the Debian control metadata, to `IMAGE_INSTALL`. Duplicate package names are
rejected. Packages must be compatible with the arm64 image, and their
dependencies must be available from the configured repositories or supplied in
the same list.

## Tests

The staging test checks the generated workspace, the configuration packages, the
root password post-processing and the error handling without Docker:

```console
$ bazel test //ebclfsa_aarch64_from_scratch:build_image_test
```

The ping, multicast and no-disk QEMU integration tests boot the image with
`//ebclfsa_aarch64:qemu_config`. The test is tagged `manual`, so
`bazel test --config=qemu-integration //tests/...` does not build this image:

```console
$ bazel test --config=qemu-integration //tests:ebclfsa_from_scratch_qemu_test
```

The [EBcLfSA from scratch workflow](../.github/workflows/ebclfsa_from_scratch_build.yml)
builds the image and runs these tests when files of this package, the shared
network or QEMU configuration, or the tests change. It can also be started manually.
