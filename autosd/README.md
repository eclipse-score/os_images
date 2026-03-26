AutoSD Image
============

## Background and Basic Info

This AtuoSD image can be built using [Automotive-Image-Builder](https://gitlab.com/CentOS/automotive/src/automotive-image-builder).
The image uses [Eclipse Bluechi](https://bluechi.readthedocs.io/en/latest/) and [QM](https://qm.readthedocs.io/en/latest/) to bring its MCO architecture. 

This is a base image which can be used as a starting point / base state to deploy specific Eclipse S-CORE releases.

## Building Instructions

This section will describe how build a QEMU image, note that `aib` does not support cross architecture building,
so the targeted architecture needs to be same as the host machine.

A linux system is required to build this image but Ubuntu
and an OCI compliant container manager (docker, podman) should be enough.

Download the builder script:

```
$ curl -o auto-image-builder.sh \
  "https://gitlab.com/CentOS/automotive/src/automotive-image-builder/-/raw/main/auto-image-builder.sh"
$ chmod +x automotive-image-builder
```

To build a qemu image by running:

```
$ export AIB_BIN=./auto--image-builder.sh
$ sudo -E ./scripts/build.sh
$ sudo -E ./scripts/save.sh
```

The resulting image will be stored in `_build/outputs/disk.qcow2`.

Change the image perms (if needed) since `sudo` was used:

```
sudo chown $(logname) _build/disk.qcow2
```

## Running (QEMU)

```
/usr/bin/qemu-system-x86_64 \
-drive file=/usr/share/OVMF/OVMF_CODE_4M.fd,if=pflash,format=raw,unit=0,readonly=on \
-drive file=/usr/share/OVMF/OVMF_VARS_4M.fd,if=pflash,format=raw,unit=1,snapshot=on,readonly=off \
-enable-kvm \
-m 5G \
-smp $(nproc) \
-machine q35 \
-cpu host \
-device virtio-net-pci,netdev=n0 \
-netdev user,id=n0,hostfwd=tcp::2222-:22 \
-display none \
-drive file=_build/disk.qcow2,index=0,media=disk,format=qcow2,if=virtio,id=rootdisk,snapshot=off
```

