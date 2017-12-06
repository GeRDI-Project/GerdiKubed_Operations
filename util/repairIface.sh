#!/bin/bash
ip=__IP__
gw=__GW__
nw=__NW__
if=__IF__
table="rt2"

# Delete entries from systemd
ip route | grep $gw | grep -q default \
  && ip route delete default via $gw dev $if \
  || echo "deleted default route in standard table"
ip route | grep $nw \
  && ip route delete $nw dev $if \
  || echo "deleted route 1 in standard table"

# Make sure table $table exists
grep -q $table /etc/iproute2/rt_tables \
  || echo "1 $table" >> /etc/iproute2/rt_tables \
  || echo "added table $table to rt_tables"

# Add routes and rules to table $table
ip route show table $table | grep -q $nw \
  || ip route add $nw dev $if src $ip table $table

ip route show table $table | grep -q default \
  || ip route add default via $gw dev $if src $ip table $table

ip rule show table $table | grep from | grep -q $nw \
  || ip rule add from $nw table $table

ip rule show table $table | grep to | grep -q $nw \
  || ip rule add to $nw table $table

