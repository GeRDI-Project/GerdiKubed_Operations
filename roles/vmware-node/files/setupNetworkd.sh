#!/bin/bash
# Copyright 2018 Walentin Lamonos lamonos@lrz.de
# Based on repairRoutes.sh by Tobias Weber weber@lrz.de
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
# 
# NOTE: This is a slighly different script that also makes sure networkd is setup
# Get all attached ips
# Make sure to only seperate by newline;
# Also get rid of loopback IP
# IPs are stored as IP_ARRAY[0] = IP[[:space:]]CIDR[[:space:]]BROADCAST[[:space:]]DEVICENAME
#      Example: 141.40.254.115 23 141.40.255.255 ens3
IFS=$'\n'
# Filter out ipv4 ips
# Remove loopback, filter by device ens0-9
# Get the fields we need, replace / with space
# Filter out dynamic
IP_ARRAY=$( \
ip addr | grep -e "inet[[:space:]]" | \
grep -v '127.0.0.1' | grep -E 'eth[0-9]' | \
awk '{print $2" "$4" "$7$8}' | sed 's/\// /g' | \
sed 's/dynamic//g')
unset $IFS

PUBLIC_IPS=()
PRIVATE_IPS=()
GATEWAYS=()

# Split into private and public IPs
# Also calculate gateways
while read -r IP; do
  # Get the gateway address (for LRZ it's broadcast - 1)
  GATEWAYS+=$(echo $IP | awk '{print $3}' | awk -F"." '{printf "%d.%d.%d.%d ", $1, $2, $3, $4 - 1}')
  # Check if IP matches the private IP patterns
  TMP=$(echo $IP | awk '{print $1}' | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)') # Taken from: https://unix.stackexchange.com/a/98930
  if [ -z "$TMP" ]; then
    # Public IP
    PUBLIC_IPS+=("$IP")
  else
    # Private IP
    PRIVATE_IPS+=("$IP")
  fi
done <<< "$IP_ARRAY"

# Check what state we are in
# Loadbalancer & Old Nodes: 1 Public, 2 Private (1 OVN, 1 SSH) -> Setup required
# Loadbalancer & Old Nodes after OVN setup: 1 Public, 1 Private (1 hijacked by OVN, 1 SSH) -> No Setup required
# New Nodes: 0 Public, 2 Private (1 OVN, 1 SSH) -> Setup required
# New Nodes after OVN setup: 0 Public, 1 Private (1 hijacked by OVN, 1 SSH) -> No Setup required
echo "${#PUBLIC_IPS[@]} Public & ${#PRIVATE_IPS[@]} Private IPs detected."

# Error states
if [ ${#PRIVATE_IPS[@]} -eq 0 ]; then
  >&2 echo "No private IPs assigned to node. All setups require private IPs!"
  exit 1
fi

# Cases: 1 Private & 1 Public OR 1 Private & 0 Public -> Assume we are already set up -> Exit script
if [[ ${#PRIVATE_IPS[@]} -eq 1 && ${#PUBLIC_IPS[@]} -eq 1 ]] || [[ ${#PRIVATE_IPS[@]} -eq 1 && ${#PUBLIC_IPS[@]} -eq 0 ]]; then
  echo "Nothing to do"
  exit 0
fi

# Taken from https://gist.github.com/kwilczynski/5d37e1cced7e76c7c9ccfdf875ba6c5b
# arg $1 = IP
cidr_to_netmask() {
  local value=$(( 0xffffffff ^ ((1 << (32 - $1)) - 1) ))
  echo "$(( (value >> 24) & 0xff )).$(( (value >> 16) & 0xff )).$(( (value >> 8) & 0xff )).$(( value & 0xff ))"
}

# Taken from https://stackoverflow.com/questions/15429420/given-the-ip-and-netmask-how-can-i-calculate-the-network-address-using-bash?answertab=active#tab-top
# arg $1 = IP; arg $2 = SUBNET_MASK
ip_to_netaddr() {
  IFS=. read -r i1 i2 i3 i4 <<< "$1"
  IFS=. read -r m1 m2 m3 m4 <<< "$2"
  echo "$(printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))")"
  unset $IFS
}

if [ ${#PRIVATE_IPS[@]} -eq 2 ]; then
  COUNTER=0
  for IP in "${PRIVATE_IPS[@]}" ; do
    # Two or more private interfaces; First is gonna be OVN; Second SSH
    PUBIP_COUNT=${#PUBLIC_IPS[@]}
    DEV_NAME=$(echo ${PRIVATE_IPS[$COUNTER]} | awk '{print $4}')
    IP_INTERNAL=$(echo ${PRIVATE_IPS[$COUNTER]} | awk '{print $1}')
    CIDR=$(echo ${PRIVATE_IPS[$COUNTER]} | awk '{print $2}')
    if [ $COUNTER -eq 1 ]; then
      # Setup OVN interface
      { \
        echo '[Match]'; \
        echo 'Name='$DEV_NAME; \
        echo ''; \
        echo '[Network]'; \
        echo 'DHCP=no'; \
        echo ''; \
        echo '[Address]'; \
        echo 'Address='$IP_INTERNAL'/'$CIDR; \
      } > /etc/systemd/network/$DEV_NAME.network
      echo "Writting "$DEV_NAME".network"
    elif [ $COUNTER -eq 0 ]; then
      # Internal interface
      SUBNET_MASK=$(cidr_to_netmask $(echo ${PRIVATE_IPS[$COUNTER]} | awk '{print $2;}'))
      NETWORK_ADDRESS=$(ip_to_netaddr $(echo ${PRIVATE_IPS[$COUNTER]} | awk '{print $1;}') $(echo $SUBNET_MASK))
      CURRENT_GATEWAY=$(echo "$GATEWAYS" | awk -v pos="$(($PUBIP_COUNT+2))" '{print $pos}')
      # Setup private interface
      { \
        echo '[Match]'; \
        echo 'Name='$DEV_NAME; \
        echo ''; \
        echo '[Network]'; \
        echo 'DHCP=no'; \
        echo 'DNS=129.187.5.1'; \
        echo 'Address='$IP_INTERNAL'/'$CIDR; \
        echo 'Gateway='$CURRENT_GATEWAY; \
	echo 'IPForward=kernel'; \
      } > /etc/systemd/network/$DEV_NAME.network
      echo "Writting "$DEV_NAME".network"
    fi
    COUNTER=$((COUNTER+1))
  done
else
  >&2 echo "Too many private interfaces. I have no idea what to do!"
  exit 1;
fi

# We always use the first private ip for OVN and the second for internal
IP_INT=$(echo ${PRIVATE_IPS[0]} | awk '{print $1}')

rm /etc/resolv.conf
apt-get purge -y resolvconf

# Start systemd networking
systemctl enable --now systemd-networkd.service
systemctl enable --now systemd-resolved.service

# Setup systemd DNS
sed -i 's/#DNS=/DNS=129.187.5.1/;' /etc/systemd/resolved.conf

systemctl disable networking.service

ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

systemctl restart systemd-resolved.service

rm -f /etc/systemd/network/wired.network
systemctl daemon-reload

sed -i 's/#ListenAddress 0.0.0.0/ListenAddress '$IP_INT'/
  s/#AddressFamily.*/AddressFamily inet/;' /etc/ssh/sshd_config
