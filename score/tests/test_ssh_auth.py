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

import paramiko


def test_root_login_with_empty_password(target, config):
    assert config.qemu_config.ssh_auth.pkey_path is None
    exit_code, output = target.execute("id -u")
    assert exit_code == 0
    assert output.strip() == b"0"

    exit_code, output = target.execute("/usr/sbin/sshd -T")
    assert exit_code == 0
    assert b"pubkeyauthentication yes" in output.splitlines()

    with paramiko.SSHClient() as client:
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(
            hostname=config.qemu_config.networks[0].ip_address,
            port=config.qemu_config.ssh_port,
            username="root",
            password="",
            allow_agent=False,
            look_for_keys=False,
            timeout=30,
        )
        _, stdout, stderr = client.exec_command("id -u")
        assert stdout.channel.recv_exit_status() == 0, stderr.read()
        assert stdout.read().strip() == b"0"
