#!/bin/bash
# Step 11: UFS Explorer Professional Recovery (driven by xdotool). OPTIONAL: it clicks "I accept" in the SysDev EULA on YOUR behalf,
# so it only runs when you set ACCEPT_UFS_EULA=yes after reading the EULA yourself. Run after step 08.
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/00-common.sh"
if [ "${ACCEPT_UFS_EULA:-}" != "yes" ]; then log "UFS Explorer SKIPPED (export ACCEPT_UFS_EULA=yes only after you have read and accepted the SysDev EULA)"; exit 0; fi
rm -rf "$ROOTFS/root/extras"; mkdir -p "$ROOTFS/root/extras"
cp "$EXTRAS/ufsxpci.tar.xz" "$ROOTFS/root/extras/"
cp "$BUILD_ROOT/build/chroot/29-ufs.sh" "$ROOTFS/root/29-ufs.sh"; chmod +x "$ROOTFS/root/29-ufs.sh"
log "running 29-ufs.sh in the chroot (log: $LOGS/29-ufs.log)"
in_chroot bash /root/29-ufs.sh > "$LOGS/29-ufs.log" 2>&1
RC=$?
rm -rf "$ROOTFS/root/29-ufs.sh" "$ROOTFS/root/extras"
tail -n 14 "$LOGS/29-ufs.log"
log "STEP 11 (ufs) finished rc=$RC"
exit $RC
