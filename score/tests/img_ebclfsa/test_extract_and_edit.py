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

import sys
import subprocess
import unittest
from pathlib import Path

sys.argv = sys.argv[:1]

# Find files in runfiles directory
RUNFILES = Path(__file__).parent.resolve()

WIC = RUNFILES / "extracted.wic"
KERNEL = RUNFILES / "extracted-vmlinux"
KEY = RUNFILES / "extracted-ssh-key"
EDITED = RUNFILES / "edited.wic"

OFFSET = 2048 * 512
LENGTH = 16 * 1024 * 1024


class ExtractAndEditTest(unittest.TestCase):
    def debugfs(self, image, command):
        import tempfile

        partition = Path(tempfile.mktemp())
        try:
            with image.open("rb") as disk, partition.open("wb") as out:
                disk.seek(OFFSET)
                out.write(disk.read(LENGTH))
            return subprocess.run(
                ["/usr/sbin/debugfs", "-R", command, str(partition)],
                capture_output=True,
                check=True,
            )
        finally:
            partition.unlink(missing_ok=True)

    def test_extract_produces_wic_kernel_and_key(self):
        self.assertTrue(WIC.exists(), f"WIC not found: {WIC}")
        self.assertTrue(KERNEL.exists(), f"Kernel not found: {KERNEL}")
        self.assertTrue(KEY.exists(), f"SSH key not found: {KEY}")

        self.assertGreater(WIC.stat().st_size, 1024, "WIC is too small")
        self.assertEqual(KERNEL.read_bytes(), b"KERNEL_PLACEHOLDER")
        self.assertIn(b"ssh-rsa", KEY.read_bytes())

    def test_edited_image_contains_payload(self):
        self.assertTrue(EDITED.exists(), f"Edited image not found: {EDITED}")
        result = self.debugfs(EDITED, "cat /opt/testfile.txt")
        self.assertEqual(result.stdout, b"test file\n")

    def test_edited_preserves_partition_table(self):
        with WIC.open("rb") as orig, EDITED.open("rb") as edited:
            self.assertEqual(orig.read(OFFSET), edited.read(OFFSET))


if __name__ == "__main__":
    unittest.main()
