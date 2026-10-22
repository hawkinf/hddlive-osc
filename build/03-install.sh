#!/bin/bash
# Step 3: copies scripts/extras into the rootfs and runs the installation in the chroot.
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/00-common.sh"
rm -rf "$ROOTFS/root/extras" "$ROOTFS/root/hddlive"
mkdir -p "$ROOTFS/root/extras" "$ROOTFS/root/hddlive"
cp -a "$EXTRAS/." "$ROOTFS/root/extras/"
[ -d "$OLD/home/ddrescueview-linux-x86_64" ] && cp -a "$OLD/home/ddrescueview-linux-x86_64" "$ROOTFS/root/extras/" || true   # optional (see README)
cp -a "$BUILD_ROOT/build/chroot/." "$ROOTFS/root/hddlive/"
chmod +x "$ROOTFS"/root/hddlive/*.sh
log "running 10-install.sh in the chroot (log: $LOGS/10-install.log)"
set +e
in_chroot bash /root/hddlive/10-install.sh >"$LOGS/10-install.log" 2>&1
RC=$?
set -e
tail -60 "$LOGS/10-install.log"
log "10-install.sh finished with exit code $RC"
exit $RC
