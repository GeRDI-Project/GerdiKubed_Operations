#!/bin/bash
# Copyright 2018 Walentin Lamonos lamonos@lrz.de
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#       http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Note: VMware machines start out with the ifupdown package,
# our setup requires the systemd networking
IFS=$'\n'
# Get number of eth0-9 interfaces
NIC_ARRAY=$( \
	ip addr | grep -E 'eth[0-9]:' | awk '{print $2}')
unset $IFS
# Count results
COUNTER=0
while read -r NIC; do
  if [[ ! -z "$NIC" ]]; then
    COUNTER=$((COUNTER+1))
  fi
done <<< "$NIC_ARRAY"

echo "$COUNTER NICs detected & $# IPs passed to script"

# Check if provided amount of ips matches amount of NICs
if [ "$#" -ne $COUNTER ]; then
  echo "Illegal amount of IPs or NICs"
  exit 1
fi

# Iterate again, this time add the ips to the interfaces file
COUNTER=0
TEMP=1
while read -r NIC; do
  # Skip eth0; This is setup by default on VMware machines
  if [ "$COUNTER" -gt 0 ]; then
    # grep || makes sure that the interface is not already in
    grep -q -F 'auto eth'$COUNTER /etc/network/interfaces || 
    { \
       printf '\n'; \
       echo 'auto eth'$COUNTER; \
       echo 'iface eth'$COUNTER' inet static'; \
       echo '	address '${!TEMP}; \
       echo '	netmask 22'; \
    } >> /etc/network/interfaces 
  fi
  COUNTER=$((COUNTER+1))
  TEMP=$((TEMP+1))
done <<< "$NIC_ARRAY"

service networking restart
