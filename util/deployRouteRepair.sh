#!/bin/bash
#
# ABOUT:
# This script deploys a repair on a machine with two default routes (which
# leads to the state that one interface is not operational). One of the routes
# (called "internal") will be deleted from the default routing table and
# configured with a dedicated routing table which applies to the internal
# network.
#
# ARGUMENTS:
# The first argument is the ip address over which ssh is possible since it
# is the first of two configured default routes ($addressToRepairWith).
# This argument is required.
#
# The second argument is the ip address which routes should be configured with
# a dedicated routing table ($internalAddress). Might be the same as the first
# argument. This argument is required.
#
# The third, fourth and fith argument are the gateway, network and interface
# ($gw, $nw, $if) used for the internal connection.
# Arguments three to five are optional, these are the default values:
# gw=10.155.215.255
# nw=10.155.208.0/21
# if=ens4
#
# DETAILS:
# This script does the following:
# * Connect via ssh with addressToRepairWith to the machine.
# * Installs a script repairRoute.sh which
#   ** deletes the routes of $internalAddress from the default routing table
#   ** installs an additional routing table
#   ** adds the aforedeleted routing information to that table
# * Replaces the strings __IP__, __GW__, __NW__ and __IF__ with the values of
#   $internalAddress, $gw, $nw and $if
# * Installs iproute2 package to have the utilities needed by repairRoute.sh.
# * Registers the script to systemd, since the changes will be flushed on reboot.
# * Reboots the machine. If the machine is up again the repair should have
#   taken place.
# Check with
#   ip route && ip route table rt2
#
# USAGE:
# repairRoute.sh must be in the same directory then run:
# ./deployRouteRepair.sh 141.40.254.131 10.155.208.23

################################################################################
# ARGUMENT HANDLING
################################################################################
[[ $# < 2 ]] && exit "Number of arguments given not correct!"
addressToRepairWith=$1
internalAddress=$2
[ ! -z $3 ] && gw=$3
[ -z $3 ] && gw=10.155.215.254
[ ! -z $4 ] && nw=$4
[ -z $4 ] && nw="10.155.208.0/21"
[ ! -z $5 ] && if=$5
[ -z $5 ] && if="ens4"

echo -n "Connecting via $addressToRepairWith to repair route for"
echo " $if ($internalAddress) with gw $gw and nw $nw"

echo "Install repairRoute script"
scp repairRoute.sh root@$addressToRepairWith:repairRoute.sh
echo "sed values $internalAddress $gw $nw and $if to repairRoute"
ssh root@$addressToRepairWith "sed -i 's#__IP__#$internalAddress#g;
                      s#__GW__#$gw#g;
                      s#__NW__#$nw#g;
                      s#__IF__#$if#g' /root/repairRoute.sh"

echo "Install dependencies for repairRoute"
ssh root@$addressToRepairWith 'apt update 2>&1 > /dev/null'
ssh root@$addressToRepairWith 'apt install iproute2 -y 2>&1 > /dev/null'

echo "Run repaireRoute"
ssh -f root@$addressToRepairWith 'nohup bash -c "sleep 10; /root/repairRoute.sh 2>&1 > /root/repairRoute.log" &'
