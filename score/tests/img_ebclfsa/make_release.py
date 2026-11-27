#!/usr/bin/env python3
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

import os
import struct
import sys
import tarfile
import tempfile
import subprocess


def main(output):
    with tempfile.TemporaryDirectory() as work:
        partition = os.path.join(work, "partition")
        with open(partition, "wb") as file:
            file.truncate(16 * 1024 * 1024)
        subprocess.run(["/usr/sbin/mkfs.ext4", "-q", "-F", partition], check=True)

        wic = os.path.join(work, "image.wic")
        with open(wic, "wb") as disk:
            mbr = bytearray(512)
            mbr[450] = 0x83
            struct.pack_into("<II", mbr, 454, 2048, 32768)
            mbr[510:512] = b"\x55\xaa"
            disk.write(mbr)
            disk.seek(2048 * 512)
            with open(partition, "rb") as fs:
                while data := fs.read(1024 * 1024):
                    disk.write(data)

        kernel = os.path.join(work, "kernel")
        with open(kernel, "wb") as f:
            f.write(b"KERNEL_PLACEHOLDER")

        key = os.path.join(work, "ssh-key")
        with open(key, "wb") as f:
            f.write(b"ssh-rsa AAAAB3...example")

        archive = output
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(wic, arcname="score-release.wic")
            tar.add(kernel, arcname="score-release-vmlinux")
            tar.add(key, arcname="score-release-ssh-target-key")


if __name__ == "__main__":
    main(sys.argv[1])
