#!/bin/bash
# Step 2: downloads the external programs and extracts from the old ISO whatever will be reused.
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/00-common.sh"
mkdir -p "$EXTRAS"
cd "$EXTRAS"

get() {  # get <url> <file>
  if [ -s "$2" ]; then log "already exists: $2"; return 0; fi
  log "downloading $2"
  curl -fL --retry 3 -A "Mozilla/5.0 Chrome/120" -o "$2.part" "$1" && mv "$2.part" "$2" || { log "FAILED: $1"; rm -f "$2.part"; return 1; }
}

OSC=https://github.com/ISpillMyDrink/OpenSuperClone/releases/download
get "$OSC/v2.6.0-alpha1/opensuperclone_2.6-1_amd64.deb"  opensuperclone_2.6-1_amd64.deb       # newest (alpha, 2026-07-24)
get "$OSC/v2.5.0/opensuperclone_2.5.0-1_amd64.deb"       opensuperclone_2.5.0-1_amd64.deb     # stable (fallback)
# the official 2.6 .deb requires GLIBC 2.34 (Ubuntu 22.04): on 20.04 we build from source (15-osc-build.sh)
get https://github.com/ISpillMyDrink/OpenSuperClone/archive/refs/tags/v2.6.0-alpha1.tar.gz osc-2.6.0-alpha1.tar.gz
get https://ftp.gnu.org/gnu/ddrescue/ddrescue-1.30.tar.lz                    ddrescue-1.30.tar.lz
get https://dmde.com/download/dmde-4-4-4-842-lin64-gui.zip                   dmde-4-4-4-842-lin64-gui.zip
# DMDE beta: the GTK3 build requires GLIBC 2.34 (does not run on focal); use the GTK2 build ("gui")
get https://dmde.com/download/dmde-4-5-0-849-beta-lin64-gui.zip              dmde-4-5-0-849-beta-lin64-gui.zip
get https://dmde.com/download/dmde-4-5-0-849-beta-lin64-gtk3.zip              dmde-4-5-0-849-beta-lin64-gtk3.zip
get https://www.hdsentinel.com/hdslin/hdsentinel-020c-x64.zip                hdsentinel-020c-x64.zip
get https://www.r-studio.com/downloads/RStudio5_x64.deb                      RStudio5_x64.deb || true
get https://github.com/doublecmd/doublecmd/releases/download/v1.2.9/doublecmd-1.2.9.gtk2.x86_64.tar.xz doublecmd-1.2.9.gtk2.x86_64.tar.xz
get https://www.r-studio.com/downloads/RLinux6_x64.deb                       RLinux6_x64.deb || true
get https://www.cgsecurity.org/testdisk-7.2.linux26-x86_64.tar.bz2           testdisk-7.2.linux26-x86_64.tar.bz2
get https://github.com/smartmontools/smartmontools/releases/download/RELEASE_7_5/smartmontools-7.5.tar.gz smartmontools-7.5.tar.gz
# ---- "missing" items (27-newer.sh): newer versions built/installed outside apt ----
get https://downloads.rclone.org/rclone-current-linux-amd64.zip              rclone-current-linux-amd64.zip
get "https://deb.debian.org/debian/pool/main/h/hdparm/hdparm_9.65+ds.orig.tar.xz" hdparm_9.65+ds.orig.tar.xz
get http://sg.danny.cz/sg/p/sg3_utils-1.49.tar.xz                            sg3_utils-1.49.tar.xz
get https://github.com/exfatprogs/exfatprogs/releases/download/1.4.3/exfatprogs-1.4.3.tar.xz exfatprogs-1.4.3.tar.xz
get https://github.com/nilfs-dev/nilfs-utils/archive/refs/tags/v2.3.1.tar.gz nilfs-utils-2.3.1.tar.gz
get https://github.com/simsong/bulk_extractor/releases/download/v2.2.0/bulk_extractor-2.2.0.tar.gz bulk_extractor-2.2.0.tar.gz
get https://github.com/linux-nvme/nvme-cli/archive/refs/tags/v3.1.tar.gz     nvme-cli-3.1.tar.gz
get https://github.com/md-raid-utilities/mdadm/archive/refs/tags/mdadm-4.6.tar.gz mdadm-4.6.tar.gz
get https://github.com/GNOME/gparted/archive/refs/tags/GPARTED_1_8_1.tar.gz   gparted-1.8.1.tar.gz
get https://github.com/ashaduri/gsmartcontrol/archive/refs/tags/v2.0.2.tar.gz gsmartcontrol-2.0.2.tar.gz
get https://github.com/sleuthkit/sleuthkit/releases/download/sleuthkit-4.15.0/sleuthkit-4.15.0.tar.gz sleuthkit-4.15.0.tar.gz
get https://tuxera.com/opensource/ntfs-3g_ntfsprogs-2026.9.28.tgz            ntfs-3g_ntfsprogs-2026.9.28.tgz
get https://github.com/libyal/libewf/releases/download/20260924/libewf-experimental-20260924.tar.gz libewf-experimental-20260924.tar.gz
get https://www.cgsecurity.org/testdisk-7.2.tar.bz2                          testdisk-7.2.tar.bz2
get https://www.cgsecurity.org/testdisk-7.3-WIP.linux26-x86_64.tar.bz2       testdisk-7.3-WIP.linux26-x86_64.tar.bz2
get https://www.sysdevlabs.com/download/ufsxpci.tar.xz                       ufsxpci.tar.xz
ls -la "$EXTRAS" | tee -a "$LOGS/build.log"

# --- (24.04) new sources built by 27-newer.sh (dl/extras-new) ---
XN="$DL/extras-new"; mkdir -p "$XN"
getn() { [ -s "$XN/$2" ] && { log "already have $2"; return; }; curl -fL -A "Mozilla/5.0" -o "$XN/$2.part" "$1" && mv "$XN/$2.part" "$XN/$2" || { log "FAILED $1"; return 1; }; }
getn https://mirrors.edge.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v7.1.tar.xz btrfs-progs-v7.1.tar.xz
getn https://mirrors.edge.kernel.org/pub/linux/utils/fs/xfs/xfsprogs/xfsprogs-7.2.1.tar.xz xfsprogs-7.2.1.tar.xz
getn https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.47.4/e2fsprogs-1.47.4.tar.xz e2fsprogs-1.47.4.tar.xz
getn https://github.com/Thomas-Tsai/partclone/archive/refs/tags/0.3.50.tar.gz partclone-0.3.50.tar.gz
getn https://github.com/fdupoux/fsarchiver/releases/download/0.8.9/fsarchiver-0.8.9.tar.gz fsarchiver-0.8.9.tar.gz
getn https://mirrors.edge.kernel.org/pub/linux/utils/cryptsetup/v2.8/cryptsetup-2.8.0.tar.xz cryptsetup-2.8.0.tar.xz

# --- original HDDSuperClone 2.3.3.pro (legacy) + HDDSCViewer + hddscripts: extracted from the old ISO (reproducible) ---
if [ ! -s "$XN/legacy-hddsuperclone-2.3.3.tar.gz" ] && [ -s "$OLD_ISO" ]; then
  log "extracting legacy HDDSuperClone from the old ISO"
  W="$DL/legacy-work"; rm -rf "$W"; mkdir -p "$W"
  xorriso -osirrox on -indev "$OLD_ISO" -extract /casper/filesystem.squashfs "$W/old.squashfs" >/dev/null 2>&1
  unsquashfs -f -d "$W/x" "$W/old.squashfs" usr/local/bin usr/local/share/doc >/dev/null 2>&1
  ( cd "$W/x" && tar czf "$XN/legacy-hddsuperclone-2.3.3.tar.gz" --owner=0 --group=0 usr/local/bin/hddsuperclone usr/local/bin/hddscviewer usr/local/bin/hddscripts usr/local/bin/hddsuperclone-uninstall.sh usr/local/bin/hddscviewer-uninstall.sh usr/local/share/doc/hddsuperclone usr/local/share/doc/hddscviewer )
  rm -rf "$W"
fi
ls -la "$XN" | tee -a "$LOGS/build.log"

# --- reuse from the old ISO: ddrescueview 0.4.5 (x86_64 binary + resources) ---
if [ ! -e "$OLD/ddrescueview-linux-x86_64/ddrescueview" ] && [ -s "$OLD_ISO" ]; then
  log "extracting ddrescueview from the old ISO"
  xorriso -osirrox on -indev "$OLD_ISO" -extract /casper/filesystem.squashfs "$DL/old-filesystem.squashfs" >/dev/null 2>&1
  unsquashfs -f -d "$OLD" "$DL/old-filesystem.squashfs" home/ddrescueview-linux-x86_64 >"$LOGS/unsquash-old.log" 2>&1
  rm -f "$DL/old-filesystem.squashfs"
fi
ls -la "$OLD/home/ddrescueview-linux-x86_64" 2>/dev/null || ls -la "$OLD"
log "STEP 2 (download) OK"
