# K8s base image for vms

Designed to be the base for the cluster. All recipes have been tested on a ubuntu 16.04 (maybe some packages are missing, but installation should be straightforward).

## QCOW2-IMAGE FOR KVM

Based on (all retrieved on 2017-10-19):
* [Creating a KVM virtual machine using debootstrap (main source, but old)](http://diogogomes.com/2012/07/13/debootstrap-kvm-image/index.html)
* [Create a complete system image without booting in the emulator (newer but seems to based on first one)](http://tic-le-polard.blogspot.de/2015/04/qemu-create-complete-system-image.html)
* [spindle - a tool to help spin distribution images (set of bash scripts, complex but very helpful)](https://github.com/asb/spindle)
* [Creating a BIOS/GPT and UEFI/GPT Grub-bootable Linux system](https://blog.heckel.xyz/2017/05/28/creating-a-bios-gpt-and-uefi-gpt-grub-bootable-linux-system/)

```bash
KEYFILE=~/.ssh/id_rsa.pub

./util/createVMImage.sh \
  -k $KEYFILE \
  -p apt-transport-https \
  -p bash-completion \
  -p ca-certificates \
  -p curl \
  -p conntrack \
  -p conntrackd \
  -p dbus \
  -p git \
  -p grub-pc \
  -p ipcalc \
  -p iproute2 \
  -p linux-image-amd64 \
  -p locales \
  -p openssh-server \
  -p python \
  -p python-dbus \
  -p python-dnspython \
  -p python-openssl \
  -p software-properties-common \
  -p systemd \
  -p systemd-sysv

# Test locally
sudo qemu-system-x86_64 -hda $BUILDDIR/$IMAGE -m 1024 -device e1000,netdev=user.0 -netdev user,id=user.0,hostfwd=tcp::5555-:22
ssh -p 5555 root@localhost
```
