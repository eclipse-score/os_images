# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
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
#!/bin/bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source ${SCRIPT_DIR}/vars.sh
source ${SCRIPT_DIR}/aib.sh

if [ "${AIB_TARGET}" = "qemu" ]; then
  DISK_IMG_EXT="qcow2"
else
  DISK_IMG_EXT="img"
fi

mkdir -p ${AIB_BUILD_DIR}/outputs


aib::oci_to_disk_image ${AIB_OCI_IMAGE_BUILDER} ${AIB_OCI_IMAGE} ${AIB_BUILD_DIR}/outputs/score-autosd-${AIB_TARGET}-$(arch)-latest.${DISK_IMG_EXT}

sudo chown -R $(id -u):$(id -u) ${AIB_BUILD_DIR}

aib::oci_export ${AIB_BUILD_DIR} ${AIB_OCI_IMAGE} score-autosd-${AIB_TARGET}-$(arch)-latest.tar
aib::oci_export ${AIB_BUILD_DIR} ${AIB_OCI_IMAGE_BUILDER} score-autosd-builder-${AIB_TARGET}-$(arch)-latest.tar
