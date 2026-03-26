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
AIB_BIN=${AIB_BIN:-/usr/bin/aib}
AIB_OCI_IMAGE=${AIB_OCI_IMAGE:-localhost/score:latest}
AIB_OCI_IMAGE_BUILDER=${AIB_OCI_IMAGE_BUILDER:-localhost/score-builder:latest}
AIB_DISTRO=${AIB_DISTRO:-autosd10-sig}
AIB_BUILD_DIR=${AIB_BUILD_DIR:-./_build}
AIB_MANIFEST=${AIB_MANIFEST:-image.aib.yml}
AIB_TARGET=${AIB_TARGET:-qemu}
