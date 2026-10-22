#!/bin/bash
# HDDLive build — common variables and helpers. `source` this file from the other scripts.
# Runs on the build host (Ubuntu 22.04 or newer, root). Set BUILD_ROOT to change the working tree (default /opt/hddlive-build).
set -euo pipefail

export BUILD_ROOT="${BUILD_ROOT:-/opt/hddlive-build}"
export DL="$BUILD_ROOT/dl"                  # input ISOs and downloads
export EXTRAS="$DL/extras"                  # downloaded .deb/.zip/.tar files
export ISO_SRC="$BUILD_ROOT/iso-src"        # extracted contents of the base ISO
export ROOTFS="$BUILD_ROOT/rootfs"          # unpacked squashfs (chroot)
export OLD="$BUILD_ROOT/old-hddlive"       # optional: files extracted from the ORIGINAL HDDLive ISO (ddrescueview, legacy HDDSuperClone)
export OUT="$BUILD_ROOT/out"
export LOGS="$BUILD_ROOT/logs"
export BASE_ISO="$DL/xubuntu-24.04.5-desktop-amd64.iso"
export OLD_ISO="$DL/xubuntu-hddlive-x64.iso"
export NEW_ISO_NAME="hddlive-osc-24.04.5-amd64.iso"
mkdir -p "$LOGS" "$OUT"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOGS/build.log"; }

# Runs a command inside the chroot with PRIVATE mounts (they vanish on exit; nothing leaks to the host).
#  - /dev is a minimal tmpfs (null, zero, random...): the chroot does NOT see the server's disks.
#  - policy-rc.d blocks services from starting.
in_chroot() {
  unshare --mount --propagation private -- bash -c '
    set -e
    R="$1"; shift
    mount -t tmpfs -o mode=755,size=16m tmpfs "$R/dev"
    for n in "null c 1 3" "zero c 1 5" "full c 1 7" "random c 1 8" "urandom c 1 9" "tty c 5 0" "console c 5 1"; do
      set -- $n "$@"; nm=$1; ty=$2; ma=$3; mi=$4; shift 4
      mknod -m 666 "$R/dev/$nm" $ty $ma $mi
    done
    mkdir -p "$R/dev/pts" "$R/dev/shm"
    mount -t devpts devpts "$R/dev/pts" -o newinstance,ptmxmode=0666,mode=620
    ln -sf pts/ptmx "$R/dev/ptmx"; ln -sf /proc/self/fd "$R/dev/fd"
    ln -sf /proc/self/fd/0 "$R/dev/stdin"; ln -sf /proc/self/fd/1 "$R/dev/stdout"; ln -sf /proc/self/fd/2 "$R/dev/stderr"
    mount -t tmpfs tmpfs "$R/dev/shm"
    mount -t proc proc "$R/proc"
    mount -t sysfs sysfs "$R/sys"
    mount -t tmpfs tmpfs "$R/run"
    mount -t tmpfs tmpfs "$R/tmp"
    [ -e "$R/etc/resolv.conf.hddlive-orig" ] || cp -a "$R/etc/resolv.conf" "$R/etc/resolv.conf.hddlive-orig" 2>/dev/null || true
    rm -f "$R/etc/resolv.conf"; echo "nameserver 1.1.1.1" > "$R/etc/resolv.conf"
    printf "#!/bin/sh\nexit 101\n" > "$R/usr/sbin/policy-rc.d"; chmod +x "$R/usr/sbin/policy-rc.d"
    chroot "$R" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin DEBIAN_FRONTEND=noninteractive LC_ALL=C "$@"
  ' _ "$ROOTFS" "$@"
}
