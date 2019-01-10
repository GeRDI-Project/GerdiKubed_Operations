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
# NOTE: OpenNebula !specific! script that handles the setup of systemd-networkd and systemd-resolved
# Get all attached ips
# Make sure to only seperate by newline;
# Also get rid of loopback IP
# IPs are stored as IP_ARRAY[0] = IP[[:space:]]CIDR[[:space:]]BROADCAST[[:space:]]DEVICENAME
#      Example: 141.40.254.115 23 141.40.255.255 ens3
# Delete previous default OpenNebula setup (happens on multi NIC machines)
rm /etc/systemd/network/wired.network > /dev/null 2>&1 

# Test if we are already set up
DIRECTORYTEST=$(find /etc/systemd/network -name "*.network" | wc -l)

if [ "$DIRECTORYTEST" -ge "1" ]; then
  echo "Networkd already setup. Nothing to do here."
  exit 0;
fi

IFS=$'\n'
# Filter out ipv4 ips
# Remove loopback, filter by device ens0-9
# Get the fields we need, replace / with space
# Filter out dynamic
IP_ARRAY=$( \
ip addr | grep -e "inet[[:space:]]" | \
grep -v '127.0.0.1' | grep -E 'ens[0-9]' | \
awk '{print $2" "$4" "$7$8}' | sed 's/\// /g' | \
sed 's/dynamic//g')
unset $IFS

ROUTING_TABLE_INT=$1
NFS_SERVER_DOMAIN=$2

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
# Loadbalancers: 1 Public & 1 Private -> Setup required
# Nodes: 0 Public & 1 Private interface -> Setup required
echo "${#PUBLIC_IPS[@]} Public & ${#PRIVATE_IPS[@]} Private IPs detected."

# Error states
if [ ${#PRIVATE_IPS[@]} -eq 0 ]; then
  >&2 echo "No private IPs assigned to node. All setups require private IPs!"
  exit 1
fi

EXIST=`ip rule show $NFS_SERVER_DOMAIN | wc -l`
if [ ${#PUBLIC_IPS[@]} -eq 1 ] && [ $EXIST -eq 0 ]; then
  ip rule add to $NFS_SERVER_DOMAIN table $ROUTING_TABLE_INT
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

# Does this machine have a public interface?
if [ ${#PUBLIC_IPS[@]} -eq 1 ]; then
  # Yes, setup route repair
  PRIVATEIP_COUNT=${#PRIVATE_IPS[@]}
  DEV_NAME=$(echo ${PUBLIC_IPS[0]} | awk '{print $4}')
  IP_INTERNAL=$(echo ${PUBLIC_IPS[0]} | awk '{print $1}')
  CIDR=$(echo ${PUBLIC_IPS[0]} | awk '{print $2}')
  CURRENT_GATEWAY=$(echo "$GATEWAYS" | awk -v pos=$(($PRIVATEIP_COUNT+1)) '{print $pos}')
  SUBNET_MASK=$(cidr_to_netmask $(echo ${PUBLIC_IPS[0]} | awk '{print $2;}'))
  NETWORK_ADDRESS=$(ip_to_netaddr $(echo ${PUBLIC_IPS[0]} | awk '{print $1;}') $(echo $SUBNET_MASK))
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
  } > /etc/systemd/network/1-$DEV_NAME.network
  echo "Writting 1-"$DEV_NAME".network"
  # Setup repairRoutes.sh
  DEV_OVN=$(echo ${PRIVATE_IPS[1]} | awk '{print $4}')
  DEV_INT=$(echo ${PRIVATE_IPS[0]} | awk '{print $4}')
  IP_INT=$(echo ${PRIVATE_IPS[0]} | awk '{print $1}')
  CIDR=$(echo ${PRIVATE_IPS[0]} | awk '{print $2}')
  SUBNET_MASK=$(cidr_to_netmask $(echo ${PRIVATE_IPS[0]} | awk '{print $2;}'))
  NETWORK_ADDRESS=$(ip_to_netaddr $(echo ${PRIVATE_IPS[0]} | awk '{print $1;}') $(echo $SUBNET_MASK))
  # Write repairRoutes.sh
  # Taken from Gerdi GIT (gerdikubed/util/sed.src/repairRoutes.sh)
  { \
    echo '#!/bin/bash'; \
    echo "ip route | egrep '"$DEV_INT"|br"$DEV_INT"' | \\" ; \
    echo 'while read line'; \
    echo 'do'; \
    echo '  ip route delete $line'; \
    echo 'done'; \
    echo ''; \
    echo 'ip rule add from '$IP_INT' lookup '$ROUTING_TABLE_INT; \
    echo 'ip rule add to '$NETWORK_ADDRESS'/'$CIDR' lookup '$ROUTING_TABLE_INT; \
    echo 'ip rule add to '$NFS_SERVER_DOMAIN' table '$ROUTING_TABLE_INT; \
  } > /root/repairRoutes.sh

  chmod +x /root/repairRoutes.sh

  { \
    echo '[Unit]'; \
    echo 'Description=Repair routes on multi NIC setup'; \
    echo 'After=network.target'; \
    echo ''; \
    echo '[Service]'; \
    echo 'ExecStart=/root/repairRoutes.sh'; \
    echo 'Type=oneshot'; \
    echo ''; \
    echo '[Install]'; \
    echo 'WantedBy=multi-user.target'; \
  } > /etc/systemd/system/repairRoutes.service

  systemctl enable --now repairRoutes.service > /dev/null 2>&1
  systemctl daemon-reload
elif [ ${#PUBLIC_IPS[@]} -gt 1 ]; then
  >&2 echo "Too many public interfaces. I have no idea what to do!"
  exit 1;
fi

if [ ${#PRIVATE_IPS[@]} -eq 1 ]; then
  for IP in "${PRIVATE_IPS[@]}" ; do
    # Two private interfaces; First is gonna be SSH; Second OVN
    DEV_NAME=$(echo ${PRIVATE_IPS[0]} | awk '{print $4}')
    IP_INTERNAL=$(echo ${PRIVATE_IPS[0]} | awk '{print $1}')
    CIDR=$(echo ${PRIVATE_IPS[0]} | awk '{print $2}')
    NETWORK_ADDRESS=$(ip_to_netaddr $(echo ${PRIVATE_IPS[0]} | awk '{print $1;}') $(echo $SUBNET_MASK))
    CURRENT_GATEWAY=$(echo "$GATEWAYS" | awk -v pos="1" '{print $pos}')
    # Setup SSH interface
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
    if [ ${#PUBLIC_IPS[@]} -eq 1 ]; then
    # This is a 2 interface machine;
    # Get rid of previous Gateway
    sed -i '0,/Gateway=/{/Gateway=/d;}' /etc/systemd/network/$DEV_NAME.network
    # Append Route logic
    { \
      echo ''; \
      echo '[Route]'; \
      echo 'Gateway='$CURRENT_GATEWAY; \
      echo 'Table='$ROUTING_TABLE_INT; \
      echo ''; \
      echo '[Route]'; \
      echo 'Gateway='$CURRENT_GATEWAY; \
      echo 'Destination='$NETWORK_ADDRESS'/'$CIDR; \
      echo 'Table='$ROUTING_TABLE_INT; \
    } >> /etc/systemd/network/$DEV_NAME.network
    # Setup networkd for ovn kubernetes bridge
    cp /etc/systemd/network/$DEV_NAME.network /etc/systemd/network/br$DEV_NAME.network
    sed -i "s/Name=$DEV_NAME/Name=br$DEV_NAME/g" /etc/systemd/network/br$DEV_NAME.network
    fi
    echo "Writting "$DEV_NAME".network"
  done
else
  >&2 echo "Too many private interfaces. I have no idea what to do!"
  exit 1;
fi

# We always use the private IP for SSH
IP_INT=$(echo ${PRIVATE_IPS[0]} | awk '{print $1}')

rm /etc/resolv.conf

# Start systemd networking
systemctl enable --now systemd-networkd.service > /dev/null 2>&1
systemctl enable --now systemd-resolved.service > /dev/null 2>&1

# Setup systemd DNS
sed -i 's/#DNS=/DNS=129.187.5.1/;' /etc/systemd/resolved.conf

systemctl disable networking.service > /dev/null 2>&1

ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

systemctl restart systemd-resolved.service > /dev/null 2>&1

rm -f /etc/systemd/network/wired.network
systemctl daemon-reload

systemctl restart systemd-networkd

sed -i 's/#ListenAddress 0.0.0.0/ListenAddress '$IP_INT'/
  s/#AddressFamily.*/AddressFamily inet/;' /etc/ssh/sshd_config
