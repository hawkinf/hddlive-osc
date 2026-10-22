#!/bin/bash
# Runs INSIDE the chroot: regenerates the initramfs and cleans out everything that must not go into the image.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
KVER=$(ls /lib/modules | sort -V | tail -1)
echo "kernel: $KVER"
# the initramfs must not carry arrays/volumes from the build server
[ -f /etc/mdadm/mdadm.conf ] && sed -i '/^ARRAY/d' /etc/mdadm/mdadm.conf || true
: > /etc/crypttab 2>/dev/null || true
# cloud-init is useless on a recovery live image (it slows down boot)
mkdir -p /etc/cloud && touch /etc/cloud/cloud-init.disabled
# (24.04) Ubuntu's casper generates a UUID per build (CASPER_GENERATE_UUID) that would need to go in .disk/casper-uuid-generic on the ISO, and pins
# LAYERFS_PATH=minimal.standard.live.squashfs (layers). Here the ISO has ONE squashfs (filesystem.squashfs): disable both.
rm -f /etc/initramfs-tools/conf.d/casperize.conf /etc/initramfs-tools/conf.d/default-layer.conf
update-initramfs -u -k "$KVER"
ls -la /boot | grep "$KVER" || true
depmod -a "$KVER"
echo "dkms:"; dkms status
find /lib/modules/$KVER -name 'oscdriver*' | head
apt-get -y autoremove --purge || true
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /var/cache/debconf/*-old /var/lib/dpkg/*-old
rm -rf /root/extras /root/hddlive /root/.cache /root/.bash_history /tmp/* /var/tmp/* /var/crash/* 2>/dev/null || true
find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true
rm -f /etc/ssh/ssh_host_* 2>/dev/null || true     # SSH host keys generated during the build must NOT ship in the image
rm -f /var/lib/systemd/random-seed
: > /etc/machine-id
echo "cleanup OK"
