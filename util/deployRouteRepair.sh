#!/bin/bash
#
# ABOUT:
# This script deploys a repair on a machine with two NICs attached to
# different networks (two default routes lead to an unoperational iface).
# One of the routes (called "internal") will be deleted from the default
# routing table and the routes will be configured in a dedicated routing
# table.
#
# ARGUMENTS:
# The first argument is the ip address over which ssh is possible since it
# is the first of two configured default routes ($IP_CONN).
# This argument is required.
#
# The second argument is an ip address which will only be used by OVN
#
# The third argument is the ip address which routes should be configured with
# a dedicated routing table ($internalAddress). Might be the same as the first
# argument. This argument is required.
#
# The following variables are hardcoded and must be changed in the script
# DEV_INT (default: ens5) This is used to grep out the rules remaining in the
#         default routing table.
# DEV_OVN (default: ens4) see DEV_INT
# GW_INT  (default: 10.155.215.254) Gateway of the internal network
# MASK_INT (default: 21) Network mask for internal network
# NW_INT  (default: 10.155.208.0/$MASK_INT) Internal network range
# ROUTING_TABLE_INT (default: 180485) Number of the dedicated routing table
#
# USAGE:
# repairRoute.sh must be in the same directory then run:
# ./deployRouteRepair.sh 141.40.254.131 10.155.208.4 10.155.208.71

################################################################################
# ARGUMENT HANDLING
################################################################################
[[ $# != 3 ]] && exit "Number of arguments given not correct!"
IP_CONN=$1
IP_OVN=$2
IP_INT=$3

DEV_OVN=ens4
DEV_INT=ens5
GW_INT=10.155.215.254
MASK_INT=21
NW_INT=10.155.208.0/$MASK_INT
ROUTING_TABLE_INT=180485

echo "Prepare scripts and configs for $IP_CONN"
mkdir -p deploy/$IP_CONN
for file in sed.src/*
do
  sed "
        s#__DEV_INT__#$DEV_INT#g
        s#__DEV_OVN__#$DEV_OVN#g
        s#__NW_INT__#$NW_INT#g;
        s#__GW_INT__#$GW_INT#g;
        s#__IP_INT__#$IP_INT#g;
        s#__IP_OVN__#$IP_OVN#g;
        s#__MASK_INT__#$MASK_INT#g;
        s#__ROUTING_TABLE_INT__#$ROUTING_TABLE_INT#g;
        " $file  > deploy/$IP_CONN/$(basename $file)
done;

echo "Install scripts and configs"
for file in deploy/$IP_CONN/*.network;
do
  scp $file root@$IP_CONN:/etc/systemd/network/
done
scp deploy/$IP_CONN/repairRoutes.sh \
  root@$IP_CONN:repairRoutes.sh
ssh root@$IP_CONN 'chmod +x /root/repairRoutes.sh'
scp deploy/$IP_CONN/repairRoutes.service \
  root@$IP_CONN:/etc/systemd/system/repairRoutes.service


echo "Remove old systemd network config"
ssh root@$IP_CONN 'rm /etc/systemd/network/wired.network'

echo "Install dependencies for repairRoute"
ssh root@$IP_CONN 'apt update 2>&1 > /dev/null'
ssh root@$IP_CONN 'apt install iproute2 -y 2>&1 > /dev/null'

echo "Install repairRoutes as systemd startup script"
ssh root@$IP_CONN 'systemctl enable repairRoutes.service'
ssh root@$IP_CONN 'systemctl daemon-reload'

echo "Configure sshd to listen only on internal addr"
ssh root@$IP_CONN "sed -i '
	      s/#ListenAddress.*/ListenAddress $IP_INT/
        s/#AddressFamily.*/AddressFamily inet/;
        ' /etc/ssh/sshd_config"

echo "Reboot"
ssh root@$IP_CONN 'reboot'
