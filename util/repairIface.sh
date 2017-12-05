#!/bin/bash
ip=__IP__
set -f
IFS='
'


ip route delete default via 141.40.255.254 dev ens3
ip route delete 141.40.254.0/23 dev ens3

echo
grep -q rt2 /etc/iproute2/rt_tables || echo "1 rt2" >> /etc/iproute2/rt_tables

ip route add 141.40.254.0/23 dev ens3 src $ip table rt2
ip route add default via 141.40.255.254 dev ens3 src $ip table rt2
ip rule add from 141.40.254.0/23 table rt2
ip rule add to 141.40.254.0/23 table rt2
