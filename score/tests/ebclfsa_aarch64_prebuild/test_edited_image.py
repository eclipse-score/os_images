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


def test_edited_payload_is_present_in_booted_image(target):
    path = "/usr/share/os-images-img-edit-test/edit_payload.txt"

    status, output = target.execute(f"cat {path}")
    assert status == 0, output
    assert output == b"Hello from the edited prebuilt image!\n"

    status, output = target.execute(f"stat -c '%a' {path}")
    assert status == 0, output
    assert output.strip() == b"644"
