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

if [ "$EUID" -ne 0 ]; then
  echo "Please run using root (sudo)!"
  exit
fi

################################################################################
# DEFAULT PARAMS, HELP-MESSAGE, CHECK PARAMS AND REQUIREMENTS
################################################################################

# Default arguments:
BUILDDIR=~/vmimage
DEBIAN=stretch
MIRROR=http://debian.mirror.lrz.de/debian
SIZE=2G
NAME=debian

function printHelp {
  printf "Usage: %s [OPTIONS]\n" $0
  printf "OPTIONS:\n"
  printf "\t-b|--builddir <pathToBuildDir> Directory to build the image in (Default: %s)\n" $BUILDDIR
  printf "\t-d|--debian <debian> Sets the debian version (Default: %s)\n" \
    $DEBIAN
  printf "\t-h|--help Prints this help message\n"
  printf "\t-k|--key <pathToKeyFile> Path to public key file (necessary to ssh into the vm). May be set several times.\n"
  printf "\t-m|--mirror <url> Debian Package Mirror to be used (Default: %s)\n" \
    $MIRROR
  printf "\t-n|--name <name> Name of the qcow image file (Default: %s)\n" $NAME
  printf "\t-p|--package <pkgName> Package that will be installed in the image. May be set several times.\n"
  printf "\t-s|--size <size> Size of the image (Default: %s)\n" $SIZE
  echo
  echo "After a successful run you will find the image here: <pathToBuildDir>/<name>.qcow2"
}

# Parameter parsing as proposed here:
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
POSITIONAL=()
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
      -b|--builddir)
      BUILDDIR="$2"
      shift # past argument
      shift # past value
      ;;
      -d|--debian)
      DEBIAN="$2"
      shift # past argument
      shift # past value
      ;;
      -h|--help)
      printHelp
      exit
      ;;
      -k|--key)
      KEYS+=("$2")
      shift # past argument
      shift # past value
      ;;
      -m|--mirror)
      MIRROR="$2"
      shift # past argument
      shift # past value
      ;;
      -n|--name)
      MIRROR="$2"
      shift # past argument
      shift # past value
      ;;
      -p|--package)
      PKGS+=("$2")
      shift # past argument
      shift # past value
      ;;
      -s|--size)
      SIZE="$2"
      shift # past argument
      shift # past value
      ;;
      *)    # unknown option
      >&2 echo "Unkown param $key!"
      exit 1
      ;;
  esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters

# Derived parameters
MNTDIR="$BUILDDIR/mnt/"
IMAGE=$NAME.qcow2

# check requirements
for pkg in qemu \
        debootstrap \
        debian-archive-keyring \
        debian-keyring \
        parted
do
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $pkg 2>&1 |grep "install ok installed")
  if [ "" == "$PKG_OK" ]
  then
    echo "Package $pkg is not installed. Please install and retry."
    exit 1
  fi
done

################################################################################
# DISPLAY ACTIONS AND ASK FOR FEEDBACK
################################################################################

printf "Will build %s\n\tBuilddir: %s\n\tDebian: %s\n\tMirror: %s\n" $IMAGE $BUILDDIR $DEBIAN $MIRROR
if [ ${#PKGS[@]} -gt 0 ]
then
  printf "Additional packages to be installed in image:\n"
  for pkg in "${PKGS[@]}"
  do
    printf "\t*) %s\n" $pkg
  done
fi

read -p "Do you want to proceed? Then type in y/Y! " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "Building the image, will be available here: $BUILDDIR/$IMAGE"
else
  echo "All right, will abort. See you next time :)"
  exit 0
fi

################################################################################
# BUILD THE IMAGE
################################################################################
mkdir -p $BUILDDIR

# enable nbd kernel module, partition disk, make fs and mount it
modprobe nbd max_part=16

qemu-img create -f qcow2 $BUILDDIR/$IMAGE $SIZE

qemu-nbd -c /dev/nbd0 $BUILDDIR/$IMAGE

sgdisk -og \
        -n 1::+1M -t 1:ef02 -c 1:'BIOS boot partition' \
        -n 2::-0 -t 2:8300 -c 2:'Linux root filesystem' \
        /dev/nbd0

# Find our partition
LOOPDEV=$(losetup --find --show /dev/nbd0)
partprobe ${LOOPDEV}

# Format linux root fs
mkfs.ext4 -F ${LOOPDEV}p2

# Create mount directory and mount partition to directory
mkdir -p ${MNTDIR}
mount ${LOOPDEV}p2 ${MNTDIR}

# install base system
debootstrap --variant=minbase --arch=amd64 \
    $DEBIAN \
    $MNTDIR \
    $MIRROR

# configure image
echo "/dev/sda2 / ext4 errors=remount-ro 0 1" \
  | tee ${MNTDIR}etc/fstab > /dev/null
for d in dev sys proc; do mount --bind /$d ${MNTDIR}$d; done

# Install additional packages
DEBIAN_FRONTEND=non-interactive chroot ${MNTDIR} \
    apt-get install -y \
    --no-install-recommends \
    ${PKGS[@]}

# Clean up
chroot ${MNTDIR} apt-get clean

# correct locale and timezone
sed -i ' s/# de_DE.UTF-8/de_DE.UTF-8/
              s/# en_US.UTF-8/en_US.UTF-8/' \
  ${MNTDIR}etc/locale.gen
chroot ${MNTDIR} locale-gen
cp ${MNTDIR}usr/share/zoneinfo/Europe/Berlin ${MNTDIR}etc/localtime

# install bootloader
chroot ${MNTDIR} grub-install --modules="ext2 part_gpt" /dev/nbd0
chroot ${MNTDIR} update-grub
sed -i 's/nbd0p2/sda2/g' ${MNTDIR}boot/grub/grub.cfg

# setup networking
chroot ${MNTDIR} systemctl enable systemd-networkd.service
rm ${MNTDIR}etc/resolv.conf
chroot ${MNTDIR} ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
chroot ${MNTDIR} systemctl enable systemd-resolved.service
echo "[Match]
Name=en*

[Network]
DHCP=yes" | tee ${MNTDIR}etc/systemd/network/wired.network > /dev/null

# install ssh-keys
mkdir ${MNTDIR}root/.ssh
for key in ${KEYS[@]}
do
  [ -f "$key" ] || (echo "Given param '$key' (-k|--key) is not a file" && continue)
  cat $key | tee -a ${MNTDIR}root/.ssh/authorized_keys > /dev/null
done

################################################################################
# TIDY UP
################################################################################
umount ${MNTDIR}{proc/,sys/,dev/}
umount ${MNTDIR}
rm -rf ${MNTDIR}
sync ${LOOPDEV}
losetup -d ${LOOPDEV}
qemu-nbd -d /dev/nbd0

echo
echo "DONE!"
echo "Try image:"
echo "sudo qemu-system-x86_64 -hda $BUILDDIR/$IMAGE -m 1024 -device e1000,netdev=user.0 -netdev user,id=user.0,hostfwd=tcp::5555-:22 &"
echo "ssh -p 5555 root@localhost"
