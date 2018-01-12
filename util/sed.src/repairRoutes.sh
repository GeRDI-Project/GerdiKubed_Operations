#!/bin/bash
# Delete all routes in default routing table not using __DEV_EXT__
ip route | grep -v __DEV_EXT__ | \
while read line
do
  ip route delete $line
done

# Add routingpolicies
ip rule add from __IP_INT__ lookup __ROUTING_TABLE_INT__
ip rule add to  __NW_INT__ lookup __ROUTING_TABLE_INT__
