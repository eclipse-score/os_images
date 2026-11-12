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


def test_root_password_is_not_empty(target):
    exit_code, output = target.execute(
        """awk -F: '$1 == "root" {print length($2)}' /etc/shadow"""
    )
    assert exit_code == 0
    assert int(output.strip()) > 0, "The release's root password must not be cleared"


def test_passwordless_ssh_config_is_not_installed(target):
    exit_code, _ = target.execute(
        "test ! -e /etc/ssh/sshd_config.d/99-integration-test.conf"
    )
    assert exit_code == 0, "The passwordless SSH override must not be installed"

    exit_code, output = target.execute("/usr/sbin/sshd -T")
    assert exit_code == 0
    assert b"permitemptypasswords no" in output.splitlines()
