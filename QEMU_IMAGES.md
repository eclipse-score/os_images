# QEMU Images

Bazel definitions for the QEMU images used by the
[S-CORE ITF](https://github.com/eclipse-score/itf) integration test framework.
The definitions were ported from the ITF repository so that other repositories
can depend on them directly.

## Images

| Package | Base | Architecture |
| --- | --- | --- |
| `//ubuntu_x86_64` | Ubuntu 24.04 minimal cloud image | x86_64 |
| `//ebclfsa_aarch64` | EB corbos Linux for Safety Applications fastdev image built from the toolkit's packages | aarch64 |
| `//ebclfsa_aarch64_prebuild` | EB corbos Linux for Safety Applications fastdev image customized with shared Debian packages | aarch64 |

All images expose `:image` and `:qemu_config`:
The ebclfsa images additionally expose `:kernel` for the prebuilt image.

| Target | Content |
| --- | --- |
| `:image` | The customized disk image |
| `:kernel` | The kernel for the EBcLfSA images |
| `:qemu_config` | `qemu_config.json` describing how to run the image |

`//ebclfsa_aarch64_prebuild` additionally exposes `:vanilla-image`, the
unmodified base disk image.

The prebuilt EBcLfSA image preserves the release's root password and SSH
configuration. Its `:ssh_target_key` target downloads the matching public
development key from the toolkit release. Its generated `:qemu_config` sets
ITF's native `ssh_auth.pkey_path` to the key's runfiles path. Include the key
in the test's `data` alongside the image and configuration:

```starlark
args = [
    "--qemu-config=$(location //ebclfsa_aarch64_prebuild:qemu_config)",
    "--qemu-kernel=$(location //ebclfsa_aarch64_prebuild:kernel)",
    "--qemu-rootfs=$(location //ebclfsa_aarch64_prebuild:image)",
]
data = [
    "//ebclfsa_aarch64_prebuild:image",
    "//ebclfsa_aarch64_prebuild:kernel",
    "//ebclfsa_aarch64_prebuild:qemu_config",
    "//ebclfsa_aarch64_prebuild:ssh_target_key",
]
```

ITF 0.7.0 uses this configuration for both SSH and SFTP, including its pre-test
connection checks; no local ITF patches or SSH agent setup are required.

The Ubuntu image uses a build-generated Ed25519 key pair. Only the public key
is installed in root's `authorized_keys`; the root password is locked, and SSH
password and keyboard-interactive authentication are disabled. The private key
is exposed as `//ubuntu_x86_64:ssh_target_key` and referenced by the generated
`:qemu_config`. Include it in each test's `data`:

```starlark
args = [
    "--qemu-config=$(location //ubuntu_x86_64:qemu_config)",
    "--qemu-rootfs=$(location //ubuntu_x86_64:image)",
]
data = [
    "//ubuntu_x86_64:image",
    "//ubuntu_x86_64:qemu_config",
    "//ubuntu_x86_64:ssh_target_key",
]
```

The key pair and image are cached Bazel artifacts: keep the matching private key
with the image for testing. No private keys are committed to the repository.
`//ubuntu_x86_64:cloud_init` provides the rendered user-data and meta-data.

The source-built EBcLfSA image uses the toolkit's built-in development key
generation. Its `:ssh_target_key` exports the private key produced alongside the
image, and its generated `:qemu_config` references that key for ITF SSH and SFTP.
Include `//ebclfsa_aarch64:ssh_target_key` in test `data` alongside the image,
kernel and configuration. The root password is locked and SSH password
authentication is disabled. See its [README](ebclfsa_aarch64/README.md) for details.

The image targets are tagged `manual`, since building them boots QEMU and needs
the base images to be downloaded.

## Additional disk on /opt

Both images mount an additional disk automatically on `/opt`. The ITF QEMU
plugin attaches such a disk when it is passed via `--qemu-disk`; it always shows
up as the second virtio block device `/dev/vdb`. The `fstab` entry uses `nofail`,
so the images keep booting when no additional disk is attached.

`//tests:qemu_disk_image` builds an example ext4 disk with
[rules_imagefs](https://github.com/eclipse-score/rules_imagefs):

```starlark
py_itf_test(
    name = "my_test",
    args = [
        "--qemu-config=$(location //ubuntu_x86_64:qemu_config)",
        "--qemu-disk=$(location //tests:qemu_disk_image)",
        "--qemu-rootfs=$(location //ubuntu_x86_64:image)",
    ],
    ...
)
```

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
      qemu-system-x86 qemu-utils openssh-client
$ bazel build //ubuntu_x86_64:image
$ bazel build //ebclfsa_aarch64_prebuild:image
```

Building the images requires KVM or falls back to slow TCG emulation.

## Testing

Run the image boot and bidirectional ping tests with:

```console
$ bazel test --config=qemu-integration //tests/...
```

## Security note

The source-built EBcLfSA and Ubuntu images use build-generated development SSH
keys for root login with password authentication disabled.
The prebuilt EBcLfSA image uses the toolkit release's publicly available
development SSH key and retains its default root password. All these images
are meant for integration testing only and must never be used in production.
