# K8s base image for vms

Designed to be the base for the cluster

Howto build (based on http://willhaley.com/blog/create-a-custom-debian-stretch-live-environment-ubuntu-17-zesty/# retrieved 2017-10-11)

Tested on a ubuntu 16.04

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
    linux-image-4.9.0-4-amd64 \
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
