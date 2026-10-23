#!/bin/bash
# Runs INSIDE the chroot: extras of the "full kit" (merged tool lists + what already existed):
#  DMDE (4.4.4 stable + 4.5.0 beta, no license bundled), Double Commander, R-Linux, TestDisk/PhotoRec 7.2 (official static build),
#  smartmontools 7.5 (built from source), Clonezilla/partimage/rclone/ecryptfs/xfsdump/udftools/gpart/nbd-client, guides and self-test.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)
X=/root/extras
warn() { echo "!!! WARNING: $*"; }

echo "##### additional apt packages (available in noble) #####"
apt-get update >/dev/null 2>&1
inst_ex() { local a="" m="" c; for p in "$@"; do c=$(apt-cache policy "$p" 2>/dev/null | sed -n 's/^ *Candidate: //p'); if [ -n "$c" ] && [ "$c" != "(none)" ]; then a="$a $p"; else m="$m $p"; fi; done
  [ -n "$m" ] && echo "(no package in noble:$m)"
  [ -z "$a" ] && return 0
  "${APT[@]}" install $a || { warn "batch apt install failed; trying one by one"; for p in $a; do "${APT[@]}" install "$p" || warn "did not install: $p"; done; }; }
inst_ex clonezilla partimage rclone ecryptfs-utils xfsdump udftools gpart nbd-client
# (24.04) rescue/forensics/network tools that were not in the original list (whatever does not exist in noble is just listed)
inst_ex gdisk zfsutils-linux bcache-tools chntpw libimage-exiftool-perl pigz fdupes rdfind squashfs-tools cabextract 7zip mtools dosfstools   libbde-utils libvshadow-utils libvhdi-utils libvmdk-utils libqcow-utils libfsapfs-utils libfsntfs-utils libvslvm-utils libluksde-utils   recoverdm dd-rescue scrounge-ntfs smem sysstat iperf3 tcpdump lftp ranger ncurses-hexedit testdisk-doc exfat-fuse yara   e2fsprogs-l10n sleuthkit-doc tre-agrep ntfs-3g-dev
# ZFS: never import/mount pools on their own (rescue work must not write to disks unless the user asks)
systemctl mask zfs-import-cache.service zfs-import-scan.service zfs-mount.service zfs-share.service zfs-zed.service zfs-volume-wait.service zfs-import.target zfs.target sysstat.service 2>&1 | tail -2 || true

echo "##### remove LibreOffice #####"
LO=$(dpkg-query -W -f='${Package}\n' 'libreoffice*' 2>/dev/null | sort -u | tr '\n' ' ')
if [ -n "$LO" ]; then
  # the xubuntu-desktop meta dependencies become MANUAL (otherwise purging LibreOffice would drag the meta along and a later autoremove would take Xfce)
  for M in xubuntu-desktop xubuntu-desktop-minimal xubuntu-core; do
    dpkg -s "$M" >/dev/null 2>&1 && apt-mark manual $(apt-cache depends "$M" 2>/dev/null | awk '/Depends:/ {print $2}' | grep -v -E 'libreoffice|^<') >/dev/null 2>&1
  done
  SIM=$(apt-get -s purge $LO 2>/dev/null | awk '/^(Remv|Purg)/ {print $2}')
  BAD=$(echo "$SIM" | grep -v -E '^(libreoffice|xubuntu-desktop|xubuntu-desktop-minimal|python3-uno|uno-libs|ure|libuno|fonts-opensymbol)' || true)
  if [ -n "$BAD" ]; then echo "WARNING: purging LibreOffice would remove other packages (kept): $BAD"
  else "${APT[@]}" purge $LO >/dev/null 2>&1 && echo "LibreOffice removed ($(echo $SIM | wc -w) packages)"; fi
fi
dpkg -l 'libreoffice*' 2>/dev/null | grep -c '^ii' | sed 's/^/remaining libreoffice packages: /'

echo "##### remove Portuguese language packs (English-only image) #####"
PTP=$(dpkg-query -W -f='${Package}\n' 'language-pack-pt*' 'language-pack-gnome-pt*' 'firefox-l10n-pt*' 'libreoffice-l10n-pt*' 'hunspell-pt*' 'hyphen-pt*' 'mythes-pt*' 'wbrazilian' 'wportuguese' 'manpages-pt*' 'ibrazilian' 'iportuguese' 2>/dev/null | sort -u | tr '\n' ' ')
if [ -n "$PTP" ]; then "${APT[@]}" purge $PTP >/dev/null 2>&1 && echo "removed: $PTP"; fi
rm -rf /usr/share/locale/pt /usr/share/locale/pt_BR /usr/share/locale-langpack/pt /usr/share/locale-langpack/pt_BR 2>/dev/null
echo "##### DMDE: 4.4.4 (stable) + 4.5.0 beta (GTK3: 24.04 has GLIBC 2.39) #####"
for pair in "dmde:dmde-4-4-4-842-lin64-gui.zip" "dmde-beta:dmde-4-5-0-849-beta-lin64-gtk3.zip"; do
  d=/opt/${pair%%:*}; z=$X/${pair##*:}
  [ -s "$z" ] || { warn "missing $z"; continue; }
  # CAUTION: /usr/local/bin/dmde may be a SYMLINK to the binary itself (older versions of this script): remove it BEFORE writing the wrapper,
  # otherwise the `>` overwrites /opt/dmde/dmde with the wrapper (which calls itself in an endless loop and never opens a window).
  rm -f "/usr/local/bin/${pair%%:*}"
  rm -rf "$d"; mkdir -p "$d"; unzip -q "$z" -d "$d"; chmod 755 "$d/dmde"
  file "$d/dmde" | grep -q ELF || warn "$d/dmde is not an ELF binary!"
  ldd "$d/dmde" | grep 'not found' && warn "$d has missing libs" || echo "$d: libs ok"
  # DMDE only starts with the working directory = its own folder (from any other cwd it exits silently)
  printf '#!/bin/sh\ncd %s || exit 1\nexec ./dmde "$@"\n' "$d" > "/usr/local/bin/${pair%%:*}"
  chmod 755 "/usr/local/bin/${pair%%:*}"
done
# No license is installed: DMDE runs as Free Edition. A user can enter their own license in the program (it is lost when the live session ends).

echo "##### HDDSuperClone 2.3.3.pro (legacy) + HDDSCViewer 1.0 + 47 hddscripts (optional) #####"
# OpenSuperClone already ships the equivalents (opensuperclone, oscviewer and /usr/bin/oscscripts/*.osc), but the ORIGINAL modules are
# kept as a fallback, with the same paths as the original installer (/usr/local/bin/hddsuperclone, hddscviewer, hddscripts/).
# They come from the original HDDLive ISO (see 02-download.sh) and are proprietary/freeware (EULA in /usr/local/share/doc/hddsuperclone/EULA.txt).
if [ -s /root/extras-new/legacy-hddsuperclone-2.3.3.tar.gz ]; then
  tar xzf /root/extras-new/legacy-hddsuperclone-2.3.3.tar.gz -C / && chmod 755 /usr/local/bin/hddsuperclone /usr/local/bin/hddscviewer
  ldd /usr/local/bin/hddsuperclone | grep 'not found' && warn "legacy hddsuperclone has missing libs" || echo "legacy hddsuperclone: libs ok"
  /usr/local/bin/hddsuperclone --version 2>&1 | head -1; ls /usr/local/bin/hddscripts | wc -l
else echo "(legacy HDDSuperClone not provided: skipped)"; fi

echo "##### Double Commander 1.2.9 (gtk2) #####"
rm -rf /opt/doublecmd; tar xJf "$X/doublecmd-1.2.9.gtk2.x86_64.tar.xz" -C /opt; chmod 755 /opt/doublecmd/doublecmd
ln -sf /opt/doublecmd/doublecmd /usr/local/bin/doublecmd
cat > /usr/share/applications/doublecmd.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Double Commander
GenericName=File Manager
Comment=Two-panel file manager
Exec=/opt/doublecmd/doublecmd %F
Icon=/opt/doublecmd/doublecmd.png
Terminal=false
Categories=Utility;FileTools;FileManager;
EOF
ldd /opt/doublecmd/doublecmd | grep 'not found' && warn "doublecmd has missing libs" || echo "doublecmd: libs ok"

echo "##### R-Linux 6 #####"
if [ -s "$X/RLinux6_x64.deb" ]; then "${APT[@]}" install "$X/RLinux6_x64.deb" || warn "R-Linux did not install"; ls /usr/local/R-Linux/bin 2>/dev/null | tr '\n' ' '; echo
else warn "RLinux6_x64.deb missing"; fi

echo "##### TestDisk/PhotoRec 7.2 (official static binaries) #####"
if [ -s "$X/testdisk-7.2.linux26-x86_64.tar.bz2" ]; then
  rm -rf /opt/testdisk-7.2; mkdir -p /opt; tar xjf "$X/testdisk-7.2.linux26-x86_64.tar.bz2" -C /opt
  for t in testdisk photorec fidentify; do ln -sf "/opt/testdisk-7.2/${t}_static" "/usr/local/bin/$t"; done
  /usr/local/bin/testdisk --version 2>&1 | head -2
else warn "testdisk 7.2 missing"; fi

echo "##### smartmontools 7.5 (built into /usr/local) #####"
if [ -s "$X/smartmontools-7.5.tar.gz" ]; then
  B=/usr/src/smart-build; rm -rf $B; mkdir -p $B; tar xzf "$X/smartmontools-7.5.tar.gz" -C $B; cd $B/smartmontools-7.5
  if ./configure --prefix=/usr/local --sysconfdir=/etc --with-systemdsystemunitdir=no --with-initscriptdir=no >/tmp/smart-conf.log 2>&1 \
     && make -j"$(nproc)" >/tmp/smart-make.log 2>&1 && make install >/tmp/smart-inst.log 2>&1; then
    /usr/local/sbin/smartctl --version | head -1
  else warn "smartmontools 7.5 did not build (apt's 7.1 stays)"; tail -5 /tmp/smart-make.log; fi
  cd /; rm -rf $B
else warn "smartmontools-7.5 missing"; fi
# monitoring services stay disabled (they must not touch disks on their own)
systemctl mask smartmontools.service smartd.service 2>/dev/null || true

echo "##### guides and self-test #####"
G=/usr/share/hddlive/cheatsheets; rm -rf $G; mkdir -p $G
cat > $G/1-clone-first.txt <<'EOF'
CLONE FIRST (bench rule: preserve before touching anything)
=============================================================
Never mount or repair the ORIGINAL failing disk. Clone it to another disk/file and work on the COPY.

OpenSuperClone (shortcut "OpenSuperClone"): source = bad disk, destination = image file or a good disk (same size or larger).
  Virtual driver (modprobe oscdriver) and direct AHCI/IDE access: see the program's own manual. Secure Boot must be OFF.
GNU ddrescue 1.30 (terminal) - 3 passes:
  sudo ddrescue -f -n   /dev/sdX  image.img  map.log      # pass 1: fast, skips bad areas
  sudo ddrescue -f -d -r3 /dev/sdX image.img map.log      # pass 2: direct reads + 3 retries
  ddrescueview map.log                                    # watch progress
The map (mapfile) lets you stop and resume. ALWAYS keep the map together with the image.
Guymager: forensic image (.E01/.dd) with hashes. dc3dd/dcfldd: dd with hashing/log.
rclone 1.75: copy images/files to cloud/SFTP/SMB (rclone config; rclone copy image.img remote:folder).
Partclone/FSArchiver/Clonezilla: for HEALTHY disks (backup/migration). On a disk with read errors start with ddrescue/OpenSuperClone.
Disable a SATA port at boot (keeps Linux from touching the bad drive): boot menu entry "disable ataX" (edit X).
EOF
cat > $G/2-raid-lvm-crypto.txt <<'EOF'
RAID / LVM / ENCRYPTION (read-only access)
===========================================
This image does NOT assemble RAID/volumes by itself. Do it by hand, always read-only:
mdadm:     sudo mdadm --examine /dev/sdX1
           sudo mdadm --assemble --scan --readonly        # assemble the array read-only
LVM:       sudo vgscan ; sudo vgchange -ay ; sudo lvs      # then: sudo mount -o ro /dev/VG/LV /mnt
LUKS:      sudo cryptsetup open --readonly /dev/sdX1 name  # asks for the passphrase; needs the correct key/passphrase
BitLocker: sudo mkdir -p /mnt/bl /mnt/x ; sudo dislocker -V /dev/sdX1 -u -- /mnt/bl ; sudo mount -o ro,loop /mnt/bl/dislocker-file /mnt/x
exFAT/NILFS2: mkfs.exfat / fsck.exfat / tune.exfat (exfatprogs 1.4.3);  mkfs.nilfs2 / nilfs-tune (nilfs-utils 2.3.1)
NTFS (new tools): ntfsclone, ntfsundelete, ntfsfix, ntfsinfo... v2026.9.28 in /usr/local/bin (mount.ntfs-3g is still Ubuntu's)
Multipath: installed but OFF (multipathd masked) so it does not claim disks.
Btrfs:     sudo mount -o ro,rescue=all /dev/sdX1 /mnt      # or  btrfs restore /dev/sdX1 /dest  (btrfs-progs 7.1)
XFS/ext4:  sudo mount -o ro,norecovery /dev/sdX1 /mnt      # norecovery does not replay the journal (no writes)
ZFS:       sudo zpool import -o readonly=on -R /mnt/z POOL  (automatic import is OFF in this image)
Images:    sudo qemu-nbd --read-only -c /dev/nbd0 disk.vmdk ; sudo mount -o ro /dev/nbd0p1 /mnt   (modprobe nbd first)
EOF
cat > $G/3-analyze-images.txt <<'EOF'
ANALYZE IMAGES / FORENSICS
===========================
Sleuth Kit:   mmls image.img ; fls -r -o <start_sector> image.img ; icat -o <sector> image.img <inode> > file
E01/EWF:      ewfinfo img.E01 ; ewfverify img.E01 ; ewfmount img.E01 /mnt/ewf   (creates /mnt/ewf/ewf1)
Mount image:  sudo losetup -r -P -f --show image.img   (then: sudo mount -o ro /dev/loopXp1 /mnt)
Carving:      photorec /d out image.img  |  foremost -i image.img -o out  |  scalpel -o out image.img
bulk_extractor: bulk_extractor -o out image.img   (e-mails, URLs, cards, etc.; v2.2.0)
binwalk:      binwalk -e file_or_image   (signatures/firmware)
libguestfs:   guestfish --ro -a disk.vmdk -i  |  virt-ls / virt-cat / virt-df -a disk.qcow2   (VM images, read-only)
Sleuth Kit 4.15 and the new libewf live in /usr/local (they win over apt's in PATH).
Autopsy 4.23.1: only in the "full" build (not in this ISO). Needs lots of RAM; save cases outside the live session.
Hex:          wxHexEditor (GUI)  |  hexedit / dhex / bvi (terminal)  |  ghex
Deleted files on ext: extundelete / ext4magic (old tools: not a universal solution)
Photos: recoverjpeg ;  videos/files by type: magicrescue
EOF
cat > $G/4-repair-safely.txt <<'EOF'
REPAIR SAFELY
==============
1. Clone the disk (ddrescue/OpenSuperClone) and work on the COPY.
2. First only diagnose (no writes):
     sudo fsck -n /dev/sdX1          (ext*)         sudo ntfsfix -n /dev/sdX1      (NTFS, dry run)
     sudo xfs_repair -n /dev/sdX1    (XFS)          sudo btrfs check --readonly /dev/sdX1
     sudo testdisk /list /dev/sdX    (list partitions)
3. Only after confirming on the copy: fsck -y / ntfsfix / testdisk (rewrite table) / GParted.
4. GParted only on a disk you accept to lose: partition operations WRITE.
5. oscscripts/hddscripts (erase, ATA security, ROM patch) are DESTRUCTIVE.
EOF
cat > $G/5-scripts.txt <<'EOF'
OPENSUPERCLONE SCRIPTS (.osc) AND OLD HDDSUPERCLONE SCRIPTS (hddscripts)
=========================================================================
WHERE THEY ARE
  /usr/bin/oscscripts/            OpenSuperClone .osc scripts (65 files)
  /usr/bin/oscscripts/myscripts/  your own scripts (create them here)
  /usr/local/bin/hddscripts/      47 shell scripts of the original HDDSuperClone 2.3.3 (legacy)
  Shortcuts: folder 7-Scripts-and-Legacy on the Desktop.

HOW TO USE
  - Open OpenSuperClone (or OpenSuperTool: sudo opensuperclone --tool), pick the disk and use the scripts menu
    (hddmenu / hddsubmenu_*). The scripts run ATA/SCSI commands on the selected disk.
  - The legacy HDDSuperClone (sudo hddsuperclone) uses the scripts in /usr/local/bin/hddscripts.
  - Do not use both programs on the same disk at the same time.

GROUPS (file names)
  ata_identify_device, ata_scan_device, ata_smart_data, ata_status ....... information (safe)
  ata28_/ata48_read_sectors_pio|dma, ata28_readlong, ata_sct_readlong ..... sector reads
  ata28_/ata48_write_*, ata*_erase_*, ata28_makebad, ata48_write_uncorrectable  WRITE to the disk (DESTRUCTIVE)
  ata_security_set_password|remove_password|unlock ........................ ATA password (can LOCK the disk)
  ata_enable|disable_look_ahead, ata_idle_immediate_unload, ata_rebuild_assist_*, reset, reset_hard
  seagate_f3_*  (OpenSuperClone only) ........ glist, SMART, spin up/down, tune for imaging, regen translator (change firmware/state)
  wd_royl_*, wd_dump_mod42 ................. Western Digital ROM/modules (patch/write = DESTRUCTIVE)
  hddmenu, hddsubmenu_* ..................... menus

RULES
  1. Run scripts that WRITE only on a cloned/disposable disk.
  2. Check the disk first with: lsblk -o NAME,SIZE,MODEL,SERIAL
  3. Firmware scripts (seagate_f3_*, wd_royl_*) only with the right model and a ROM backup.
EOF
cat > $G/6-cli-tools.txt <<'EOF'
COMMAND-LINE TOOLS (all already installed) - quick examples
============================================================
(use sudo; replace /dev/sdX with the right disk: lsblk -o NAME,SIZE,MODEL,SERIAL)
CLONE/IMAGE
  ddrescue -f -n /dev/sdX img.img map.log ; ddrescue -f -d -r3 /dev/sdX img.img map.log ; ddrescuelog -t map.log
  ddru_findbad (affected files) | safecopy | dc3dd | dcfldd | recoverdm | partclone.extfs|ntfs|fat|btrfs -c -s /dev/sdX1 -o img
  fsarchiver savefs img.fsa /dev/sdX1 | ewfacquire /dev/sdX | ewfverify img.E01 | ewfmount img.E01 /mnt | xmount | qemu-nbd
RECOVER
  testdisk /dev/sdX | photorec img.img | foremost -i img -o out | scalpel img | bulk_extractor -o out img | recoverjpeg
  ntfsundelete /dev/sdX1 | ntfsclone | extundelete | ext4magic | scrounge-ntfs | fatcat | exiftool | binwalk | yara
DIAGNOSTICS
  smartctl -a /dev/sdX ; smartctl -t short /dev/sdX ; smartctl --scan | hdparm -I /dev/sdX | nvme smart-log /dev/nvme0
  sg_inq|sg_logs|sg_readcap /dev/sdX | sdparm /dev/sdX | lsscsi | lsblk | lshw -short | inxi -F | dmidecode | sensors
  fio | stress-ng | memtester 1024 1 | f3probe /dev/sdX (fake flash drive?) | badblocks -sv /dev/sdX (read-only)
FILE SYSTEMS (on a COPY only!)
  fsck -n | e2fsck -n | ntfsfix -n | xfs_repair -n | btrfs check --readonly | btrfs restore /dev/sdX1 /dest | debugfs
RAID / LVM / ENCRYPTION
  mdadm --examine /dev/sdX1 ; mdadm --assemble --scan --readonly | vgscan ; vgchange -ay | cryptsetup luksOpen /dev/sdX1 name
  dislocker -V /dev/sdX1 -u -- /mnt/bl (BitLocker) | zpool import -o readonly=on -R /mnt/z pool | kpartx -av img
FORENSICS (Sleuth Kit)
  mmls img | fsstat -o OFFSET img | fls -r -o OFFSET img | icat -o OFFSET img INODE > file | tsk_recover -o OFFSET img out | mactime
NETWORK / UPLOAD
  rclone config ; rclone copy /source remote:folder | sshfs user@host:/dir /mnt | rsync -avP | mount.cifs | nfs
WIPE (DESTRUCTIVE)
  nwipe | wipe | shred | hdparm --security-erase (careful!)
See also: guides 1 to 7 and the DOCUMENTACAO-COMPLETA-HDDLIVE-24.04.md document in the repository.
EOF
cat > $G/7-recover-files.txt <<'EOF'
RECOVER FILES - which tool to use
==================================
0. ALWAYS work on an image/clone (guide 1). Recovery destination = ANOTHER disk.
1. Partition vanished / disk "unformatted"           -> TestDisk (or DMDE: Partitions > full scan)
2. Deleted files, file system OK                      -> DMDE, R-Studio, UFS Explorer, R-Linux (ext), ntfsundelete, extundelete
3. Formatted / file system destroyed                  -> DMDE (full scan), R-Studio, UFS Explorer; then PhotoRec/QPhotoRec
4. Only photos/videos from a memory card              -> PhotoRec/QPhotoRec, recoverjpeg/recovermov, Foremost/Scalpel
5. RAID / NAS                                         -> folder 4 (assemble read-only), then DMDE/R-Studio/UFS (they rebuild RAID)
6. Which files were hit by the bad sectors            -> ddru_findbad (ddrescue mapfile)
7. Copy the result                                    -> Double Commander
Tip: DMDE and R-Studio show names and folders; PhotoRec does not (files like f1234.jpg) but finds more on a destroyed FS.
EOF
chmod 644 $G/*.txt

cat > /usr/local/bin/hddlive-install <<'HDDLIVE_INSTALL_EOF'
#!/bin/bash
# hddlive-install - copy the running HDDLive live system to a disk so it becomes permanent (BIOS/Legacy + UEFI).
# It ERASES the chosen disk. Run it from the live session:  sudo hddlive-install [DISK] [--user NAME] [--hostname NAME] [--yes]
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: sudo hddlive-install [DISK] [options]
  DISK                 target disk, e.g. /dev/sdb or /dev/nvme0n1 (asked interactively if omitted)
  --user NAME          user account to create (asked if omitted)
  --hostname NAME      machine name (default: hddlive)
  --squashfs PATH      path of casper/filesystem.squashfs (auto-detected in the live media)
  --yes                skip the final "type the device and ERASE" confirmation (passwords are still asked)
  -h, --help           this help

Layout created on the target: GPT with a 2 MiB bios_grub partition, a 512 MiB EFI System Partition and the rest as ext4 (root).
GRUB is installed for BOTH Legacy/BIOS and UEFI (normal UEFI entry + removable fallback). os-prober is disabled in the installed
system so it never probes other disks on its own. Bench protections (no auto-mount, RAID/ZFS not auto-assembled) are kept.
USAGE
}

DISK=""; USERN=""; HOSTN="hddlive"; SQ=""; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --user) USERN="${2:-}"; shift 2 ;;
    --hostname) HOSTN="${2:-}"; shift 2 ;;
    --squashfs) SQ="${2:-}"; shift 2 ;;
    --yes) YES=1; shift ;;
    -*) echo "unknown option: $1"; usage; exit 2 ;;
    *) DISK="$1"; shift ;;
  esac
done

[ "$(id -u)" -eq 0 ] || exec sudo -E bash "$0" "$@"
die() { echo "ERROR: $*" >&2; exit 1; }
for t in parted mkfs.ext4 mkfs.vfat unsquashfs grub-install lsblk blkid chroot; do command -v "$t" >/dev/null 2>&1 || die "missing tool: $t"; done

# ---- 1. find the system image
if [ -z "$SQ" ]; then
  for c in /cdrom/casper/filesystem.squashfs /run/live/medium/casper/filesystem.squashfs /lib/live/mount/medium/casper/filesystem.squashfs; do
    [ -f "$c" ] && { SQ="$c"; break; }
  done
fi
[ -n "$SQ" ] && [ -f "$SQ" ] || die "filesystem.squashfs not found. If you booted with 'load into RAM', mount the USB stick and pass --squashfs /path/casper/filesystem.squashfs"
echo "System image: $SQ ($(du -h "$SQ" | cut -f1))"

# disk that holds the live media (never offered as a target)
LIVEDISK=""
SRC=$(findmnt -no SOURCE -T "$SQ" 2>/dev/null || true)
if [ -b "${SRC:-}" ]; then LIVEDISK=$(lsblk -no PKNAME "$SRC" 2>/dev/null | head -n1); [ -n "$LIVEDISK" ] && LIVEDISK="/dev/$LIVEDISK"; fi

# ---- 2. choose the disk
list_disks() {
  printf '\n%-16s %-8s %-28s %-18s %-6s %s\n' DEVICE SIZE MODEL SERIAL TRAN NOTES
  lsblk -dpno NAME,SIZE,MODEL,SERIAL,TRAN,TYPE 2>/dev/null | awk '$NF=="disk"' | while read -r line; do
    dev=$(echo "$line" | awk '{print $1}')
    [ "$dev" = "$LIVEDISK" ] && note="<- live media (not allowed)" || note=""
    mp=$(lsblk -nro MOUNTPOINT "$dev" 2>/dev/null | grep -c .)
    [ "$mp" -gt 0 ] && note="$note mounted partitions"
    printf '%-16s %s\n' "$dev" "$(echo "$line" | cut -d' ' -f2-) $note"
  done
  echo
}
echo "Disks seen by this system (the target will be COMPLETELY ERASED):"; list_disks
[ -n "$DISK" ] || { read -r -p "Target disk (for example /dev/sdb): " DISK; }
[ -b "$DISK" ] || die "$DISK is not a block device"
[ "$(lsblk -dno TYPE "$DISK")" = "disk" ] || die "$DISK is not a whole disk (give the disk, not a partition)"
[ "$DISK" != "$LIVEDISK" ] || die "$DISK holds the live media; choose another disk"
if lsblk -nro MOUNTPOINT "$DISK" | grep -q .; then die "$DISK has mounted partitions; unmount them first (and make sure it is the right disk!)"; fi
SIZE_B=$(blockdev --getsize64 "$DISK"); [ "$SIZE_B" -ge $((12*1024*1024*1024)) ] || die "$DISK is smaller than 12 GB"

# ---- 3. account data (asked BEFORE anything is erased)
[ -n "$USERN" ] || read -r -p "User name to create (lowercase, e.g. tech): " USERN
echo "$USERN" | grep -Eq '^[a-z_][a-z0-9_-]{0,30}$' || die "invalid user name"
[ -n "$HOSTN" ] || HOSTN=hddlive
echo "$HOSTN" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9-]{0,62}$' || die "invalid host name"
read -r -s -p "Password for $USERN: " PW1; echo; read -r -s -p "Repeat the password: " PW2; echo
[ -n "$PW1" ] && [ "$PW1" = "$PW2" ] || die "passwords are empty or do not match"

# ---- 4. confirmation
MODEL=$(lsblk -dno MODEL,SIZE,SERIAL "$DISK" | xargs)
echo
echo "About to ERASE $DISK ($MODEL) and install HDDLive: user=$USERN host=$HOSTN"
if [ "$YES" -ne 1 ]; then
  read -r -p "Type the device path ($DISK) to continue: " A; [ "$A" = "$DISK" ] || die "cancelled"
  read -r -p "Type ERASE to confirm: " A; [ "$A" = "ERASE" ] || die "cancelled"
fi

# ---- 5. install
T=/target; EFI=0; [ -d /sys/firmware/efi ] && EFI=1
case "$DISK" in *[0-9]) P="${DISK}p" ;; *) P="$DISK" ;; esac
cleanup() { umount -R "$T" 2>/dev/null; }
trap cleanup EXIT
step() { echo; echo "== $*"; }

step "Partitioning $DISK (GPT: bios_grub + EFI + root)"
wipefs -a "$DISK" >/dev/null 2>&1
parted -s "$DISK" mklabel gpt mkpart bios 1MiB 3MiB set 1 bios_grub on mkpart ESP fat32 3MiB 515MiB set 2 esp on mkpart root ext4 515MiB 100% || die "partitioning failed"
partprobe "$DISK" 2>/dev/null; udevadm settle; sleep 2
[ -b "${P}2" ] && [ -b "${P}3" ] || die "partitions did not appear (${P}2 / ${P}3)"
mkfs.vfat -F32 "${P}2" >/dev/null || die "mkfs.vfat failed"
mkfs.ext4 -q -L hddlive "${P}3" || die "mkfs.ext4 failed"

step "Copying the system (a few minutes)"
mkdir -p "$T"; mount "${P}3" "$T" || die "mount root failed"
mkdir -p "$T/boot/efi"; mount "${P}2" "$T/boot/efi" || die "mount ESP failed"
unsquashfs -f -d "$T" "$SQ" || die "copy failed"

step "Configuring"
UR=$(blkid -s UUID -o value "${P}3"); UE=$(blkid -s UUID -o value "${P}2")
printf 'UUID=%s / ext4 defaults 0 1\nUUID=%s /boot/efi vfat umask=0077 0 1\n' "$UR" "$UE" > "$T/etc/fstab"
echo "$HOSTN" > "$T/etc/hostname"
grep -q "127.0.1.1" "$T/etc/hosts" 2>/dev/null && sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $HOSTN/" "$T/etc/hosts" || echo "127.0.1.1 $HOSTN" >> "$T/etc/hosts"
for d in dev dev/pts proc sys run; do mount --bind "/$d" "$T/$d"; done
chroot "$T" useradd -m -s /bin/bash -G sudo,adm,plugdev,dialout,cdrom,disk "$USERN" || die "useradd failed"
printf '%s:%s\n' "$USERN" "$PW1" | chroot "$T" chpasswd || die "chpasswd failed"
# the installed system must not probe other disks on its own (rescue machine): keep os-prober off
grep -q '^GRUB_DISABLE_OS_PROBER' "$T/etc/default/grub" 2>/dev/null && sed -i 's/^GRUB_DISABLE_OS_PROBER.*/GRUB_DISABLE_OS_PROBER=true/' "$T/etc/default/grub" || echo 'GRUB_DISABLE_OS_PROBER=true' >> "$T/etc/default/grub"

step "Initramfs and GRUB (Legacy + UEFI)"
chroot "$T" update-initramfs -u -k all || die "update-initramfs failed"
chroot "$T" grub-install --target=i386-pc "$DISK" || echo "WARNING: BIOS/Legacy GRUB failed (UEFI boot may still work)"
NV=""; [ "$EFI" -eq 1 ] || NV="--no-nvram"
chroot "$T" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu $NV || echo "WARNING: UEFI GRUB failed"
chroot "$T" grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --no-nvram || true
chroot "$T" update-grub || die "update-grub failed"
sync

cleanup; trap - EXIT
echo
echo "DONE. HDDLive is installed on $DISK (user: $USERN)."
echo "Reboot, remove the live USB/DVD and boot from that disk (Legacy or UEFI)."
echo "Bench protections are kept; to restore normal behaviour: sudo rm /etc/udev/rules.d/99-disable-udisk-automount.rules"
HDDLIVE_INSTALL_EOF
chmod 755 /usr/local/bin/hddlive-install
cat > $G/8-install-to-disk.txt <<'EOF'
MAKE HDDLIVE PERMANENT: INSTALL TO A DISK, OR KEEP IT ON THE USB STICK
=======================================================================
This image has no graphical installer. Two supported ways:

1) INSTALL TO A DISK (internal HDD/SSD/NVMe or an external disk) - one command
     sudo hddlive-install                      (asks everything, shows the disks)
     sudo hddlive-install /dev/sdb --user tech --hostname hddlive
   * It ERASES the chosen disk COMPLETELY. Use an empty disk, NEVER the failing disk you are working on.
   * It refuses the disk that holds the live media and disks with mounted partitions.
   * Creates GPT (bios_grub + 512 MiB EFI + ext4 root), copies the system, creates your user, rebuilds the initramfs and installs
     GRUB for Legacy/BIOS AND UEFI. os-prober is disabled, so the installed system never probes other disks on its own.
   * If you booted with "load into RAM", mount the USB stick and add:  --squashfs /path/casper/filesystem.squashfs
   * After it finishes: reboot, remove the USB stick, boot from the disk. The bench protections stay on (no auto-mount, RAID/ZFS not
     assembled automatically). To get normal auto-mount back: sudo rm /etc/udev/rules.d/99-disable-udisk-automount.rules
   * The OpenSuperClone driver is built for the image kernel; if apt installs a newer kernel DKMS rebuilds it.

2) KEEP IT ON THE USB STICK WITH PERSISTENCE (settings, licenses, files survive reboots)
   a. Write the ISO to the stick (dd / Rufus DD mode). Free space remains after the image.
   b. Create a partition in the free space labeled casper-rw (replace sdX; check with lsblk first):
        sudo parted /dev/sdX mkpart persist ext4 <end-of-last-partition> 100%
        sudo mkfs.ext4 -L casper-rw /dev/sdX3
   c. Boot the entry "HDDLive - persistent (needs a partition labeled casper-rw)".
   Nothing is saved without that partition. Persistence keeps changes on the stick: do not use it for the failing customer's disk.
EOF

cat > /usr/local/bin/hddlive-selftest <<'EOF'
#!/bin/bash
# HDDLive self-test: checks that the tools are installed and that the GUIs open (needs a graphical session).
ok=0; bad=0
chk() { if eval "$2" >/dev/null 2>&1; then printf '  [ OK ] %s\n' "$1"; ok=$((ok+1)); else printf '  [FAIL] %s\n' "$1"; bad=$((bad+1)); fi; }
gui() { # gui <name> <command...> : opens it, waits 10s, checks the process is still alive, closes ONLY that program
  local n="$1"; shift
  local tgt="$1"; [ "$tgt" = sudo ] && tgt="$2"; tgt=$(basename "$tgt")
  [ -n "$tgt" ] || { printf '  [FAIL] GUI %s: empty command\n' "$n"; bad=$((bad+1)); return; }   # NEVER pkill -f with an empty pattern (kills the whole session)
  ( "$@" >/tmp/selftest-$n.log 2>&1 & echo $! >/tmp/selftest-$n.pid ); sleep 10
  # (kill -0 fails with EPERM on root processes started by sudo: use /proc)
  if [ -d "/proc/$(cat /tmp/selftest-$n.pid)" ]; then printf '  [ OK ] GUI %s opened\n' "$n"; ok=$((ok+1)); else printf '  [FAIL] GUI %s closed (log: /tmp/selftest-%s.log)\n' "$n" "$n"; bad=$((bad+1)); fi
  sudo -n pkill -x -- "$tgt" 2>/dev/null; pkill -x -- "$tgt" 2>/dev/null
  [ "$tgt" = gparted ] && sudo -n pkill -x gpartedbin 2>/dev/null
  [ "$tgt" = ufs-explorer-pro ] && sudo -n pkill -x ufs-explorer-pro-tls 2>/dev/null
  sleep 1
}
echo "== Kernel and driver"; uname -r
chk "oscdriver loadable (modprobe)" "sudo modprobe oscdriver && lsmod | grep -q oscdriver"
echo "== Versions"
for c in "opensuperclone --version" "oscviewer --version" "ddrescue --version" "smartctl --version" "testdisk --version" "hdparm -V" "nvme version" "doublecmd --help"; do
  b=${c%% *}; chk "$b" "command -v $b"; done
smartctl --version 2>/dev/null | head -1; ddrescue --version | head -1; opensuperclone --version 2>&1 | head -1
echo "== Installed programs"
for b in dmde dmde-beta rstudio hdsentinel photorec fidentify gparted guymager gsmartcontrol ddrescueview wxHexEditor clonezilla partclone.ext4 fsarchiver foremost scalpel sdparm sg_inq mdadm vgs cryptsetup dislocker mmls ewfinfo; do chk "$b" "command -v $b"; done
chk "R-Linux" "test -x /usr/local/R-Linux/bin/R-Linux"
[ -x /opt/autopsy/bin/autopsy ] && { chk "Autopsy 4.23.1 installed" "test -f /usr/lib/libtsk_jni.so"; chk "Java 17 (Autopsy JRE)" "java -version 2>&1 | grep -q 17"; }
[ -x /opt/ufs-explorer-pro/ufs-explorer-pro ] && chk "UFS Explorer installed" "true"
[ -x /usr/local/bin/hddsuperclone ] && { chk "HDDSuperClone legacy 2.3.3" "hddsuperclone --version 2>&1 | grep -q 2.3.3"; chk "HDDSCViewer legacy" "command -v hddscviewer"; }
[ -x /opt/ufs-explorer-pro/ufs-explorer-pro ] && chk "Sentinel License Manager active (UFS)" "systemctl is-active hasplmd"
chk "trusted launchers (no Untrusted warning)" "gio info -a metadata::xfce-exe-checksum ~/Desktop/06-GParted.desktop | grep -q checksum"
chk "hdparm 9.65" "hdparm -V 2>&1 | grep -q 9.65"
chk "mdadm 4.6" "mdadm --version 2>&1 | grep -q 4.6"
chk "nvme-cli 3.x" "nvme version 2>&1 | grep -q 'version 3'"
chk "Sleuth Kit 4.15" "mmls -V 2>&1 | grep -q 4.15"
chk "ddrescue 1.30" "ddrescue --version 2>&1 | grep -q 1.30"
chk "smartmontools 7.5" "smartctl --version 2>&1 | grep -q 'smartctl 7.5'"
chk "btrfs-progs 7.x" "btrfs --version 2>&1 | grep -q 'v7'"
chk "xfsprogs 7.x" "xfs_repair -V 2>&1 | grep -q 'version 7'"
chk "e2fsprogs 1.47.4" "e2fsck -V 2>&1 | grep -q 1.47.4"
chk "partclone 0.3.50" "partclone.extfs --version 2>&1 | grep -q 0.3.50"
chk "fsarchiver 0.8.9" "fsarchiver --version 2>&1 | grep -q 0.8.9"
chk "cryptsetup 2.8" "cryptsetup --version 2>&1 | grep -q 'cryptsetup 2.8'"
chk "ntfsclone 2026" "ntfsclone --version 2>&1 | grep -q 2026"
chk "bulk_extractor 2.2" "bulk_extractor -V 2>&1 | grep -q 2.2"
chk "GSmartControl 2.0 (/usr/local)" "test -x /usr/local/sbin/gsmartcontrol"
chk "ZFS (module and tools)" "command -v zpool && modinfo zfs"
chk "Firefox (Mozilla deb)" "command -v firefox && ! snap list firefox"
chk "anti-automount udev rule" "test -f /etc/udev/rules.d/99-disable-udisk-automount.rules"
chk "hddlive-install present and valid" "test -x /usr/local/bin/hddlive-install && bash -n /usr/local/bin/hddlive-install"
chk "English-only image (no Portuguese language packs)" "! dpkg -l 'language-pack-pt*' 2>/dev/null | grep -q '^ii'"
if [ -n "$DISPLAY" ]; then
  echo "== GUIs (opens each one for 10s)"
  gui dmde sudo /usr/local/bin/dmde
  gui doublecmd /opt/doublecmd/doublecmd
  gui gsmartcontrol sudo gsmartcontrol
  gui gparted sudo gparted
  gui guymager sudo guymager
  gui ddrescueview /opt/ddrescueview/ddrescueview
  gui wxHexEditor sudo wxHexEditor
  gui hardinfo hardinfo
  [ -x /opt/ufs-explorer-pro/ufs-explorer-pro ] && gui ufs-explorer /opt/ufs-explorer-pro/ufs-explorer-pro
  gui qphotorec sudo qphotorec
  [ -x /opt/autopsy/bin/autopsy ] && { gui autopsy /opt/autopsy/bin/autopsy --nosplash; pkill -f /opt/autopsy 2>/dev/null; }
  gui oscviewer oscviewer
  gui opensuperclone sudo opensuperclone
else echo "== (no DISPLAY: GUIs not tested)"; fi
echo; echo "Result: $ok OK, $bad failed"
EOF
chmod 755 /usr/local/bin/hddlive-selftest
echo "extras OK"
