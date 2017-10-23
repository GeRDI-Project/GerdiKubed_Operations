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

mkdir $BUILDDIR

# enable nbd kernel module
sudo modprobe nbd

sudo qemu-img create -f qcow2 $BUILDDIR/$IMAGE $SIZE

sudo qemu-nbd -c /dev/nbd0 $BUILDDIR/$IMAGE

#TODO parted?
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

# openssh-server + python to be ansible ready (python has to be > 3 as of the time writing)
# TODO: replace grub2 with lightweight isolinux
# TODO: no init script in /sbin unless systemd-sysv is installed?
apt-get install \
    --no-install-recommends \
    linux-image-amd64 \
    systemd \
    systemd-sysv \
    grub-pc \
    openssh-server \
    python

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
#TODO: Not nice: Hard coding ssh-keys, but works sofar ;)
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
# TODO: There might be a more elegant solution, since this consumes a lot of time...
# Saves ~ 300MB of image size. If this is the way to go, we should tune it further
# (delete unnecessary files befor dd'ing)
dd if=/dev/zero of=/tmp/somefile
rm /tmp/somefile


umount /proc/ /sys/ /dev/

exit

sudo sed -i 's/nbd0p2/sda2/g' $MNTDIR/boot/grub/grub.cfg

# necessary? Try without!
sudo grub-install /dev/nbd0 --root-directory=$MNTDIR --modules="biosdisk part_msdos"


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

## ISO-IMAGE

Based on http://willhaley.com/blog/create-a-custom-debian-stretch-live-environment-ubuntu-17-zesty/# retrieved 2017-10-11

```bash

BUILDDIR=~/live_boot
DEBIAN=stretch
MIRROR=http://debian.mirror.lrz.de/debian
#MIRROR=http://ftp.us.debian.org/debian/

sudo apt-get install \
    debootstrap \
    syslinux \
    isolinux \
    squashfs-tools \
    genisoimage \
    memtest86+ \
    rsync

mkdir $BUILDDIR
#TODO
#W: Cannot check Release signature; keyring file not available /usr/share/keyrings/debian-archive-keyring.gpg
sudo debootstrap --variant=minbase \
    --arch amd64 \
    $DEBIAN \
    $BUILDDIR/chroot \
    $MIRROR

sudo chroot $BUILDDIR/chroot

echo "k8s-debian-stretch-minbase" > /etc/hostname

# eventually change kernel, choose from apt-cache search linux-image
apt-get install --no-install-recommends \
    linux-image-amd64 \
    live-boot \
    systemd-sysv \
    python \
    openssh-server

# debug stuff
#apt-get install iproute2 vim dnsutils


apt-get clean
passwd root

mkdir /root/.ssh

echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFFtpcNHDgsysmAHibEnJzRD2NvL0RAdgwZ7x3fcykLuEoF7D6G+YgYETzBZFg61ZtwzPQJWDUq4f7+lklZmZzUtFqbLMBwkDN9CAIWbK3BVtO4umzXmN8oyTNmRKIV0lyDM6WMe4w/6eKG/W6zXXujCMG4UE/SWTOdUOWD7eaTEUt1X46XvWfZOyWXodizxFZwE0MD35Z45zJQ9wC5oU1fvgrB9SCGPyI0w9PgdTLrqAOrVJNNSzCfszzXCG9TSNw72zGh3dsHnWnJ5Ru2dJEK6qUi7eW/k2qfEKbHOH7eY7tXahLuYzvaZ7ixdCtlyApaZkkKFkLZ80o9x8wRmhj di72jiv@di72jiv-Latitude-E7270" >  /root/.ssh/authorized_keys

echo "[Match]
Name=en*

[Network]
DHCP=yes" > /etc/systemd/network/wired.network

systemctl enable systemd-networkd.service
rm /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
systemctl enable systemd-resolved.service

exit

mkdir -p $BUILDDIR/image/{live,isolinux}

(cd $BUILDDIR && \
    sudo mksquashfs chroot image/live/filesystem.squashfs -e boot
)

(cd $BUILDDIR && \
    cp chroot/boot/vmlinuz-* image/live/vmlinuz1
    cp chroot/boot/initrd.img-* image/live/initrd1
)

# TODO do without isolinux?
echo "UI menu.c32

prompt 1
menu title Debian Live

timeout 1

label Debian Live
menu label ^Debian Live
menu default
kernel /live/vmlinuz1
append initrd=/live/initrd1 boot=live" > $BUILDDIR/image/isolinux/isolinux.cfg

(cd $BUILDDIR/image/ && \
    cp /usr/lib/ISOLINUX/isolinux.bin isolinux/ && \
    cp /usr/lib/syslinux/modules/bios/menu.c32 isolinux/ && \
    cp /usr/lib/syslinux/modules/bios/hdt.c32 isolinux/ && \
    cp /usr/lib/syslinux/modules/bios/ldlinux.c32 isolinux/ && \
    cp /usr/lib/syslinux/modules/bios/libutil.c32 isolinux/ && \
    cp /usr/lib/syslinux/modules/bios/libmenu.c32 isolinux/ && \
    cp /usr/lib/syslinux/modules/bios/libcom32.c32 isolinux/ && \
    cp /usr/lib/syslinux/modules/bios/libgpl.c32 isolinux/ && \
    cp /usr/share/misc/pci.ids isolinux/
)

genisoimage \
    -rational-rock \
    -volid "Debian Live" \
    -cache-inodes \
    -joliet \
    -hfs \
    -full-iso9660-filenames \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -output $BUILDDIR/debian-live.iso \
    $BUILDDIR/image


```
