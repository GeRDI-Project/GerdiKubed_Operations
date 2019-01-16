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
for link in `ip link | egrep '^[0-9]+:' | awk '{ print $2 }' | tr -d ':' | sort -V`
do
  echo $link | egrep -q '^lo|^docker0|^k8s-' && continue
  ipv4WithMask=$(ip a list dev $link | egrep 'inet ' | awk '{ print $2 }' | tr -d '\n')
  [[ -z "$ipv4WithMask" ]] && continue
  let "curNum++"
  [ "$curNum" -ne "$1" ] && continue
  ipv4=$(echo $ipv4WithMask | awk -F '/' '{ print $1 }')
  gw=$(ipcalc $(ip a | grep inet | grep $link | awk '{ print $2 }' | tr '\n' ' ') | grep 'HostMax:' | awk '{ print $2 }')
  nw=$(ipcalc $(ip a | grep inet | grep $link | awk '{ print $2 }' | tr '\n' ' ') | grep 'Network:' | awk '{ print $2 }')
  mask=$(echo $ipv4WithMask | awk -F '/' '{ print $2 }')
  output="$link $ipv4 $gw $nw $mask"
  echo $output | tr -d '\n'
  echo
  exit 0
done
exit 1
