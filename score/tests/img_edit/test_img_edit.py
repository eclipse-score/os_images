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

import io
import os
from pathlib import Path
import struct
import subprocess
import sys
import tarfile
import tempfile
import unittest

BASE, EDITED, UNCHANGED, EDITOR = [Path(p).resolve() for p in sys.argv[1:]]
sys.argv = sys.argv[:1]
OFFSET = 2048 * 512
LENGTH = 16 * 1024 * 1024


class ImageEditTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ.get("TEST_TMPDIR"))
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def debugfs(self, image, command):
        partition = self.root / "partition"
        with image.open("rb") as disk, partition.open("wb") as out:
            disk.seek(OFFSET)
            out.write(disk.read(LENGTH))
        return subprocess.run(
            ["/usr/sbin/debugfs", "-R", command, str(partition)],
            capture_output=True,
            check=True,
        )

    def test_bazel_rule_copies_and_layers_pkg_tar_outputs(self):
        base = BASE.read_bytes()
        edited = EDITED.read_bytes()
        self.assertEqual(UNCHANGED.read_bytes(), base)
        self.assertEqual(edited[:OFFSET], base[:OFFSET])
        self.assertEqual(edited[OFFSET + LENGTH :], base[OFFSET + LENGTH :])
        self.assertEqual(
            self.debugfs(EDITED, "cat /opt/app/config").stdout, b"second content\n"
        )
        self.assertEqual(self.debugfs(EDITED, "cat /etc/shadow").stdout, b"root::1:2\n")
        self.assertNotIn(
            b"second content", self.debugfs(BASE, "cat /opt/app/config").stdout
        )

    def test_symlink_metadata_spaces_and_invalid_archive(self):
        archive = self.root / "payload.tar"
        with tarfile.open(archive, "w") as tar:
            file = tarfile.TarInfo("space dir/value")
            file.mode, file.uid, file.gid = 0o640, 12, 34
            file.size = 7
            tar.addfile(file, io.BytesIO(b"payload"))
            link = tarfile.TarInfo("space dir/link")
            link.type = tarfile.SYMTYPE
            link.linkname = "value"
            tar.addfile(link)
            long_link = tarfile.TarInfo("space dir/long link")
            long_link.type = tarfile.SYMTYPE
            long_link.linkname = "a" * 100
            tar.addfile(long_link)
            existing_alias = tarfile.TarInfo("alias/from-existing")
            existing_alias.size = 3
            tar.addfile(existing_alias, io.BytesIO(b"old"))
            new_link = tarfile.TarInfo("newlink")
            new_link.type = tarfile.SYMTYPE
            new_link.linkname = "real"
            tar.addfile(new_link)
            new_alias = tarfile.TarInfo("newlink/from-new")
            new_alias.size = 3
            tar.addfile(new_alias, io.BytesIO(b"new"))
        output = self.root / "output.wic"
        result = subprocess.run(
            [sys.executable, str(EDITOR), str(BASE), str(output), str(archive)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        stat = self.debugfs(output, 'stat "/space dir/value"').stdout
        self.assertIn(b"Mode:  0640", stat)
        self.assertRegex(stat, rb"User:\s+12\s+Group:\s+34")
        self.assertEqual(
            self.debugfs(output, 'cat "/space dir/value"').stdout, b"payload"
        )
        self.assertIn(
            b'Fast link dest: "value"',
            self.debugfs(output, 'stat "/space dir/link"').stdout,
        )
        self.assertIn(
            b"Size: 100", self.debugfs(output, 'stat "/space dir/long link"').stdout
        )
        self.assertEqual(self.debugfs(output, "cat /real/from-existing").stdout, b"old")
        self.assertEqual(self.debugfs(output, "cat /real/from-new").stdout, b"new")
        self.assertIn(
            b'Fast link dest: "/real"', self.debugfs(output, "stat /alias").stdout
        )

        with tarfile.open(archive, "w") as tar:
            entry = tarfile.TarInfo("../outside")
            tar.addfile(entry, io.BytesIO())
        result = subprocess.run(
            [sys.executable, str(EDITOR), str(BASE), str(output), str(archive)],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsafe archive path", result.stderr)

    def test_gpt_partition_and_missing_filesystem(self):
        image = self.root / "gpt.wic"
        data = bytearray(BASE.read_bytes())
        data[450] = 0xEE
        header = bytearray(512)
        header[:8] = b"EFI PART"
        struct.pack_into("<QII", header, 72, 2, 2, 128)
        data[512:1024] = header
        entry = bytearray(128)
        entry[:16] = bytes([1]) * 16
        struct.pack_into("<QQ", entry, 32, 2048, 2048 + 32768 - 1)
        data[1024:1152] = entry
        struct.pack_into("<QQ", entry, 32, 34, 34)
        data[1152:1280] = entry
        image.write_bytes(data)
        archive = self.root / "empty.tar"
        with tarfile.open(archive, "w") as tar:
            entry = tarfile.TarInfo("gpt-file")
            entry.size = 3
            tar.addfile(entry, io.BytesIO(b"gpt"))
        output = self.root / "result.wic"
        command = [sys.executable, str(EDITOR), str(image), str(output), str(archive)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(image.read_bytes()[:OFFSET], output.read_bytes()[:OFFSET])
        self.assertEqual(self.debugfs(output, "cat /gpt-file").stdout, b"gpt")
        data[OFFSET + 1024 + 56 : OFFSET + 1024 + 58] = b"\0\0"
        image.write_bytes(data)
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no ext4 partition", result.stderr)

    def test_insufficient_space_fails_without_changing_base(self):
        archive = self.root / "large.tar"
        with tarfile.open(archive, "w") as tar:
            data = b"x" * (LENGTH + 1024 * 1024)
            entry = tarfile.TarInfo("too-large")
            entry.size = len(data)
            tar.addfile(entry, io.BytesIO(data))
        before = BASE.read_bytes()
        result = subprocess.run(
            [
                sys.executable,
                str(EDITOR),
                str(BASE),
                str(self.root / "out.wic"),
                str(archive),
            ],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("img_edit:", result.stderr)
        self.assertEqual(BASE.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
