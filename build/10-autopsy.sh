#!/bin/bash
# Step 10: Autopsy 4.23.1 (heavy, isolated stage: +1.2 GB). Run AFTER 08/04 and BEFORE 05-pack.
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/00-common.sh"
ZIP="$DL/autopsy/autopsy-4.23.1.zip"
[ -s "$ZIP" ] || { mkdir -p "$DL/autopsy"; curl -fL -A "Mozilla/5.0" -o "$ZIP" https://github.com/sleuthkit/autopsy/releases/download/autopsy-4.23.1/autopsy-4.23.1.zip; }
rm -rf "$ROOTFS/root/extras"; mkdir -p "$ROOTFS/root/extras"
cp "$ZIP" "$ROOTFS/root/extras/"; cp "$EXTRAS/sleuthkit-4.15.0.tar.gz" "$ROOTFS/root/extras/"
cp "$BUILD_ROOT/build/chroot/28-autopsy.sh" "$ROOTFS/root/28-autopsy.sh"; chmod +x "$ROOTFS/root/28-autopsy.sh"
log "running 28-autopsy.sh in the chroot (log: $LOGS/28-autopsy.log)"
in_chroot bash /root/28-autopsy.sh > "$LOGS/28-autopsy.log" 2>&1
RC=$?
cp "$ROOTFS/var/log/hddlive-newer/tsk-java.log" "$LOGS/newer/" 2>/dev/null || true
rm -rf "$ROOTFS/var/log/hddlive-newer" "$ROOTFS/root/28-autopsy.sh" "$ROOTFS/root/extras"
tail -n 25 "$LOGS/28-autopsy.log"
log "STEP 10 (autopsy) finished rc=$RC"
exit $RC
