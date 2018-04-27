#!/bin/bash
# Get all attached ips
# Make sure to only seperate by newline;
# Also get rid of loopback IP
# IPs are stored as IP_ARRAY[0] = IP[[:space:]]CIDR[[:space:]]BROADCAST[[:space:]]DEVICENAME
#      Example: 141.40.254.115 23 141.40.255.255 ens3
IFS=$'\n'
IP_ARRAY=$(ip addr | grep -e "inet[[:space:]]" | grep -v '127.0.0.1' | awk '{print $2" "$4" "$7$8}' | sed 's/\// /g' | sed 's/dynamic//g')
unset $IFS

ROUTING_TABLE_INT=$1

PUBLIC_IPS=()
PRIVATE_IPS=()
GATEWAYS=()

# Split into private and public IPs
# Also calculate gateways
while read -r IP; do
  # Get the gateway address (for LRZ it's broadcast - 1)
  GATEWAYS+=$(echo $IP | awk '{print $3}' | awk -F"." '{printf "%d.%d.%d.%d ", $1, $2, $3, $4 - 1}')
  # Check if IP matches the private IP patterns
  TMP=$(echo $IP | awk '{print $1}' | grep -E '10.*|172.16.*|192.168.*')
  if [ -z "$TMP" ]; then
    # Public IP
    PUBLIC_IPS+=("$IP")
  else
    # Private IP
    PRIVATE_IPS+=("$IP")
  fi
done <<< "$IP_ARRAY"

# Check if we have enough IPs
# Optimal: 1 Public, 2 Private
# Acceptable: 1 Public, 1 Private
# Unacceptable: 1 Public or 0 Private; 0 Public or 1 Private
echo "${#PUBLIC_IPS[@]} Public & ${#PRIVATE_IPS[@]} Private IPs detected."

# Error states
if [ ${#PRIVATE_IPS[@]} -eq 0 ]; then
  >&2 echo "No private IPs assigned to node"
  exit 1
elif [ ${#PUBLIC_IPS[@]} -eq 0 ]; then
  >&2 echo "No public IPs assigned to node"
  exit 1
fi

# All public IPs should use DHCP
for IP in "${PUBLIC_IPS[@]}"; do
  DEV_NAME=$(echo $IP | awk '{print $4}')
  # Setup public interface
  { \
    echo '[Match]'; \
    echo 'Name='$DEV_NAME; \
    echo ''; \
    echo '[Network]'; \
    echo 'DHCP=yes'; \
  } > /etc/systemd/network/$DEV_NAME.network
  echo "Writting "$DEV_NAME".network"
done

# Handle different amounts of private interfaces
if [ ${#PRIVATE_IPS[@]} -eq 1 ]; then
  # One Private interface; Try to route everything (including OVN)
  PUBIP_COUNT=${#PUBLIC_IPS[@]}
  DEV_NAME=$(echo ${PRIVATE_IPS[0]} | awk '{print $4}')
  IP_INTERNAL=$(echo ${PRIVATE_IPS[0]} | awk '{print $1}')
  CIDR=$(echo ${PRIVATE_IPS[0]} | awk '{print $2}')
  # Taken from https://gist.github.com/kwilczynski/5d37e1cced7e76c7c9ccfdf875ba6c5b
  # Because this is a beautiful solution
  TMP=$(( 0xffffffff ^ ((1 << (32 - $(echo ${PRIVATE_IPS[0]} | awk '{print $2}'))) - 1) ))
  SUBNET_MASK="$(( (TMP >> 24) & 0xff )).$(( (TMP >> 16) & 0xff )).$(( (TMP >> 8) & 0xff )).$(( TMP & 0xff ))"

  # Taken from https://stackoverflow.com/questions/15429420/given-the-ip-and-netmask-how-can-i-calculate-the-network-address-using-bash?answertab=active#tab-top
  # Again, short and to the point
  IFS=. read -r i1 i2 i3 i4 <<< "$(echo ${PRIVATE_IPS[0]} | awk '{print $1}')"
  IFS=. read -r m1 m2 m3 m4 <<< $SUBNET_MASK
  NETWORK_ADDRESS=$(printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))")
  unset $IFS
  CURRENT_GATEWAY=$(echo "$GATEWAYS" | awk -v pos="$(($PUBIP_COUNT+1))" '{print $pos}')
  # Setup private interface
  { \
    echo '[Match]'; \
    echo 'Name='$DEV_NAME; \
    echo ''; \
    echo '[Network]'; \
    echo 'DHCP=no'; \
    echo ''; \
    echo '[Address]'; \
    echo 'Address='$IP_INTERNAL'/'$CIDR; \
    echo ''; \
    echo '[Route]'; \
    echo 'Gateway='$CURRENT_GATEWAY; \
    echo 'Table='$ROUTING_TABLE_INT; \
    echo ''; \
    echo '[Route]'; \
    echo 'Gateway='$CURRENT_GATEWAY'/'$CIDR; \
    echo 'Destination='$NETWORK_ADDRESS'/'$CIDR; \
    echo 'Table='$ROUTING_TABLE_INT; \
  } > /etc/systemd/network/$DEV_NAME.network
elif [ ${#PRIVATE_IPS[@]} -gt 1 ]; then
  COUNTER=0
  for IP in "${PRIVATE_IPS[@]}" ; do
    # Two or more private interfaces; First is gonna be OVN; Second SSH
    PUBIP_COUNT=${#PUBLIC_IPS[@]}
    DEV_NAME=$(echo ${PRIVATE_IPS[$COUNTER]} | awk '{print $4}')
    IP_INTERNAL=$(echo ${PRIVATE_IPS[$COUNTER]} | awk '{print $1}')
    CIDR=$(echo ${PRIVATE_IPS[$COUNTER]} | awk '{print $2}')
    if [ $COUNTER -eq 0 ]; then
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
    elif [ $COUNTER -eq 1 ]; then
      # Internal interface
      # Taken from https://gist.github.com/kwilczynski/5d37e1cced7e76c7c9ccfdf875ba6c5b
      # Because this is a beautiful solution
      TMP=$(( 0xffffffff ^ ((1 << (32 - $(echo ${PRIVATE_IPS[$COUNTER]} | awk '{print $2}'))) - 1) ))
      SUBNET_MASK="$(( (TMP >> 24) & 0xff )).$(( (TMP >> 16) & 0xff )).$(( (TMP >> 8) & 0xff )).$(( TMP & 0xff ))"
      # Taken from https://stackoverflow.com/questions/15429420/given-the-ip-and-netmask-how-can-i-calculate-the-network-address-using-bash?answertab=active#tab-top
      # Again, short and to the point
      IFS=. read -r i1 i2 i3 i4 <<< "$(echo ${PRIVATE_IPS[$COUNTER]} | awk '{print $1}')"
      IFS=. read -r m1 m2 m3 m4 <<< $SUBNET_MASK
      NETWORK_ADDRESS=$(printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))")
      unset $IFS
      CURRENT_GATEWAY=$(echo "$GATEWAYS" | awk -v pos="$(($PUBIP_COUNT+2))" '{print $pos}')
      # Setup private interface
      { \
        echo '[Match]'; \
        echo 'Name='$DEV_NAME; \
        echo ''; \
        echo '[Network]'; \
        echo 'DHCP=no'; \
        echo ''; \
        echo '[Address]';
        echo 'Address='$IP_INTERNAL'/'$CIDR; \
        echo ''; \
        echo '[Route]'; \
        echo 'Gateway='$CURRENT_GATEWAY; \
        echo 'Table='$ROUTING_TABLE_INT; \
        echo ''; \
        echo '[Route]'; \
        echo 'Gateway='$CURRENT_GATEWAY'/'$CIDR; \
              echo 'Destination='$NETWORK_ADDRESS'/'$CIDR; \
        echo 'Table='$ROUTING_TABLE_INT; \
      } > /etc/systemd/network/$DEV_NAME.network
      echo "Writting "$DEV_NAME".network"
    fi
    COUNTER=$((COUNTER+1))
  done
fi

# We always use the first private ip for OVN and the second for internal
# Note: That case 1 public & 1 private is covered by the | in egrep
DEV_OVN=$(echo ${PRIVATE_IPS[0]} | awk '{print $4}')
DEV_INT=$(echo ${PRIVATE_IPS[1]} | awk '{print $4}')

IP_INT=$(echo ${PRIVATE_IPS[1]} | awk '{print $1}')

CIDR=$(echo ${PRIVATE_IPS[1]} | awk '{print $2}')

# Write repairRoutes.sh
# Taken from Gerdi GIT (gerdikubed/util/sed.src/repairRoutes.sh)
{ \
  echo '#!/bin/bash'; \
  echo "ip route | egrep '"$DEV_INT"|"$DEV_OVN"' | \\" ; \
  echo 'while read line'; \
  echo 'do'; \
  echo '  ip route delete $line'; \
  echo 'done'; \
  echo ''; \
  echo 'ip rule add from '$IP_INT' lookup '$ROUTING_TABLE_INT; \
  echo 'ip rule add to '$NETWORK_ADDRESS'/'$CIDR' lookup '$ROUTING_TABLE_INT; \
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

rm -f /etc/systemd/network/wired.network
systemctl enable repairRoutes.service
systemctl daemon-reload

sed -i 's/#ListenAddress 0.0.0.0/ListenAddress '$IP_INT'/
  s/#AddressFamily.*/AddressFamily inet/;' /etc/ssh/sshd_config
