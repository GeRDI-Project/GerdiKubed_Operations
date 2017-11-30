# K8s base image for vms

Designed to be the base for the cluster. All recipes have been tested on a ubuntu 16.04 (maybe some packages are missing, but installation should be straightforward).

## QCOW2-IMAGE FOR KVM

Based on (all retrieved on 2017-10-19):
* [Creating a KVM virtual machine using debootstrap (main source, but old)](http://diogogomes.com/2012/07/13/debootstrap-kvm-image/index.html)
* [Create a complete system image without booting in the emulator (newer but seems to based on first one)](http://tic-le-polard.blogspot.de/2015/04/qemu-create-complete-system-image.html)
* [spindle - a tool to help spin distribution images (set of bash scripts, complex but very helpful)](https://github.com/asb/spindle)

```bash

BUILDDIR=~/mindeb_vm
MNTDIR=$BUILDDIR/mnt
DEBIAN=stretch
MIRROR=http://debian.mirror.lrz.de/debian
SIZE=10G
IMAGE=mindeb.qcow2

# install requirements
apt-get install qemu \
  debootstrap

mkdir $BUILDDIR

# enable nbd kernel module
sudo modprobe nbd

sudo qemu-img create -f qcow2 $BUILDDIR/$IMAGE $SIZE

sudo qemu-nbd -c /dev/nbd0 $BUILDDIR/$IMAGE

#TODO parted? SAI-242
sudo sfdisk /dev/nbd0 <<EOF
,2097152,82
;
EOF

sudo mkswap /dev/nbd0p1
sudo mkfs.ext4 /dev/nbd0p2
mkdir $MNTDIR
sudo mount /dev/nbd0p2 $MNTDIR

sudo debootstrap --variant=minbase \
    $DEBIAN \
    $MNTDIR \
    $MIRROR

sudo mount --bind /dev $MNTDIR/dev

sudo chroot $MNTDIR /bin/bash
# now we are root and do not need sudo anymore
mount -t proc none /proc
mount -t sysfs none /sys

# openssh-server + python + iprout2 to be ansible ready (python has to be > 3 as of the time writing)
# TODO: replace grub2 with lightweight isolinux SAI-242
# TODO: no init script in /sbin unless systemd-sysv is installed? SAI-242
apt-get install -y \
    --no-install-recommends \
    linux-image-amd64 \
    systemd \
    systemd-sysv \
    grub-pc \
    openssh-server \
    python \
    iproute2

# when asked by group for a device enter /dev/nbd0 (NOT /dev/nbd0p2)
apt-get clean

grub-install /dev/nbd0
update-grub

passwd root

cat > /etc/fstab <<EOF
/dev/sda1 none swap sw 0 0
/dev/sda2 / ext4 errors=remount-ro 0 1
EOF

mkdir /root/.ssh
#TODO: Not nice: Hard coding ssh-keys, but works sofar ;) SAI-242
cat > /root/.ssh/authorized_keys <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9olNhMkCbQPJ2vcjIFwNSB8IW/BwuA6fm8Hu1GsPFPsvMYGxibOZ0lXQNu5tyUfv7dQaq3hS4p2jCWp1ldFB64+GjiuFNuJSijER/p28VUCxF7FIslNLUTXWdNIHttZaZ1ugrKZwdkUbdOmsDQ8OBOuRlSAjMmuGQxstrnwfKYddnvbguUU4C3smAC/AEVst9yPLu2QwrRAe2R8Dg0TvMckkzQVompft/jSoIwC2GCkx4ZkDrPOZiXqy241Tt1LaEjuj1Kz/iKw065XGwChfIgEdKGa8sS1t3cv/wwLaGBz26ujJ0OrcRvwlGOkPTLZ9vz4BPyet3U7dYHLZNwkdB tobi@Joschka
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFFtpcNHDgsysmAHibEnJzRD2NvL0RAdgwZ7x3fcykLuEoF7D6G+YgYETzBZFg61ZtwzPQJWDUq4f7+lklZmZzUtFqbLMBwkDN9CAIWbK3BVtO4umzXmN8oyTNmRKIV0lyDM6WMe4w/6eKG/W6zXXujCMG4UE/SWTOdUOWD7eaTEUt1X46XvWfZOyWXodizxFZwE0MD35Z45zJQ9wC5oU1fvgrB9SCGPyI0w9PgdTLrqAOrVJNNSzCfszzXCG9TSNw72zGh3dsHnWnJ5Ru2dJEK6qUi7eW/k2qfEKbHOH7eY7tXahLuYzvaZ7ixdCtlyApaZkkKFkLZ80o9x8wRmhj di72jiv@di72jiv-Latitude-E7270
EOF

cat > /etc/systemd/network/wired.network <<EOF
[Match]
Name=en*

[Network]
DHCP=yes
EOF

systemctl enable systemd-networkd.service

# After that no network is available in chroot! To regain network (for new packages etc, rm resolv.conf and restore the resolv.conf on your machine. Do not forget to restore the following setup)

rm /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
systemctl enable systemd-resolved.service

# Shrink image (zero bytes are non-dirty, host will not see them as "claimed" by guest)
# see https://serverfault.com/questions/329287/free-up-not-used-space-on-a-qcow2-image-file-on-kvm-qemu
# TODO: There might be a more elegant solution, since this consumes a lot of time... SAI-242
# Saves ~ 300MB of image size. If this is the way to go, we should tune it further
# (delete unnecessary files befor dd'ing)
dd if=/dev/zero of=/tmp/somefile
rm /tmp/somefile


umount /proc/ /sys/ /dev/

exit

sudo sed -i 's/nbd0p2/sda2/g' $MNTDIR/boot/grub/grub.cfg

sudo umount $MNTDIR
sudo qemu-nbd -d /dev/nbd0

# use resized image
qemu-img convert -O qcow2 $BUILDDIR/${IMAGE} $BUILDDIR/${IMAGE}_bkp
rm $BUILDDIR/${IMAGE}
mv $BUILDDIR/${IMAGE}_bkp $BUILDDIR/${IMAGE}

# Test locally
sudo qemu-system-x86_64 -hda $BUILDDIR/$IMAGE -m 1024 -device e1000,netdev=user.0 -netdev user,id=user.0,hostfwd=tcp::5555-:22
ssh -p 5555 root@localhost
```
