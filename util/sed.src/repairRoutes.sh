#!/bin/bash
#
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
# Delete all routes in default routing table not using __DEV_EXT__
ip route | egrep '__DEV_INT__|__DEV_OVN__' | \
while read line
do
  ip route delete $line
done

# Add routingpolicies
# Beginnin with systemd 236 we can do it by a configuration.
# Alas, debian 9 has systemd 232, so we need to do it manually.
ip rule add from __IP_INT__ lookup __ROUTING_TABLE_INT__
ip rule add to  __NW_INT__ lookup __ROUTING_TABLE_INT__
