#!/bin/bash
# Step 8: installs the "missing" items (27-newer.sh) inside the chroot and brings the logs into $LOGS/newer.
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/00-common.sh"
rm -rf "$ROOTFS/root/extras"; mkdir -p "$ROOTFS/root/extras"
cp -a "$EXTRAS/." "$ROOTFS/root/extras/"
rm -rf "$ROOTFS/root/extras-new"; mkdir -p "$ROOTFS/root/extras-new"; cp -a "$DL/extras-new/." "$ROOTFS/root/extras-new/"
cp "$BUILD_ROOT/build/chroot/27-newer.sh" "$ROOTFS/root/27-newer.sh"; chmod +x "$ROOTFS/root/27-newer.sh"
log "running 27-newer.sh in the chroot (log: $LOGS/27-newer.log) — builds several programs, may take a while"
in_chroot env ONLY="${ONLY:-}" bash /root/27-newer.sh > "$LOGS/27-newer.log" 2>&1
mkdir -p "$LOGS/newer"; cp -a "$ROOTFS/var/log/hddlive-newer/." "$LOGS/newer/" 2>/dev/null || true
cp "$ROOTFS/root/newer-results.txt" "$LOGS/newer/results.txt" 2>/dev/null || true
rm -rf "$ROOTFS/var/log/hddlive-newer" "$ROOTFS/root/27-newer.sh" "$ROOTFS/root/newer-results.txt" "$ROOTFS/root/extras" "$ROOTFS/root/extras-new"
cat "$LOGS/newer/results.txt"
log "STEP 8 (newer) finished"
