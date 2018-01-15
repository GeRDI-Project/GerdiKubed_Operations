#!/bin/bash
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
