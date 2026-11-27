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

"""Extract WIC image, kernel, and optional SSH key from EBcLfSA release archive."""

def _img_ebclfsa_extract_impl(ctx):
    out_dir = ctx.actions.declare_directory(ctx.label.name)

    args = ctx.actions.args()
    args.add(ctx.file.archive)
    args.add(out_dir.path)
    if ctx.attr.without_key:
        args.add("--without-key")

    ctx.actions.run(
        executable = ctx.executable._tool,
        arguments = [args],
        inputs = [ctx.file.archive],
        outputs = [out_dir],
        mnemonic = "ImageExtract",
        progress_message = "Extracting EBcLfSA archive %{output}",
    )

    wic = ctx.actions.declare_file(ctx.label.name + ".wic")
    ctx.actions.run_shell(
        inputs = [out_dir],
        outputs = [wic],
        command = 'cp "$1/vanilla.wic" "$2"',
        arguments = [out_dir.path, wic.path],
        mnemonic = "ExtractWIC",
    )

    kernel = ctx.actions.declare_file(ctx.label.name + "-vmlinux")
    ctx.actions.run_shell(
        inputs = [out_dir],
        outputs = [kernel],
        command = 'cp "$1/vanilla-vmlinux" "$2"',
        arguments = [out_dir.path, kernel.path],
        mnemonic = "ExtractKernel",
    )

    all_files = [wic, kernel]
    output_groups = {
        "wic": depset([wic]),
        "kernel": depset([kernel]),
    }

    if not ctx.attr.without_key:
        key = ctx.actions.declare_file(ctx.label.name + "-ssh-key")
        ctx.actions.run_shell(
            inputs = [out_dir],
            outputs = [key],
            command = 'cp "$1/ssh_target_key" "$2"',
            arguments = [out_dir.path, key.path],
            mnemonic = "ExtractKey",
        )
        all_files.append(key)
        output_groups["key"] = depset([key])

    return [
        DefaultInfo(files = depset(all_files)),
        OutputGroupInfo(**output_groups),
    ]

_img_ebclfsa_extract_rule = rule(
    implementation = _img_ebclfsa_extract_impl,
    attrs = {
        "archive": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "EBcLfSA release archive containing .wic, -vmlinux, and optionally -ssh-target-key",
        ),
        "without_key": attr.bool(
            default = False,
            doc = "Set to True when using an explicit SSH key override",
        ),
        "_tool": attr.label(
            default = Label("//score/common/img_ebclfsa:extract"),
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Extracts WIC image, kernel, and SSH key from an EBcLfSA release archive.",
)

def img_ebclfsa_extract(name, archive, without_key = False, prefix = None):
    """Extract WIC image, kernel, and SSH key from an EBcLfSA release archive.

    Creates the extraction rule and filegroup wrappers for individual outputs.

    Args:
        name: Name of the extraction rule.
        archive: EBcLfSA release archive containing .wic, -vmlinux, and optionally -ssh-target-key.
        without_key: Set to True when using an explicit SSH key override.
        prefix: Optional prefix for output target names. If provided, creates targets like
                `prefix.wic`, `prefix-vmlinux`, and `prefix-ssh-key`. If None, uses `name`.
    """
    _img_ebclfsa_extract_rule(
        name = name,
        archive = archive,
        without_key = without_key,
    )

    if prefix == None:
        prefix = name

    native.filegroup(
        name = prefix + ".wic",
        srcs = [name],
        output_group = "wic",
    )

    native.filegroup(
        name = prefix + "-vmlinux",
        srcs = [name],
        output_group = "kernel",
    )

    if not without_key:
        native.filegroup(
            name = prefix + "-ssh-key",
            srcs = [name],
            output_group = "key",
        )
