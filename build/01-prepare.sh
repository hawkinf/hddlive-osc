#!/bin/bash
# Step 1 (Xubuntu 24.04.5): extracts the base ISO and MERGES the 3 squashfs layers (minimal + minimal.standard + minimal.standard.live)
# into a single rootfs (the 24.04 ISO uses layered squashfs/overlayfs; to remaster, we flatten it and write a single filesystem.squashfs).
set -euo pipefail
BUILD_ROOT="${BUILD_ROOT:-/opt/hddlive-build}"
mkdir -p "$BUILD_ROOT"/{dl,out,logs}
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/00-common.sh"

[ -f "$BASE_ISO" ] || { echo "missing $BASE_ISO"; exit 1; }
echo "checking base sha256"; sha256sum "$BASE_ISO" | tee "$LOGS/base-iso.sha256"
grep -q 4ed869ebf2b9f2f6118c1b60b9ed07576e8fe3d5cdfe10aae06869e669878b81 "$LOGS/base-iso.sha256" || { echo "base SHA256 does NOT match"; exit 1; }
if [ -d "$ISO_SRC" ] && [ -n "$(ls -A "$ISO_SRC" 2>/dev/null)" ]; then echo "iso-src already exists; aborting"; exit 1; fi
if [ -d "$ROOTFS" ]  && [ -n "$(ls -A "$ROOTFS"  2>/dev/null)" ]; then echo "rootfs already exists; aborting"; exit 1; fi
mkdir -p "$ISO_SRC" "$ROOTFS"

log "extracting base ISO contents (xorriso)"
xorriso -osirrox on -indev "$BASE_ISO" -extract / "$ISO_SRC" >"$LOGS/xorriso-extract.log" 2>&1
chmod -R u+w "$ISO_SRC"

log "saving the appended EFI partition (partition 2) and boot parameters"
# the 24.04 ISO has the EFI image as an appended partition (no efi.img file): extract by 512-byte sector range
xorriso -indev "$BASE_ISO" -report_el_torito as_mkisofs  >"$BUILD_ROOT/boot-params-eltorito.txt" 2>/dev/null
xorriso -indev "$BASE_ISO" -report_system_area as_mkisofs >"$BUILD_ROOT/boot-params-sysarea.txt"  2>/dev/null
RANGE=$(grep -o "interval:local_fs:[0-9]*d-[0-9]*d" "$BUILD_ROOT/boot-params-sysarea.txt" | head -1 | sed 's/interval:local_fs://')
S=${RANGE%%d-*}; E=${RANGE##*-}; E=${E%d}
echo "EFI partition: 512B sectors $S .. $E"
dd if="$BASE_ISO" of="$BUILD_ROOT/efi-part.img" bs=512 skip="$S" count=$((E - S + 1)) 2>/dev/null
ls -la "$BUILD_ROOT/efi-part.img"; file "$BUILD_ROOT/efi-part.img" | cut -c1-120
# GRUB MBR (432 bytes)
dd if="$BASE_ISO" of="$BUILD_ROOT/grub-mbr.img" bs=432 count=1 2>/dev/null

log "merging squashfs layers in order (rsync; overlayfs whiteouts become removals)"
: > "$LOGS/whiteouts.log"
FIRST=1
for L in minimal minimal.standard minimal.standard.live; do
  [ -f "$ISO_SRC/casper/$L.squashfs" ] || { log "layer missing: $L"; continue; }
  log "  layer $L"
  if [ $FIRST = 1 ]; then
    unsquashfs -f -d "$ROOTFS" "$ISO_SRC/casper/$L.squashfs" >"$LOGS/unsquashfs-$L.log" 2>&1; FIRST=0
  else
    T="$BUILD_ROOT/layer-tmp"; rm -rf "$T"
    unsquashfs -d "$T" "$ISO_SRC/casper/$L.squashfs" >"$LOGS/unsquashfs-$L.log" 2>&1
    # overlayfs whiteouts (char device 0/0): delete the target in the lower layer and discard the node
    { find "$T" -xdev -type c -print0 2>/dev/null || true; } | while IFS= read -r -d '' f; do
      if [ "$(stat -c '%t:%T' "$f" 2>/dev/null)" = "0:0" ]; then rel="${f#$T}"; rm -rf "$ROOTFS$rel"; rm -f "$f"; echo "whiteout: $rel" >>"$LOGS/whiteouts.log"; fi
    done || true
    rsync -aHX "$T"/ "$ROOTFS"/ >"$LOGS/rsync-$L.log" 2>&1 || { log "rsync failed on $L"; tail -5 "$LOGS/rsync-$L.log"; exit 1; }
    rm -rf "$T"
  fi
done
log "summary"
du -sh "$ISO_SRC" "$ROOTFS" | tee -a "$LOGS/build.log"
ls "$ISO_SRC" "$ISO_SRC/casper" | tee -a "$LOGS/build.log"
chroot "$ROOTFS" dpkg-query -W | wc -l | xargs -I{} echo "packages in rootfs: {}" | tee -a "$LOGS/build.log"
ls "$ROOTFS/boot" | tee -a "$LOGS/build.log"
echo "whiteouts removed: $(wc -l < "$LOGS/whiteouts.log" 2>/dev/null || echo 0)"
log "STEP 1 OK (24.04)"
