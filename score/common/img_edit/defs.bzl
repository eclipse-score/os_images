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

"""Add tar archives to the ext4 partition of a WIC image."""

def _img_edit_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".wic")
    args = ctx.actions.args()

    image_files = [f for f in ctx.files.image if f.path.endswith(".wic")]
    if len(image_files) != 1:
        fail("Expected exactly one .wic file, got %d" % len(image_files))
    image_file = image_files[0]

    args.add(image_file)
    args.add(out)
    args.add_all(ctx.files.srcs)
    ctx.actions.run(
        executable = ctx.executable._tool,
        arguments = [args],
        inputs = [image_file] + ctx.files.srcs,
        outputs = [out],
        mnemonic = "ImageEdit",
        progress_message = "Editing WIC image %{output}",
    )
    return [DefaultInfo(files = depset([out]))]

img_edit = rule(
    implementation = _img_edit_impl,
    attrs = {
        "image": attr.label(
            mandatory = True,
            allow_files = [".wic"],
            doc = "Base WIC image, which is not modified.",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Tar archives applied in order to the largest ext4 partition.",
        ),
        "_tool": attr.label(
            default = Label("//score/common/img_edit:edit"),
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Copies a WIC image and adds the contents of tar archives to its ext4 filesystem.",
)
