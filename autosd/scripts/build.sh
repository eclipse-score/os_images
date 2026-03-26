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
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source ${SCRIPT_DIR}/vars.sh
source ${SCRIPT_DIR}/aib.sh

aib::build_builder ${AIB_DISTRO} ${AIB_OCI_IMAGE_BUILDER}
aib::build ${AIB_DISTRO} ${AIB_TARGET} image.aib.yml ${AIB_OCI_IMAGE} "--build-container ${AIB_OCI_IMAGE_BUILDER} --define-file vars.yml --define-file vars-devel.yml"
