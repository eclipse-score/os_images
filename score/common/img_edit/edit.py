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

"""Copy a WIC image and apply tar archives to its largest ext4 partition."""

import hashlib
import os
import posixpath
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
from pathlib import PurePosixPath

SECTOR = 512
CHUNK = 1024 * 1024


def partition_ranges(image):
    """Read primary MBR or GPT partition extents, in bytes."""
    size = os.fstat(image.fileno()).st_size
    mbr = image.read(SECTOR)
    if len(mbr) != SECTOR or mbr[510:] != b"\x55\xaa":
        raise ValueError("image has no valid MBR")
    entries = [mbr[446 + i * 16 : 462 + i * 16] for i in range(4)]
    if any(entry[4] == 0xEE for entry in entries):
        image.seek(SECTOR)
        header = image.read(SECTOR)
        if len(header) != SECTOR or header[:8] != b"EFI PART":
            raise ValueError("image has no valid GPT header")
        table_lba, count, entry_size = struct.unpack_from("<QII", header, 72)
        if (
            entry_size < 128
            or entry_size > 4096
            or count > 16384
            or table_lba * SECTOR + count * entry_size > size
        ):
            raise ValueError("invalid GPT partition table")
        image.seek(table_lba * SECTOR)
        entries = [image.read(entry_size) for _ in range(count)]
        ranges = []
        for entry in entries:
            if entry[:16] != bytes(16):
                first, last = struct.unpack_from("<QQ", entry, 32)
                if last < first:
                    raise ValueError("invalid GPT partition extent")
                ranges.append((first * SECTOR, (last - first + 1) * SECTOR))
    else:
        ranges = [
            (start * SECTOR, count * SECTOR)
            for entry in entries
            if entry[4] and entry[4] not in (0x05, 0x0F, 0x85)
            for start, count in [struct.unpack_from("<II", entry, 8)]
        ]
    for offset, length in ranges:
        if offset < SECTOR or not length or offset + length > size:
            raise ValueError("invalid partition extent")
    return ranges


def root_partition(image):
    candidates = []
    for offset, length in partition_ranges(image):
        if length < 1024 + 58:
            continue
        image.seek(offset + 1024 + 56)
        if image.read(2) == b"\x53\xef":
            candidates.append((length, offset))
    if not candidates:
        raise ValueError("no ext4 partition found")
    length, offset = max(candidates)
    return offset, length


def copy_bytes(source, dest, length):
    while length:
        data = source.read(min(length, CHUNK))
        if not data:
            raise ValueError("unexpected end of image")
        dest.write(data)
        length -= len(data)


def file_hash(path):
    digest = hashlib.sha256()
    with open(path, "rb") as file:
        for data in iter(lambda: file.read(CHUNK), b""):
            digest.update(data)
    return digest.digest()


def quote(value):
    value = str(value)
    if any(c in value for c in ('"', "\\", "\n", "\r", "\0")):
        raise ValueError("unsupported character in debugfs path or symlink: %r" % value)
    return '"%s"' % value


def archive_path(name):
    parts = PurePosixPath(name).parts
    if ".." in parts:
        raise ValueError("unsafe archive path: %s" % name)
    return "/" + "/".join(part for part in parts if part not in ("/", "."))


class FileSystem:
    def __init__(self, path, work):
        self.path = path
        self.work = work
        self.debugfs = shutil.which("debugfs")
        if not self.debugfs:
            for candidate in ("/usr/sbin/debugfs", "/sbin/debugfs"):
                if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                    self.debugfs = candidate
                    break
        if not self.debugfs:
            raise RuntimeError("debugfs (e2fsprogs) is not installed")
        self.commands = []
        self.expected = {}
        self.file_number = 0
        self.known = {"/": ("directory", None)}

    def add(self, command):
        self.commands.append(command)

    def lookup(self, path):
        if path not in self.known:
            output = self.run(["stat " + quote(path)])[0].decode(errors="replace")
            found = re.search(r"Type:\s+(\S+).*?Size:\s+(\d+)", output, re.S)
            if not found:
                self.known[path] = (None, None)
            elif found.group(1) == "symlink":
                link = re.search(r'Fast link dest: "(.*)"', output)
                if link:
                    target = link.group(1)
                else:
                    dump = os.path.join(self.work, "existing-link")
                    if os.path.exists(dump):
                        os.unlink(dump)
                    self.run(["dump %s %s" % (quote(path), quote(dump))])
                    with open(dump, "rb") as file:
                        target = file.read().decode("utf-8")
                self.known[path] = ("symlink", target)
            else:
                self.known[path] = (found.group(1), None)
        return self.known[path]

    def directory(self, path):
        pending = list(PurePosixPath(path).parts[1:])
        resolved = "/"
        links = 0
        while pending:
            component = pending.pop(0)
            if component in ("", "."):
                continue
            if component == "..":
                resolved = posixpath.dirname(resolved)
                continue
            candidate = posixpath.join(resolved, component)
            kind, target = self.lookup(candidate)
            if kind == "symlink":
                links += 1
                if links > 40:
                    raise ValueError("too many symlinks resolving " + path)
                if target.startswith("/"):
                    resolved = "/"
                pending = target.split("/") + pending
            elif kind in ("directory", None):
                if kind is None:
                    self.add("mkdir " + quote(candidate))
                    self.known[candidate] = ("directory", None)
                resolved = candidate
            else:
                raise ValueError("not a directory: " + candidate)
        return resolved

    def apply_archive(self, archive):
        with tarfile.open(archive, "r:*") as tar:
            entries = sorted(
                tar, key=lambda member: archive_path(member.name).count("/")
            )
            for member in entries:
                source = None
                path = archive_path(member.name)
                if path == "/":
                    if not member.isdir():
                        raise ValueError("archive root is not a directory")
                    continue
                if not (member.isdir() or member.isfile() or member.issym()):
                    raise ValueError("unsupported archive entry: %s" % member.name)
                parent = self.directory(str(PurePosixPath(path).parent))
                path = posixpath.join(parent, PurePosixPath(path).name)
                if member.isdir():
                    existing = self.lookup(path)[0]
                    if existing == "symlink":
                        path = self.directory(path)
                    elif existing not in ("directory", None):
                        raise ValueError("not a directory: " + path)
                target = quote(path)
                if member.isdir():
                    self.add("mkdir " + target)
                    mode = 0o40000 | (member.mode & 0o7777)
                    kind = "directory"
                elif member.isfile():
                    self.file_number += 1
                    source = os.path.join(self.work, "file-%d" % self.file_number)
                    with tar.extractfile(member) as data, open(source, "wb") as out:
                        shutil.copyfileobj(data, out, CHUNK)
                    self.add("rm " + target)
                    self.add("write %s %s" % (quote(source), target))
                    mode = 0o100000 | (member.mode & 0o7777)
                    kind = "regular"
                else:
                    self.add("rm " + target)
                    self.add("symlink %s %s" % (target, quote(member.linkname)))
                    mode = None
                    kind = "symlink"
                if mode is not None:
                    self.add("sif %s mode 0%o" % (target, mode))
                self.add("sif %s uid %d" % (target, member.uid))
                self.add("sif %s gid %d" % (target, member.gid))
                self.known[path] = (kind, member.linkname if member.issym() else None)
                self.expected[path] = (
                    kind,
                    member.mode & 0o7777 if mode else None,
                    member.uid,
                    member.gid,
                    member.size if member.isfile() else None,
                    member.linkname if member.issym() else None,
                    source,
                )

    def run(self, commands, write=False):
        if not commands:
            return []
        script = os.path.join(self.work, "commands")
        with open(script, "w", encoding="utf-8") as out:
            out.write("\n".join(commands) + "\n")
        result = subprocess.run(
            [self.debugfs] + (["-w"] if write else []) + ["-f", script, self.path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=dict(
                os.environ, DEBUGFS_PAGER="__none__", PAGER="__none__", LC_ALL="C"
            ),
            check=False,
        )
        errors = [
            line
            for line in result.stderr.decode(errors="replace").splitlines()
            if line
            and not re.search(
                r"File not found by ext2_lookup|Ext2 (?:file|directory) already exists",
                line,
            )
            and not line.startswith("debugfs ")
        ]
        if result.returncode or errors:
            raise RuntimeError(
                "debugfs failed:\n"
                + "\n".join(errors or [result.stderr.decode(errors="replace")])
            )
        outputs = re.split(rb"^debugfs: .*\n", result.stdout, flags=re.MULTILINE)[1:]
        if len(outputs) != len(commands):
            raise RuntimeError("unexpected debugfs output")
        return outputs

    def verify(self):
        paths = sorted(self.expected)
        outputs = self.run(["stat " + quote(path) for path in paths])
        for path, output in zip(paths, outputs):
            text = output.decode(errors="replace")
            found = re.search(
                r"Type:\s+(\S+)\s+Mode:\s+(\d+).*?User:\s+(\d+)\s+Group:\s+(\d+).*?Size:\s+(\d+)",
                text,
                re.S,
            )
            if not found:
                raise RuntimeError("missing or unreadable image entry: " + path)
            kind, mode, uid, gid, size = found.groups()
            (
                expected_kind,
                expected_mode,
                expected_uid,
                expected_gid,
                expected_size,
                target,
                _,
            ) = self.expected[path]
            if (
                kind != expected_kind
                or (expected_mode is not None and int(mode, 8) != expected_mode)
                or int(uid) != expected_uid
                or int(gid) != expected_gid
                or (expected_size is not None and int(size) != expected_size)
            ):
                raise RuntimeError("incorrect image entry: " + path)
            if target is not None:
                link = re.search(r'Fast link dest: "(.*)"', text)
                if link is not None:
                    if link.group(1) != target:
                        raise RuntimeError("incorrect symlink target: " + path)
                elif int(size) != len(target.encode()):
                    raise RuntimeError("incorrect symlink size: " + path)
        dumps = []
        for index, path in enumerate(paths):
            kind, _, _, _, _, target, source = self.expected[path]
            if kind == "regular" or (target is not None and len(target.encode()) >= 60):
                dump = os.path.join(self.work, "dump-%d" % index)
                dumps.append((path, dump, source, target))
        self.run(
            ["dump %s %s" % (quote(path), quote(dump)) for path, dump, _, _ in dumps]
        )
        for path, dump, source, target in dumps:
            if source is not None:
                expected_hash = file_hash(source)
            else:
                expected_hash = hashlib.sha256(target.encode()).digest()
            if file_hash(dump) != expected_hash:
                raise RuntimeError("incorrect image contents: " + path)


def edit(image, output, archives):
    shutil.copyfile(image, output)
    if not archives:
        return
    with tempfile.TemporaryDirectory() as work:
        partition = os.path.join(work, "partition.ext4")
        with open(output, "r+b") as disk:
            offset, length = root_partition(disk)
            disk.seek(offset)
            with open(partition, "wb") as fs:
                copy_bytes(disk, fs, length)
            fs = FileSystem(partition, work)
            for archive in archives:
                fs.apply_archive(archive)
            fs.run(fs.commands, write=True)
            fs.verify()
            disk.seek(offset)
            with open(partition, "rb") as source:
                copy_bytes(source, disk, length)


def main():
    if len(sys.argv) < 3:
        sys.exit("Usage: edit.py <input.wic> <output.wic> [tar ...]")
    try:
        edit(sys.argv[1], sys.argv[2], sys.argv[3:])
    except (OSError, ValueError, RuntimeError, tarfile.TarError) as error:
        sys.exit("img_edit: %s" % error)


if __name__ == "__main__":
    main()
