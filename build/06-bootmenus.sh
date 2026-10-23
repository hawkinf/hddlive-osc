#!/bin/bash
# (24.04) Boot menus: the 24.04 ISO uses GRUB for both BIOS (eltorito.img) and UEFI -> only grub.cfg and loopback.cfg.
# Based on the old HDDLive menu ("disable ataX" entry) + extras useful for disk recovery.
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/00-common.sh"
I="$ISO_SRC"
CMD="boot=casper"     # explicit: the initrd regenerated in the chroot does not assume casper on its own
PT="locale=pt_BR.UTF-8 keyboard-configuration/layoutcode=br keyboard-configuration/modelcode=abnt2 console-setup/layoutcode=br"

entries() {  # $1 = extra parameters (loopback needs iso-scan)
  local LB="$1"
  cat <<EOF
menuentry "HDDLive - Try without installing" {
	set gfxpayload=keep
	linux	/casper/vmlinuz  $CMD $LB quiet splash ---
	initrd	/casper/initrd
}
menuentry "HDDLive - persistent (needs a partition labeled casper-rw)" {
	set gfxpayload=keep
	linux	/casper/vmlinuz  $CMD $LB persistent quiet splash ---
	initrd	/casper/initrd
}
menuentry "HDDLive - disable ataX (press e, change X, e.g. 1 = ata1)" {
	set gfxpayload=keep
	linux	/casper/vmlinuz  $CMD $LB quiet splash --- libata.force=X:disable
	initrd	/casper/initrd
}
menuentry "HDDLive - load into RAM (can remove the USB/DVD)" {
	set gfxpayload=keep
	linux	/casper/vmlinuz  $CMD $LB quiet splash toram ---
	initrd	/casper/initrd
}
menuentry "HDDLive - safe graphics (nomodeset)" {
	set gfxpayload=keep
	linux	/casper/vmlinuz  $CMD $LB quiet splash nomodeset ---
	initrd	/casper/initrd
}
menuentry "Check disc for defects" {
	set gfxpayload=keep
	linux	/casper/vmlinuz  $CMD $LB integrity-check quiet splash ---
	initrd	/casper/initrd
}
EOF
}
{
cat <<'EOF'
set timeout=10

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

EOF
entries ""
cat <<'EOF'
grub_platform
if [ "$grub_platform" = "efi" ]; then
menuentry 'Boot from next volume' {
	exit 1
}
menuentry 'UEFI Firmware Settings' {
	fwsetup
}
else
menuentry 'Test memory' {
	linux16 /boot/memtest86+x64.bin
}
fi
EOF
} > "$I/boot/grub/grub.cfg"

{
echo "set timeout=10"
entries 'iso-scan/filename=${iso_path}'
} > "$I/boot/grub/loopback.cfg"

echo "Xubuntu 24.04.5 LTS \"Noble Numbat\" - HDDLive (OpenSuperClone) amd64 ($(date +%Y%m%d))" > "$I/.disk/info"
log "boot menus OK (GRUB)"
