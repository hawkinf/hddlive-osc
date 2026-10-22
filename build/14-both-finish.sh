#!/bin/bash
# (24.04) From an already-installed rootfs with 08/11 done: builds BOTH ISOs (light, and full with Autopsy).
# STRIP=1 first removes Autopsy from the rootfs (use it if the rootfs comes from a full ISO).
# Usage (root):  nohup bash $BUILD_ROOT/build/14-both-finish.sh > $BUILD_ROOT/logs/14-both.out 2>&1 &
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/00-common.sh"
set +e
step() { log "=== $1 ==="; shift; "$@"; local rc=$?; log "rc=$rc"; [ $rc -eq 0 ] || { log "ABORTING at: $*"; exit $rc; }; }
strip_autopsy() { cp "$BUILD_ROOT/build/chroot/31-strip-autopsy.sh" "$ROOTFS/root/31.sh"; in_chroot bash /root/31.sh 2>&1 | tail -15; rm -f "$ROOTFS/root/31.sh"; }
[ "${STRIP:-}" = 1 ] && step "strip autopsy" strip_autopsy
[ "${SKIP11:-}" = 1 ] || step "11 ufs (Sentinel RTE)" bash "$BUILD_ROOT/build/11-ufs.sh"
step "04 configure (light)" bash "$BUILD_ROOT/build/04-configure.sh"
step "05 pack (light)"     bash "$BUILD_ROOT/build/05-pack.sh"
cp -f "$OUT/$NEW_ISO_NAME" "$OUT/light.iso" && cp -f "$OUT/$NEW_ISO_NAME.sha256" "$OUT/light.iso.sha256"
log "LIGHT ISO saved to $OUT/light.iso"
[ "${ONLY_LIGHT:-}" = 1 ] && { log "ONLY_LIGHT: done"; exit 0; }
step "10 autopsy"          bash "$BUILD_ROOT/build/10-autopsy.sh"
step "04 configure (full)" bash "$BUILD_ROOT/build/04-configure.sh"
step "05 pack (full)"      bash "$BUILD_ROOT/build/05-pack.sh"
cp -f "$OUT/$NEW_ISO_NAME" "$OUT/full.iso" && cp -f "$OUT/$NEW_ISO_NAME.sha256" "$OUT/full.iso.sha256"
log "FULL ISO saved to $OUT/full.iso"
log "BOTH ISOS READY"
