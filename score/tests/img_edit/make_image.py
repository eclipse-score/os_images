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
import subprocess
import sys
import tempfile


def main(output):
    with tempfile.TemporaryDirectory() as work:
        partition = os.path.join(work, "partition")
        with open(partition, "wb") as file:
            file.truncate(16 * 1024 * 1024)
        subprocess.run(["/usr/sbin/mkfs.ext4", "-q", "-F", partition], check=True)
        shadow = os.path.join(work, "shadow")
        with open(shadow, "wb") as file:
            file.write(b"root::1:2\n")
        subprocess.run(
            ["/usr/sbin/debugfs", "-w", "-R", "mkdir /etc", partition],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            ["/usr/sbin/debugfs", "-w", "-R", f"write {shadow} /etc/shadow", partition],
            check=True,
            capture_output=True,
        )
        for command in ("mkdir /real", "symlink /alias /real"):
            subprocess.run(
                ["/usr/sbin/debugfs", "-w", "-R", command, partition],
                check=True,
                capture_output=True,
            )
        mbr = bytearray(512)
        mbr[450] = 0x83
        struct.pack_into("<II", mbr, 454, 2048, 32768)
        mbr[510:512] = b"\x55\xaa"
        with open(output, "wb") as disk, open(partition, "rb") as fs:
            disk.write(mbr)
            disk.seek(2048 * 512)
            while data := fs.read(1024 * 1024):
                disk.write(data)
            disk.write(b"unchanged-trailer")


if __name__ == "__main__":
    main(sys.argv[1])
