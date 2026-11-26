# WIC image editing

`img_edit` copies a WIC image and adds tar archives, such as `pkg_tar` outputs,
to its largest ext4 partition. It does not mount the image or modify the input.
Archives are applied in order; later files replace earlier files. Regular
files, directories, and symbolic links are supported, including numeric owners
and file and directory modes. Other tar entry types are rejected.

```starlark
load("@score_os_images//score/common/img_edit:defs.bzl", "img_edit")

img_edit(
    name = "custom_image",
    image = ":base.wic",
    srcs = [":first_tar", ":second_tar"],
)
```

The output is `custom_image.wic`. With no sources, it is an unchanged copy.
Images must use a primary MBR or GPT partition table with 512-byte sectors.
The host executing the action needs `debugfs` from e2fsprogs.
The filesystem must have enough free space for the added files; it is not
resized. Paths and symlink targets containing double quotes, backslashes,
newlines, or NUL characters are not supported by the debugfs command interface.
No image contents other than the selected filesystem are intentionally changed.
