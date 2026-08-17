# QEMU Images

Bazel definitions for the QEMU images used by the
[S-CORE ITF](https://github.com/eclipse-score/itf) integration test framework.
The definitions were ported from the ITF repository so that other repositories
can depend on them directly.

## Images

| Package | Base | Architecture |
| --- | --- | --- |
| `//ubuntu_x86_64` | Ubuntu 24.04 minimal cloud image | x86_64 |
| `//ebclfsa_aarch64` | EB corbos Linux for Safety Applications fastdev image | aarch64 |

Both packages expose the same public targets:

| Target | Content |
| --- | --- |
| `:image` | The customized disk image |
| `:qemu_config` | `qemu_config.json` describing how to run the image |

`//ebclfsa_aarch64:kernel` additionally provides the kernel required to boot the
aarch64 image.

The image targets are tagged `manual`, since building them boots QEMU and needs
the base images to be downloaded.

## Usage from another Bazel module

```starlark
# MODULE.bazel
bazel_dep(name = "os_images", version = "1.0")
```

```starlark
# BUILD
load("@os_images//:defs.bzl", "copy_files_onto_image")

copy_files_onto_image(
    name = "my_image",
    srcs = [":my_files_tar"],
    image = "@os_images//ubuntu_x86_64:image",
)
```

## Building locally

```console
$ sudo apt-get install -y cloud-image-utils libguestfs-tools qemu-system-arm \
      qemu-system-x86 qemu-utils sshpass
$ bazel build //ubuntu_x86_64:itf-image
$ bazel build //ebclfsa_aarch64:itf-image
```

Building the images requires KVM or falls back to slow TCG emulation.

## Testing

```console
$ bazel test //tests/...
```

The tests check the image build scripts and the packaging targets without
booting QEMU. The images themselves are built by the
`QEMU Images: Build and Test` workflow.

## Security note

The resulting images permit passwordless root SSH login. They are meant for
integration testing only and must never be used in production.
