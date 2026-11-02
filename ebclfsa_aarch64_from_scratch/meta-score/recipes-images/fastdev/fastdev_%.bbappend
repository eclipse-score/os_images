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

# Allow passwordless root login for integration testing, not for production use.
# Appended so it runs after image_postprocess_accounts, which sets the toolkit's
# default root password.
ROOTFS_POSTPROCESS_COMMAND:append = " score_passwordless_root score_opt_mount"

score_passwordless_root() {
    sudo sed -i 's/^root:[^:]*:/root::/' '${ROOTFSDIR}/etc/shadow'
}

score_opt_mount() {
    printf '\n# Additional disk attached by the ITF QEMU plugin\n/dev/vdb\t/opt\tauto\tdefaults,nofail\t0\t0\n' | \
        sudo tee -a '${ROOTFSDIR}/etc/fstab' >/dev/null
}
