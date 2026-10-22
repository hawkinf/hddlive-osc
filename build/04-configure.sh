#!/bin/bash
# Step 4: extras (DMDE, Double Commander, R-Linux, TestDisk 7.2, smartmontools 7.5, guides, self-test), per-category shortcuts,
# udev rule, power settings, README (all inside the chroot).
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/00-common.sh"
rm -rf "$ROOTFS/root/extras"; mkdir -p "$ROOTFS/root/extras"
cp -a "$EXTRAS/." "$ROOTFS/root/extras/"
rm -rf "$ROOTFS/root/assets"; mkdir -p "$ROOTFS/root/assets"; cp -a "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/assets/." "$ROOTFS/root/assets/" 2>/dev/null || true
rm -rf "$ROOTFS/root/extras-new"; mkdir -p "$ROOTFS/root/extras-new"; cp -a "$DL/extras-new/." "$ROOTFS/root/extras-new/" 2>/dev/null
# DMDE is installed WITHOUT a license (Free Edition); no license file is ever copied into the image
cp "$BUILD_ROOT/build/chroot/25-extras.sh" "$BUILD_ROOT/build/chroot/20-config.sh" "$ROOTFS/root/"
chmod +x "$ROOTFS/root/25-extras.sh" "$ROOTFS/root/20-config.sh"
in_chroot bash /root/25-extras.sh 2>&1 | tee "$LOGS/25-extras.log"
in_chroot bash /root/20-config.sh 2>&1 | tee "$LOGS/20-config.log"
rm -rf "$ROOTFS/root/25-extras.sh" "$ROOTFS/root/20-config.sh" "$ROOTFS/root/extras" "$ROOTFS/root/extras-new" "$ROOTFS/root/assets"
log "STEP 4 (extras+config) OK"
