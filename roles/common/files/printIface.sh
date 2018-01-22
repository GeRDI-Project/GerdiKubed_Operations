#!/bin/bash
# Copyright 2018 Tobias Weber weber@lrz.de
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
curNum=0
for iface in `ip a | grep -v ovs-system | grep 'state UP' | awk -F ':' '{ print $2 }'`
do
  let "curNum++"
  if [ "$curNum" -eq "$1" ]
  then
    ip=$(ip a | grep inet | grep $iface | awk '{ print $2 }' | awk -F '/' '{ print $1 }')
    gw=$(ip route | grep default | grep $iface | awk '{ print $3 }')
    if [ -z $gw ];
    then
      gw=10.155.215.254
    fi
    nw=$(ipcalc $(ip a | grep inet | grep $iface | awk '{ print $2 }' | tr '\n' ' ') | grep 'Network:' | awk '{ print $2 }')
    hw=$(ip link | grep -A1 $iface | grep link/ether | awk '{ print $2 }' )
    output="$iface $ip $gw $nw $hw"
    echo $output | tr '\n' ' '
    echo
    exit 0
  fi
done
exit 100
