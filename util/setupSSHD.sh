#!/bin/bash
#
# Copyright 2018 Walentin Lamonos lamonos@lrz.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ABOUT:
# This script makes sure that the sshd server is always listening to the
# last private interface in the list of returned interfaces from ip addr.
# Replace #ListenAddress 0.0.0.0 with output of last private ipv4 interface
# Also uncomment #AddressFamily -> AdressFamily inet
sed -i 's/#ListenAddress 0.0.0.0/ListenAddress '`ip addr | \
grep -e 'inet[[:space:]]' | grep -v '127.0.0.1' | grep -E 'ens[0-9]' | \
awk '{print $2}' | sed 's/\// /g' | \
awk '{print $1}' | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)' | tail -n 1`'/
s/#AddressFamily.*/AddressFamily inet/;' /etc/ssh/sshd_config
systemctl restart sshd
service sshd restart
