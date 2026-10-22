#!/bin/bash
# Runs INSIDE the chroot: Desktop organized by category, udev rule, power/screen settings and README.
set -euo pipefail
D=/etc/skel/Desktop
rm -rf "$D"; mkdir -p "$D" /usr/share/hddlive

# mk <folder relative to $D ('.' = root)> <file> <Name> <Comment> <Exec> <Icon> <Terminal true|false>
mkcheck() { local c="$1" w; c="${c#sudo }"; w="${c%% *}"; case "$w" in bash|less|thunar|x-terminal-emulator|sh) return 0;; /*) [ -x "$w" ];; *) command -v "$w" >/dev/null 2>&1;; esac; }
mk() {
  local dir="$D/$1"
  mkcheck "$5" || { echo "(shortcut skipped, program not found: $5)"; return 0; }
  mkdir -p "$dir"
  cat > "$dir/$2.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$3
Comment=$4
Exec=$5
Icon=$6
Terminal=$7
Categories=Utility;
EOF
  chmod 755 "$dir/$2.desktop"
}
G=/usr/share/hddlive/cheatsheets
guide() { mk "$1" "$2" "$3" "Quick guide (read-only text)" "less $G/$4" text-x-generic true; }

DC=/opt/doublecmd/doublecmd.png
# cli <folder> <file> <Name> <icon> <line1> [line2 ...] : opens a terminal that SHOWS how to use the tool and leaves the prompt ready
cli() { local p="$1" f="$2" n="$3" i="$4"; shift 4; local ex="" l; for l in "$@"; do ex="$ex echo $l;"; done
  mk "$p" "$f" "$n" "Terminal tool (shows examples and opens the prompt)" "bash -c '$ex echo; exec bash'" "$i" true; }

# ================= ROOT: the most used =================
mk . 01-OpenSuperClone    "OpenSuperClone"           "Advanced cloning of failing drives (root)"   "sudo opensuperclone"                    drive-harddisk true
mk . 02-DMDE              "DMDE"                     "Data recovery / disk editor"                 "sudo dmde"                              drive-harddisk true
mk . 03-R-Studio          "R-Studio"                 "R-Studio data recovery"                      "sudo /usr/local/R-Studio/bin/R-Studio"  drive-harddisk false
mk . 04-UFS-Explorer      "UFS Explorer"             "SysDev data recovery (own license)"          "/opt/ufs-explorer-pro/ufs-explorer-pro"   drive-harddisk false
mk . 05-DoubleCommander   "Double Commander"         "Two-panel file manager"                      "/opt/doublecmd/doublecmd"               $DC false
mk . 06-GParted           "GParted"                  "Partition editor (writes to the disk!)"      "sudo gparted"                           gparted false
mk . 07-HDDSuperClone     "HDDSuperClone (legacy)"   "Original HDDSuperClone 2.3.3 (fallback)"     "sudo hddsuperclone"                     drive-harddisk true
mk . 08-Terminal          "Terminal"                 "Terminal"                                    "x-terminal-emulator"                    utilities-terminal false
mk . 90-SelfTest "HDDLive Self-Test" "Checks the tools, the driver and opens every GUI"   "bash -c 'hddlive-selftest; echo; read -p \"Press ENTER to close\"'" utilities-system-monitor true
mk . 91-DisableScreensaver "Disable Screensaver" "Turns off screen protection and DPMS" "bash -c 'xset -dpms; xset s off; pkill xscreensaver 2>/dev/null; xfce4-screensaver-command --exit 2>/dev/null; echo Screensaver OFF - re-enable: xset +dpms; xset s on; exec bash'" preferences-desktop-screensaver true
guide . 92-Command-Guide "Guide: ALL terminal commands" 6-cli-tools.txt

# ================= 1 Diagnose =================
P=1-Diagnose
mk $P 1-GSmartControl "GSmartControl"       "Disk SMART (graphical)"                    "sudo gsmartcontrol"                     drive-harddisk false
mk $P 2-HDSentinel    "Hard Disk Sentinel"  "Health and temperature (terminal)"         "bash -c 'sudo hdsentinel; echo; read -p \"Press ENTER to close\"'" utilities-terminal true
mk $P 3-GNOME-Disks   "Disks (GNOME Disks)" "SMART, benchmark, partitions, images"      "gnome-disks"                            gnome-disks false
mk $P 4-HardInfo      "HardInfo"            "Hardware information and benchmark"        "hardinfo"                               computer false
mk $P 5-CPU-X         "CPU-X"               "CPU, motherboard, RAM"                     "cpu-x"                                  computer false
mk $P 6-lshw          "Hardware (lshw-gtk)" "Lists all hardware"                        "sudo lshw-gtk"                          computer false
mk $P 7-List-disks    "List disks"          "lsblk + SMART scan + NVMe (terminal)"      "bash -c 'lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN,FSTYPE; echo; sudo smartctl --scan; echo; sudo nvme list; echo; read -p \"Press ENTER to close\"'" utilities-terminal true
cli $P 8-smartctl  "SMART in the terminal (smartctl)" utilities-terminal "smartctl - SMART of any disk" "  sudo smartctl -a /dev/sdX" "  sudo smartctl -t short /dev/sdX   short test" "  sudo smartctl -t long /dev/sdX    long test" "  sudo smartctl --scan"
cli $P 9-hdparm    "hdparm / sg3 / nvme (terminal)" utilities-terminal "hdparm - ATA: info and speed" "  sudo hdparm -I /dev/sdX   identify" "  sudo hdparm -tT /dev/sdX  speed" "sg3_utils: sudo sg_inq /dev/sdX ; sudo sg_readcap /dev/sdX ; sudo sg_logs /dev/sdX" "NVMe: sudo nvme smart-log /dev/nvme0"
cli $P 91-memtester "Test RAM (memtester)" computer "memtester - tests RAM from user mode" "  sudo memtester 2048 1    tests 2048 MB once" "For a full test use at boot: Test memory - BIOS only"
mk $P 92-TaskManager  "Task Manager" "CPU, memory, processes"                          "xfce4-taskmanager"                      utilities-system-monitor false

# ================= 2 Clone first =================
P=2-Clone-First
mk $P 1-OpenSuperClone "OpenSuperClone"   "Advanced cloning (root)"                   "sudo opensuperclone"                    drive-harddisk true
mk $P 2-OpenSuperTool  "OpenSuperTool"    "Tool mode (CLI)"                            "sudo opensuperclone --tool"             utilities-terminal true
mk $P 3-OSCViewer      "OSCViewer"        "View OpenSuperClone log/domain"             "oscviewer"                              applications-graphics false
mk $P 4-ddrescueview   "ddrescueview"     "View a ddrescue mapfile"                    "ddrescueview"                           applications-graphics false
mk $P 5-Guymager       "Guymager"         "Forensic imaging (E01/dd/AFF)"              "sudo guymager"                          drive-harddisk false
mk $P 6-Clonezilla     "Clonezilla"       "Image/clone HEALTHY disks (terminal)"       "sudo clonezilla"                        drive-harddisk true
cli $P 7-ddrescue      "ddrescue (terminal)" utilities-terminal "ddrescue - clones a failing disk, with a map" "  sudo ddrescue -f -n /dev/sdX img.img map.log       pass 1" "  sudo ddrescue -f -d -r3 /dev/sdX img.img map.log   retries" "  ddrescuelog -t map.log   statistics" "CAREFUL: source first, destination second"
cli $P 8-partclone     "Partclone / FSArchiver (terminal)" utilities-terminal "partclone - copies only the used blocks" "  sudo partclone.ntfs -c -s /dev/sdX1 -o img.pcl" "  sudo partclone.extfs -r -s img.pcl -o /dev/sdY1   restore" "fsarchiver: sudo fsarchiver savefs img.fsa /dev/sdX1"
cli $P 9-ewf           "EWF/E01 and dc3dd (terminal)" utilities-terminal "ewfacquire /dev/sdX   creates an E01 image" "ewfverify img.E01 ; ewfmount img.E01 /mnt/ewf" "dc3dd if=/dev/sdX of=img.dd hash=sha256 log=log.txt   forensic image"
guide $P 91-Guide-clone-first "Guide: clone first" 1-clone-first.txt
mk $P 92-HDDSuperClone-legacy "HDDSuperClone 2.3.3 (legacy)" "ORIGINAL program of the old HDDLive (fallback to OpenSuperClone)" "sudo hddsuperclone" drive-harddisk true
mk $P 93-HDDSuperTool-legacy  "HDDSuperTool (legacy)"        "Tool mode of the original HDDSuperClone" "sudo hddsuperclone --tool" utilities-terminal true
mk $P 94-HDDSCViewer-legacy   "HDDSCViewer (legacy)"         "Log viewer of the original HDDSuperClone" "hddscviewer" applications-graphics false

# ================= 3 Recover files =================
P=3-Recover-Files
mk $P 1-DMDE          "DMDE 4.4.4"        "Logical recovery, partitions, RAID, editor" "sudo dmde"                            drive-harddisk true
mk $P 2-DMDE-Beta     "DMDE 4.5.0 Beta"   "DMDE test version (GTK3)"                 "sudo dmde-beta"                         drive-harddisk true
mk $P 3-R-Studio      "R-Studio"          "Professional multi-filesystem recovery"     "sudo /usr/local/R-Studio/bin/R-Studio"  drive-harddisk false
mk $P 4-R-Linux       "R-Linux"           "ext2/3/4 recovery (free)"                   "sudo /usr/local/R-Linux/bin/R-Linux"    drive-harddisk false
mk $P 5-UFS-Explorer  "UFS Explorer Professional" "SysDev data recovery (own license required)" "/opt/ufs-explorer-pro/ufs-explorer-pro" drive-harddisk false
mk $P 6-QPhotoRec     "QPhotoRec 7.2"     "PhotoRec with a graphical interface"        "sudo qphotorec"                         drive-harddisk false
mk $P 7-TestDisk      "TestDisk 7.2"      "Recover partitions (terminal)"              "sudo testdisk"                          utilities-terminal true
mk $P 8-PhotoRec      "PhotoRec 7.2"      "Recover files by signature (terminal)"      "sudo photorec"                          utilities-terminal true
mk $P 9-TestDisk-WIP  "TestDisk 7.3-WIP"  "Development version (terminal)"             "sudo testdisk-wip"                      utilities-terminal true
mk $P 91-PhotoRec-WIP "PhotoRec 7.3-WIP"  "Development version (terminal)"             "sudo photorec-wip"                      utilities-terminal true
mk $P 92-DoubleCommander "Double Commander" "Copy recovered files"                     "/opt/doublecmd/doublecmd"               $DC false
cli $P 93-foremost     "Foremost / Scalpel (terminal)" utilities-terminal "signature carving" "  sudo foremost -i img.img -o out/" "  sudo scalpel img.img -o out/" "recoverjpeg: recoverjpeg img.img   photos ; recovermov img.img   videos"
cli $P 94-bulk         "bulk_extractor (terminal)" utilities-terminal "extracts e-mails, URLs, cards, phone numbers from the whole image" "  bulk_extractor -o out/ img.img"
cli $P 95-undelete     "Undelete NTFS/ext (terminal)" utilities-terminal "ntfsundelete: sudo ntfsundelete /dev/sdX1   lists deleted files" "extundelete: sudo extundelete /dev/sdX1 --restore-all" "ext4magic / scrounge-ntfs / fatcat are also installed"
guide $P 96-Guide-recovery "Guide: recover files" 7-recover-files.txt

# ================= 4 RAID / NAS / encryption =================
P=4-RAID-NAS-Encryption
guide $P 1-Guide-RAID-LVM-LUKS "Guide: RAID, LVM, LUKS, BitLocker" 2-raid-lvm-crypto.txt
mk $P 2-GNOME-Disks   "Disks (GNOME Disks)" "View volumes, LUKS, LVM"                   "gnome-disks"                            gnome-disks false
mk $P 3-Terminal-root "Terminal (root)"   "Root terminal for mdadm/lvm/cryptsetup"     "bash -c 'sudo -i'"                      utilities-terminal true
cli $P 4-mdadm        "Software RAID (mdadm)" utilities-terminal "mdadm - does NOT assemble by itself in this image" "  sudo mdadm --examine /dev/sdX1                member superblock" "  sudo mdadm --assemble --scan --readonly       assemble read-only" "  cat /proc/mdstat"
cli $P 5-lvm          "LVM" utilities-terminal "  sudo pvs ; sudo vgs ; sudo lvs" "  sudo vgchange -ay            activate volumes" "  sudo kpartx -av img.img      partitions of an image"
cli $P 6-cryptsetup   "LUKS / BitLocker (cryptsetup, dislocker)" utilities-terminal "LUKS: sudo cryptsetup luksOpen /dev/sdX1 name   ; header backup: sudo cryptsetup luksHeaderBackup" "BitLocker: sudo dislocker -V /dev/sdX1 -u -- /mnt/bl   ; then mount -o ro,loop /mnt/bl/dislocker-file /mnt/x"
cli $P 7-zfs          "ZFS (read-only)" utilities-terminal "  sudo zpool import                         lists pools" "  sudo zpool import -o readonly=on -R /mnt/z NAME" "automatic import is OFF in this image"

# ================= 5 Analyze images =================
P=5-Analyze-Images
mk $P 0-Autopsy       "Autopsy 4.23.1"    "Graphical forensic platform (Sleuth Kit 4.15; slow to open the 1st time)" "/opt/autopsy/bin/autopsy --nosplash" applications-system true
mk $P 1-wxHexEditor   "wxHexEditor"       "Hex editor for disks/images"                "sudo wxHexEditor"                       accessories-text-editor false
mk $P 2-GHex          "GHex"              "Simple hex editor"                          "ghex"                                   accessories-text-editor false
mk $P 3-Guymager      "Guymager"          "Forensic imaging"                           "sudo guymager"                          drive-harddisk false
mk $P 4-DoubleCommander "Double Commander" "Browse files"                              "/opt/doublecmd/doublecmd"               $DC false
cli $P 5-sleuthkit    "Sleuth Kit (terminal)" utilities-terminal "mmls img                    partitions" "fsstat -o OFFSET img         file system data" "fls -r -o OFFSET img         lists files, including deleted" "icat -o OFFSET img INODE > file   extracts" "tsk_recover -o OFFSET img out/   recovers deleted files"
cli $P 6-exiftool     "exiftool / binwalk / yara (terminal)" utilities-terminal "exiftool photo.jpg ; exiftool -r -ext jpg -DateTimeOriginal folder/" "binwalk file   ;   yara rules.yar file"
guide $P 7-Guide-analysis "Guide: Sleuth Kit, EWF, carving" 3-analyze-images.txt

# ================= 6 Repair safely =================
P=6-Repair-Safely
guide $P 1-Guide-repair "Guide: repair safely" 4-repair-safely.txt
mk $P 2-GParted       "GParted"           "Partition editor (writes to the disk!)"     "sudo gparted"                           gparted false
mk $P 3-TestDisk      "TestDisk"          "Repair the partition table"                 "sudo testdisk"                          utilities-terminal true
cli $P 4-safe-fsck    "Safe fsck (diagnose only)" utilities-terminal "ON A COPY ONLY. First diagnose without writing:" "  sudo e2fsck -n /dev/sdX1 ; sudo ntfsfix -n /dev/sdX1 ; sudo xfs_repair -n /dev/sdX1" "  sudo btrfs check --readonly /dev/sdX1 ; sudo fsck.exfat -n /dev/sdX1"
cli $P 5-gdisk        "gdisk / sgdisk (GPT)" utilities-terminal "  sudo gdisk -l /dev/sdX            lists GPT" "  sudo gdisk /dev/sdX   ; r  ; recovery/transformation   WRITES only with w"

# ================= 7 Scripts and original HDDSuperClone modules =================
P=7-Scripts-and-Legacy
mk $P 1-HDDSuperClone-legacy "HDDSuperClone 2.3.3 (legacy)" "ORIGINAL program of the old HDDLive (fallback to OpenSuperClone)" "sudo hddsuperclone" drive-harddisk true
mk $P 2-HDDSuperTool-legacy  "HDDSuperTool (legacy)"        "Tool mode of the original HDDSuperClone" "sudo hddsuperclone --tool" utilities-terminal true
mk $P 3-HDDSCViewer-legacy   "HDDSCViewer (legacy)"         "Log viewer of the original HDDSuperClone" "hddscviewer" applications-graphics false
mk $P 4-Scripts-OSC          "OpenSuperClone scripts (.osc)" "Folder /usr/bin/oscscripts: ATA, Seagate F3, WD royl, menus (DESTRUCTIVE: read the guide)" "thunar /usr/bin/oscscripts" folder false
mk $P 5-Scripts-legacy       "Old HDDSuperClone scripts (hddscripts)" "Folder /usr/local/bin/hddscripts (47 shell scripts)" "thunar /usr/local/bin/hddscripts" folder false
mk $P 6-My-OSC-scripts       "My OSC scripts (myscripts)" "Put your own .osc scripts here" "thunar /usr/bin/oscscripts/myscripts" folder false
guide $P 7-Guide-scripts "Guide: OpenSuperClone and HDDSuperClone scripts" 5-scripts.txt

# ================= 8 Network and internet =================
P=8-Network-Internet
mk $P 1-Firefox        "Firefox"            "Web browser"                                "firefox"                                web-browser false
mk $P 2-Connections    "Network connections" "Edit Wi-Fi/cable/VPN"                      "nm-connection-editor"                   network-wired false
cli $P 3-rclone        "rclone (cloud)" utilities-terminal "rclone config                         sets up Google Drive, OneDrive, S3, SFTP..." "rclone copy /source remote:folder -P     uploads" "rclone ls remote:"
cli $P 4-sshfs         "Mount a server (sshfs / SMB / NFS)" utilities-terminal "  mkdir -p /mnt/srv ; sshfs user@host:/folder /mnt/srv" "  sudo mount -t cifs //host/share /mnt/srv -o username=USER" "  sudo mount -t nfs host:/folder /mnt/srv"
cli $P 5-ssh           "Turn SSH on (remote access)" utilities-terminal "SSH is OFF by default. To turn it on:" "  sudo passwd xubuntu ; sudo systemctl start ssh" "Screen VNC: x11vnc -display :0 -passwd PASSWORD"
mk $P 6-Sound          "Volume (pavucontrol)" "Audio control"                            "pavucontrol"                            audio-volume-high false

# ================= 9 Utilities =================
P=9-Utilities
mk $P 1-Baobab         "Disk usage (Baobab)" "What is using the space"                   "baobab"                                 drive-harddisk false
mk $P 2-Mousepad       "Mousepad"           "Text editor"                                "mousepad"                               accessories-text-editor false
mk $P 3-Ristretto      "Ristretto"          "Image viewer"                               "ristretto"                              image-x-generic false
mk $P 4-Xfburn         "Xfburn"             "Burn CD/DVD"                                "xfburn"                                 media-optical false
mk $P 5-ScreenRecorder "Screen recorder"    "Record the service session"                 "simplescreenrecorder"                   applications-multimedia false
mk $P 6-Gromit         "Gromit-MPX"         "Draw on the screen"                         "gromit-mpx"                             applications-graphics false
mk $P 7-ScreenRuler    "Screen ruler"       "Measure in pixels"                          "screenruler"                            applications-graphics false
mk $P 8-nwipe          "nwipe - WIPE DISK (DESTRUCTIVE)" "Wipes the disk: data will NOT come back" "sudo nwipe"                     edit-delete true
cli $P 9-f3            "f3 - fake flash drive/card?" utilities-terminal "  sudo f3probe --destructive /dev/sdX   WIPES the device" "  f3write /mnt/x ; f3read /mnt/x   non-destructive"

cat > "$D/README-HDDLive.txt" <<'EOF'
HDDLive (Xubuntu 24.04 + OpenSuperClone) - quick guide (English, internal build)
=================================================================================
Desktop folders (bench flow): 1-Diagnose -> 2-Clone-First -> 3-Recover-Files -> 4-RAID-NAS-Encryption
 -> 5-Analyze-Images -> 6-Repair-Safely, plus 7-Scripts-and-Legacy, 8-Network-Internet and 9-Utilities. Each folder has text guides.
Guides are also in /usr/share/hddlive/cheatsheets/ . The "HDDLive Self-Test" shortcut checks the tools, the driver and the GUIs.

BENCH RULE: first PRESERVE (clone), then touch anything. Never mount/repair the failing ORIGINAL disk.

HOW TO USE
 1. Identify the failing disk:  lsblk -o NAME,SIZE,MODEL,SERIAL   /   sudo smartctl -a /dev/sdX
 2. Clone:  OpenSuperClone (shortcut) -> source = failing disk, destination = image/good disk.
 3. Watch progress/log:  OSCViewer or ddrescueview.
 4. Recover files from the cloned image:  DMDE / R-Studio / R-Linux / UFS Explorer / TestDisk / PhotoRec.

SAFETY FOR FAILING DISKS (already configured in this image)
 - Automatic mounting of disks is OFF (udev rule 99-disable-udisk-automount). Mount only what you need (preferably -o ro).
 - Software RAID (mdadm) is NOT assembled by itself. Use:  sudo mdadm --assemble --scan --readonly
 - smartd (background SMART monitor), ZFS auto-import, multipath and automatic updates are disabled.
 - Boot menu: "disable ataX" (edit X: libata.force=1:disable turns off port ata1) keeps Linux from touching the bad drive.
 - Boot menu: "load into RAM" lets you remove the USB stick/DVD after starting.

OPENSUPERCLONE
 - Virtual driver (oscdriver) via DKMS, already built for this image's kernel: sudo modprobe oscdriver
 - With Secure Boot ON the module does not load -> turn Secure Boot OFF in the BIOS to use the Virtual Disk.
 - Installed version: 2.6.0-alpha1 (pre-release, the newest). Stable fallback:
     sudo dpkg -i /usr/share/hddlive/osc-stable/opensuperclone_2.5.0-1_amd64.deb
 - The original HDDSuperClone 2.3.3 (legacy) is also installed: folders 2-Clone-First and 7-Scripts-and-Legacy.

COMMERCIAL PROGRAMS
 - DMDE: installed WITHOUT a license in this build (Free Edition). To use your license, put the license text in the
   "lickey=" field of /opt/dmde/dmde.ini (and /opt/dmde-beta/dmde.ini) or enter it in the program (Help > License).
   DMDE only starts with the working directory = its folder (the "dmde" and "dmde-beta" wrappers already do that). Run as root (shortcuts use sudo).
 - R-Studio (demo until you activate a license), R-Linux and Hard Disk Sentinel (free on Linux) are installed.
 - UFS Explorer Professional Recovery: ALREADY INSTALLED in /opt/ufs-explorer-pro (the person who builds the image is responsible for reading and accepting the SysDev EULA).
   It is the activation/trial edition from SysDev: activate the license inside the program. The Sentinel License Manager service is installed and running.
 - In live mode nothing is saved at the end of the session: activate/register licenses on every boot or keep the license files on a USB stick.

PASSWORD AND NETWORK
 - Live user: xubuntu (sudo without a password). SSH is installed but OFF:  sudo passwd xubuntu; sudo systemctl start ssh
EOF
cp "$D/README-HDDLive.txt" /usr/share/hddlive/README.txt

# --- udev rule that disables disk automounting (was never installed in the old ISO) ---
cat > /etc/udev/rules.d/99-disable-udisk-automount.rules <<'EOF'
# HDDLive: never auto-mount/open any disk (protects failing drives and evidence)
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1", ENV{UDISKS_AUTO}="0"
EOF

# --- power/screen: never suspend or blank the screen during long cloning jobs ---
X=/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
mkdir -p "$X"
cat > "$X/xfce4-power-manager.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>
    <property name="logind-handle-lid-switch" type="bool" value="false"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="blank-on-battery" type="int" value="0"/>
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="dpms-on-ac-sleep" type="uint" value="0"/>
    <property name="dpms-on-ac-off" type="uint" value="0"/>
    <property name="dpms-on-battery-sleep" type="uint" value="0"/>
    <property name="dpms-on-battery-off" type="uint" value="0"/>
    <property name="show-panel-label" type="int" value="0"/>
    <property name="inactivity-on-ac" type="uint" value="14"/>
    <property name="inactivity-on-battery" type="uint" value="14"/>
    <property name="inactivity-sleep-mode-on-ac" type="int" value="1"/>
    <property name="inactivity-sleep-mode-on-battery" type="int" value="1"/>
  </property>
</channel>
EOF
printf 'mode:\t\toff\nlock:\t\tfalse\n' > /etc/skel/.xscreensaver
cat > "$X/xfce4-screensaver.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-screensaver" version="1.0">
  <property name="saver" type="empty">
    <property name="enabled" type="bool" value="false"/>
    <property name="mode" type="int" value="0"/>
  </property>
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
</channel>
EOF

# --- look and feel: same as the old ISO (Greybird + elementary-xfce-darker + Noto Sans 9 + O|HMC buttons). On 24.04 the default icon theme is elementary-xfce-dark -> pin darker.
XD=/etc/xdg/xdg-xubuntu/xfce4/xfconf/xfce-perchannel-xml
sed -i 's/value="elementary-xfce-dark"/value="elementary-xfce-darker"/' $XD/xsettings.xml
grep -E 'ThemeName|IconThemeName|CursorThemeName|FontName' $XD/xsettings.xml | sed 's/^ *//'
grep -q 'value="Greybird"' $XD/xsettings.xml && grep -q 'elementary-xfce-darker' $XD/xsettings.xml && grep -q 'Noto Sans 9' $XD/xsettings.xml && echo "visual OK (Greybird / elementary-xfce-darker / Noto Sans 9)"
grep -q 'value="O|HMC"' $XD/xfwm4.xml && echo "xfwm4 buttons OK (O|HMC)"

# --- Xfce 4.18 (Thunar/xfdesktop) only runs "trusted" .desktop files: besides +x it needs metadata::xfce-exe-checksum = the file's SHA-256.
# Without it "Untrusted application launcher" is shown. The live home is created from /etc/skel at every boot, so we mark the launchers at login (autostart).
cat > /usr/local/bin/hddlive-trust-launchers <<'EOF'
#!/bin/sh
# marks every Desktop launcher as trusted (see the comment in 20-config.sh)
for f in "$HOME"/Desktop/*.desktop "$HOME"/Desktop/*/*.desktop; do
  [ -f "$f" ] || continue
  chmod +x "$f" 2>/dev/null
  gio set -t string "$f" metadata::xfce-exe-checksum "$(sha256sum "$f" | cut -d' ' -f1)" 2>/dev/null
done
EOF
chmod 755 /usr/local/bin/hddlive-trust-launchers
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/hddlive-trust-launchers.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=HDDLive: trust the Desktop launchers
Exec=/usr/local/bin/hddlive-trust-launchers
OnlyShowIn=XFCE;
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF

# --- wallpaper (Hawk Data Recovery): replaces the Xubuntu default (system default + symlink) ---
WP=/usr/share/backgrounds/hddlive/wallpaper-hawk-data-recovery.png
if [ -s /root/assets/wallpaper-hawk-data-recovery.png ]; then
  install -d /usr/share/backgrounds/hddlive; install -m 644 /root/assets/wallpaper-hawk-data-recovery.png "$WP"
  sed -i "s#/usr/share/xfce4/backdrops/xubuntu-wallpaper.png#$WP#g" /etc/xdg/xdg-xubuntu/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
  ln -sf "$WP" /usr/share/xfce4/backdrops/xubuntu-wallpaper.png
  # the image is already on a 4:3 (black) canvas: style 5 = zoom, no bars at any common aspect ratio
  sed -i 's#<property name="color-style" type="int" value="0"/><property name="rgba1" type="array">\(<value type="double" value="[0-9]*"/>\)\{4\}</property>##g; s#name="image-style" type="int" value="4"#name="image-style" type="int" value="5"#g' /etc/xdg/xdg-xubuntu/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
  rm -f /usr/local/bin/hddlive-wallpaper-black /etc/xdg/autostart/hddlive-wallpaper-black.desktop
  grep -c "$WP" /etc/xdg/xdg-xubuntu/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml | sed 's/^/wallpaper: entries in xfce4-desktop.xml = /'
else echo "!!! WARNING: wallpaper missing in /root/assets"; fi

chown -R root:root /etc/skel
echo "config OK"; find "$D" -name '*.desktop' | wc -l; ls "$D"
