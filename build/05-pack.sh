#!/bin/bash
# (24.04) Step 5: cleanup, kernel/initrd, SINGLE (flattened) squashfs, manifest, GRUB menus, two-pass md5 and hybrid BIOS+UEFI ISO.
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/00-common.sh"

if [ -z "${REPACK_ONLY:-}" ]; then   # REPACK_ONLY=1 skips cleanup/squashfs (only redoes menus + md5 + ISO)
log "final cleanup in the chroot"
cp "$BUILD_ROOT/build/chroot/30-cleanup.sh" "$ROOTFS/root/30-cleanup.sh"
in_chroot bash /root/30-cleanup.sh 2>&1 | tee "$LOGS/30-cleanup.log" | tail -20
rm -f "$ROOTFS/root/30-cleanup.sh"
if [ -e "$ROOTFS/etc/resolv.conf.hddlive-orig" ] || [ -L "$ROOTFS/etc/resolv.conf.hddlive-orig" ]; then
  rm -f "$ROOTFS/etc/resolv.conf"; mv "$ROOTFS/etc/resolv.conf.hddlive-orig" "$ROOTFS/etc/resolv.conf"
fi
rm -f "$ROOTFS/usr/sbin/policy-rc.d"
ls -la "$ROOTFS/etc/resolv.conf"

KVER=$(ls "$ROOTFS/lib/modules" | sort -V | tail -1)
log "image kernel: $KVER"
cp -f "$ROOTFS/boot/vmlinuz-$KVER"    "$ISO_SRC/casper/vmlinuz"
cp -f "$ROOTFS/boot/initrd.img-$KVER" "$ISO_SRC/casper/initrd"

log "single squashfs (xz) — the 24.04 ISO is layered; here we flatten it into one filesystem.squashfs"
rm -f "$ISO_SRC"/casper/*.squashfs "$ISO_SRC"/casper/*.manifest "$ISO_SRC"/casper/*.size "$ISO_SRC"/casper/SHA256SUMS* "$ISO_SRC"/casper/install-sources.yaml
mksquashfs "$ROOTFS" "$ISO_SRC/casper/filesystem.squashfs" -comp xz -Xbcj x86 -b 1M -noappend -no-progress -processors "$(nproc)" >"$LOGS/mksquashfs.log" 2>&1
ls -la "$ISO_SRC/casper/"
chroot "$ROOTFS" dpkg-query -W --showformat='${Package}\t${Version}\n' > "$ISO_SRC/casper/filesystem.manifest"
printf '%s' "$(du -sx --block-size=1 "$ROOTFS" | cut -f1)" > "$ISO_SRC/casper/filesystem.size"
wc -l "$ISO_SRC/casper/filesystem.manifest"
fi

log "boot menus (GRUB)"
bash "$BUILD_ROOT/build/06-bootmenus.sh"

make_md5() { ( cd "$ISO_SRC" && find . -type f -not -name md5sum.txt -not -path './boot.catalog' -print0 | sort -z | xargs -0 md5sum > md5sum.txt ); }
build_iso() {
  rm -f "$OUT/$NEW_ISO_NAME"
  xorriso -as mkisofs -r -V "HDDLive 24.04.5" -J -joliet-long -cache-inodes -iso-level 3 \
    --grub2-mbr "$BUILD_ROOT/grub-mbr.img" --protective-msdos-label \
    -partition_cyl_align off -partition_offset 16 --mbr-force-bootable \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$BUILD_ROOT/efi-part.img" -appended_part_as_gpt \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    -c '/boot.catalog' -b '/boot/grub/i386-pc/eltorito.img' -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
    -eltorito-alt-boot -e '--interval:appended_partition_2:::' -no-emul-boot -boot-load-size 10160 \
    -o "$OUT/$NEW_ISO_NAME" "$ISO_SRC" >"$LOGS/xorriso-build.log" 2>&1 || { tail -20 "$LOGS/xorriso-build.log"; exit 1; }
}

log "md5sum.txt + hybrid ISO (pass 1)"
rm -f "$ISO_SRC/boot.catalog"
make_md5; build_iso
# xorriso writes eltorito.img with boot-info-table/grub2-boot-info filled in; the md5 of the (unpatched) tree would not match in "Check disc for defects".
log "pass 2 (md5 of the already-patched eltorito.img)"
chmod u+w "$ISO_SRC/boot/grub/i386-pc/eltorito.img"
xorriso -osirrox on -indev "$OUT/$NEW_ISO_NAME" -extract /boot/grub/i386-pc/eltorito.img "$ISO_SRC/boot/grub/i386-pc/eltorito.img" >/dev/null 2>&1
chmod u+w "$ISO_SRC/boot/grub/i386-pc/eltorito.img"
make_md5; build_iso
tail -5 "$LOGS/xorriso-build.log"
unshare -m bash -c "mkdir -p /mnt/hddliveiso24 && mount -o loop,ro '$OUT/$NEW_ISO_NAME' /mnt/hddliveiso24 && cd /mnt/hddliveiso24 && md5sum -c md5sum.txt >'$LOGS/md5-verify.log' 2>&1; echo \"md5 failures: \$(grep -vc ': OK\$' '$LOGS/md5-verify.log')  ok: \$(grep -c ': OK\$' '$LOGS/md5-verify.log')\"; ls /mnt/hddliveiso24 | tr '\n' ' '"
sha256sum "$OUT/$NEW_ISO_NAME" | tee "$OUT/$NEW_ISO_NAME.sha256"
ls -la "$OUT"
log "STEP 5 (pack 24.04) OK"
