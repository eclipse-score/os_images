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
| `:vanilla-image` | The unmodified base disk image |
| `:qemu_config` | `qemu_config.json` describing how to run the image |

`//ebclfsa_aarch64:kernel` additionally provides the kernel required to boot the
aarch64 image.

The image targets are tagged `manual`, since building them boots QEMU and needs
the base images to be downloaded.

## Build scripts

All the image build scripts are located in the `//scripts` package.
They can be used to build your own images.

## Usage from another Bazel module

```starlark
# MODULE.bazel
bazel_dep(name = "os_images", version = "1.0")
```

## Building locally

```console
$ sudo apt-get install -y cloud-image-utils qemu-system-arm \
      qemu-system-x86 qemu-utils sshpass
$ bazel build //ubuntu_x86_64:image
$ bazel build //ebclfsa_aarch64:image
```

Building the images requires KVM or falls back to slow TCG emulation.

## Testing

Run the image boot and bidirectional ping tests with:

```console
$ bazel test --config=qemu-integration //tests/...
```

## Security note

The resulting images permit passwordless root SSH login. They are meant for
integration testing only and must never be used in production.
