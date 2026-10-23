# HDDLive 24.04 + OpenSuperClone — Complete program documentation

HDDLive is a bootable live ISO for data-recovery work, based on Xubuntu 24.04 and built around OpenSuperClone and a curated set of cloning, recovery, forensic and diagnostic tools. This document is for people who **use** the image on the bench and for anyone (human or AI) who needs to **maintain or continue the project**. For every program it explains: **what it is, what it is for, how it works internally, how to use it, version/origin and cautions**.

> **Note:** Everything here describes the image produced by the scripts in [`../build`](../build); versions are those used when the image was built (October 2026).

Origin legend: **apt** = Ubuntu 24.04 package · **★ upstream** = newer version compiled/downloaded from the author's site (installed in `/usr/local` or `/opt`, wins in `PATH`; the apt one stays as a fallback) · **bin** = official vendor binary · **$** = commercial (the user's own license/activation).

> **Licensing and redistribution.** The repository does **not** contain any proprietary program. DMDE, UFS Explorer, R-Studio, R-Linux, Hard Disk Sentinel and (optionally) the legacy HDDSuperClone 2.3.3 modules are downloaded from the vendors by the build scripts (or, for the legacy modules, taken from the original HDDLive ISO if the person building the image supplies it). Each user is responsible for respecting the vendors' licenses and EULAs. See the per-program notes below and §10.

---

## 0. Image overview

| Item | Value |
|---|---|
| Format | Hybrid ISO (BIOS + UEFI); can be written to a USB stick with `dd` / Rufus in DD mode / Ventoy |
| Base | **Xubuntu 24.04.5 LTS "Noble Numbat"** (Xfce 4.18), standard support until April 2029 |
| Kernel | **7.0.0-38-generic** (HWE of the 24.04.5 series), with the **oscdriver 2.6.8** module built via DKMS |
| Boot | **GRUB 2.12** on BIOS (El Torito) and UEFI (signed shim; Secure Boot works for booting, **but oscdriver does not load with Secure Boot enabled**) |
| Filesystem | a single `casper/filesystem.squashfs` (xz) — the official 24.04 ISO is layered; here it is flattened |
| Live user | `xubuntu`, passwordless sudo (SSH installed but **disabled**) |
| Look & feel | **Greybird** theme + **elementary-xfce-darker** icons + **Noto Sans 9** + window buttons `O|HMC` |
| Language | English |
| Installer | **removed** (it is a rescue live system, it does not install to disk) |
| Autopsy | **not** included in the default build (optional, see §6) |

---

## 1. How the image works

### 1.1 From the USB stick to the desktop
1. **Firmware** (BIOS/UEFI) loads **GRUB** from the ISO (`/boot/grub/grub.cfg`).
2. GRUB loads `casper/vmlinuz` (kernel) and `casper/initrd` with `boot=casper`.
3. **casper** (an initramfs script) looks for the medium that contains `casper/filesystem.squashfs`, mounts it read-only and stacks a writable layer in **RAM** (overlayfs). Everything you change during the session lives in RAM and **is lost at power-off**.
4. The system starts **LightDM** with autologin of the `xubuntu` user and Xfce opens with the Desktop already organized.

### 1.2 Boot menu (GRUB, 10 s)
| Entry | What it is for |
|---|---|
| **HDDLive – Try without installing** | normal boot |
| **disable ataX** | press `e`, replace `X` with the port number (`libata.force=1:disable` disables `ata1`): prevents Linux from even touching a faulty HDD that hangs the boot |
| **load into RAM** (`toram`) | copies the image to RAM; afterwards you can **remove the USB stick/DVD** |
| **safe graphics** (`nomodeset`) | problematic video cards |
| **Check disc for defects** | verifies the medium's `md5sum.txt` |
| **Test memory** (BIOS only) | memtest86+ |
| **UEFI Firmware Settings** / **Boot from next volume** (UEFI only) | firmware shortcuts |

### 1.3 Bench protections already configured
* **No disk is mounted automatically** (udev rule `99-disable-udisk-automount.rules`) — protects faulty disks and evidence.
* **Software RAID is not assembled automatically** (mdadm's automatic assembly rule is neutralized). Use `sudo mdadm --assemble --scan --readonly`.
* **ZFS, multipath, smartd, mdadm-monitor, update timers, cloud-init and SSH are disabled/masked** — nothing writes to or scans disks unless you ask it to.
* **Trusted Desktop launchers:** Xfce 4.18 (Thunar/xfdesktop) only runs a `.desktop` file if, besides the executable bit, it carries the `metadata::xfce-exe-checksum` attribute (SHA-256); otherwise **"Untrusted application launcher"** appears. An autostart entry (`hddlive-trust-launchers`) marks all launchers at login — they run **directly**, without a prompt.
* **Screen and power:** no screensaver, no DPMS, no suspend on lid close (clones take hours/days). There is a "Disable Screensaver" shortcut.
* **HDDLive Self-Test** shortcut (`hddlive-selftest`): checks versions, the driver and DMDE, and **opens each graphical interface** for 10 s.

### 1.4 Golden rule (applies to every program below)
> **First PRESERVE (clone to an image / good disk), then recover.** Never mount, repair, run `fsck`, `chkdsk`, GParted or TestDisk "Write" on the faulty **original** disk. Work on the **image** (or a clone).

### 1.5 Recommended workflow (mirrors the Desktop folders)
`1-Diagnose` → `2-Clone-First` → `3-Recover-Files` → `4-RAID-NAS-Encryption` → `5-Analyze-Images` → `6-Repair-Safely`.
1. **Diagnose**: `lsblk`, SMART (GSmartControl/smartctl/Hard Disk Sentinel). Mechanical failure (noise, not spinning) = **stop** and take it to a clean-room lab; cloning only makes it worse.
2. **Clone**: OpenSuperClone (or ddrescue) → `.img` image + map/log. Several passes: good areas first, then bad ones, with limited retries.
3. **Recover** on the image: DMDE / R-Studio / R-Linux / UFS Explorer (logical), TestDisk (partitions), PhotoRec/Foremost (by signature).
4. If it is **RAID/LVM/encryption**: rebuild/open it (read-only) before recovering.
5. **Analyze** (forensics): Sleuth Kit, hex editors (and Autopsy if you added it).
6. **Repair** only afterwards, and always on a **clone**.

---

## 2. Cloning and disk imaging

### 2.1 OpenSuperClone (OSC) — ★ 2.6.0-alpha1 (built from source) · stable fallback 2.5.0
* **What it is:** a **GPLv2** fork of HDDSuperClone (by Scott Dwyer; the original became proprietary). A cloner/imager specialized in **faulty disks**, ddrescue-style, but with much lower-level access and a GTK3 GUI. It is the replacement for the HDDSuperClone of the original HDDLive ISO.
* **How it works:**
  * Reads the source in **adaptive blocks**; unreadable sectors go to a **map/log (domain)** and the program returns to them later, in phases (fast copy of good areas → problem areas → fine-grained retries). It can be paused/resumed at any time, even across days, because the log keeps the state.
  * **Access modes:** through the OS API (default), **direct AHCI** and **direct IDE** (the program talks to the controller and bypasses the Linux driver, which tends to hang/retry too much), **direct USB**; also a **USB relay** to power-cycle the HDD automatically when it "dies" (external hardware).
  * **Script engine** per ATA command (identify, SMART, PIO/DMA read/write, reset, security, WD firmware utilities…). The scripts are in `/usr/bin/oscscripts`. **Many are destructive** (write, erase, set-password, ROM patch) — use them only if you know what you are doing.
  * **Virtual Disk Mode (OSCDriver):** a kernel module that creates a **virtual disk** (a fake `/dev/sdX`) that serves reads *directly from the faulty disk* (or from the image), asking OSC for each sector only when some tool (DMDE, TestDisk, mount…) requests it. This lets you recover files **without cloning the whole disk** and, at the same time, writes what was read into the image. It needs the `oscdriver` module: already built via DKMS for kernel 7.0.0-38; load it with `sudo modprobe oscdriver`. **With Secure Boot enabled the module does not load.**
* **Binaries:** `opensuperclone` (requires root), `opensuperclone --tool` (tool mode / OpenSuperTool), `oscviewer` (graphical viewer for the log/domain).
* **How to use (summary):** *OpenSuperClone* shortcut → choose the **source** (faulty disk), the **destination** (image file, or a disk of the same size or larger) and the **log file**; start the copy; follow it in OSCViewer. Never use a disk with data that matters as the destination.
* **Notes:** **2.6.0-alpha1** is a pre-release (the newest; the "official" stable is 2.5.0, kept in `/usr/share/hddlive/osc-stable/opensuperclone_2.5.0-1_amd64.deb`; switch with `sudo dpkg -i`). The official alpha `.deb` requires glibc 2.34+ and does not declare `libconfig9`, so the ISO uses a **custom-built .deb** (`../build/chroot/15-osc-build.sh`). On real hardware, test Virtual Disk Mode before trusting it.

### 2.1b Legacy modules from the old HDDLive (HDDSuperClone 2.3.3.pro, HDDSuperTool, HDDSCViewer, 47 `hddscripts`) — optional
* **Where are the "other modules" of HDDSuperClone?** OpenSuperClone **already ships the equivalent of all of them**: `opensuperclone` (GUI), `opensuperclone --tool` (= HDDSuperTool), `oscviewer` (= HDDSCViewer) and **the scripts** in `/usr/bin/oscscripts/*.osc` — the **47 HDDSuperClone scripts were ported to the `.osc` format** (ata28/ata48 read/write/erase PIO/DMA, `ata_identify_device`, `ata_smart_data`, `ata_security_*`, `reset`/`reset_hard`, `hddmenu`/`hddsubmenu_*` menus, Western Digital utilities `wd_royl_*`/`wd_dump_mod42`) and **extended** (Seagate F3: `seagate_f3_*` — glist, SMART, spin-down/up, tune for imaging, regen translator…; `ata_rebuild_assist_*`, `ata_execute_diagnostic`, `ata_idle_immediate_unload`, plus more variants such as `wd_royl_patch_mod02_ram/fast_ram`). You can create your own in `/usr/bin/oscscripts/myscripts/`.
* **Even so, the originals can be included in the image**, in case some workflow only works with them: `hddsuperclone` **2.3.3_20220430** (proprietary; EULA in `/usr/local/share/doc/hddsuperclone/EULA.txt`), `hddscviewer` 1.0, the folder `/usr/local/bin/hddscripts/` (47 shell scripts) and the documentation/languages in `/usr/local/share/doc/hddsuperclone`. Same paths as the original installer. Shortcuts in `2-Clone-First`: **HDDSuperClone 2.3.3 (legacy)**, **HDDSuperTool (legacy)**, **HDDSCViewer (legacy)** (all three ran; checked with `ldd` and `--version` on 24.04).
* **These modules are optional and proprietary.** They are **not** in this repository. They are only included when the person building the image supplies the original HDDLive ISO to the build scripts; without it they are simply absent (and their shortcuts are omitted). Respect the HDDSuperClone EULA.
* **Cautions:** do not use OSC and HDDSuperClone **at the same time** on the same disk; the legacy virtual driver is independent of `oscdriver` (the program loads its own modules via `insmod`; **not tested on hardware**); the shell `hddscripts` include write/erase/ROM-patch operations (**destructive**).

### 2.2 GNU ddrescue — ★ 1.30 (apt has 1.27)
* **What it is:** the reference command-line cloner (Antonio Diaz Diaz). Copies **data from one device/file to another**, skipping bad sectors and trying to recover them later, always keeping a **mapfile** (block list: finished / non-tried / non-trimmed / non-scraped / bad).
* **How it works:** 1st pass (`-n`, no scraping) copies everything that reads easily and notes the rest; following phases: *trimming* (trim the edges of errors), *scraping* (sector by sector in bad areas), *retrying* (`-d -r3`, direct access and N retries). Since the mapfile records everything, the process is **resumable** and **repeatable** with other options.
* **Typical use:**
  ```
  sudo ddrescue -f -n /dev/sdX image.img map.log        # pass 1 (fast)
  sudo ddrescue -f -d -r3 /dev/sdX image.img map.log    # pass 2 (retries, direct access)
  sudo ddrescuelog -t map.log                            # mapfile statistics
  ```
* **Caution:** it is easy to swap source and destination; a reversed `ddrescue` wipes the source. Use `-f` only when the destination is a file/device you really want to overwrite.

### 2.3 ddrescueview 0.4.5 — bin
A GUI (Lazarus/FPC) that shows the **ddrescue mapfile** as a colored block map (finished = green, bad = red…), with statistics, and can read the map while the copy is running. It also works with compatible OSC logs. Shortcut in `2-Clone-First`. Read-only; it does not touch the disk.

### 2.4 ddrutility 2.8 (apt) — same author as HDDSC
A set that **complements ddrescue**: `ddru_findbad` (finds **which files** were affected by the bad sectors in the mapfile, for NTFS and others), `ddru_ntfsfindbad`, `ddru_ntfsbitmap` (copies only what NTFS marks as used), `ddru_diskutility` (hashes/info). Very useful to tell the client "these 12 files are corrupted".

### 2.5 safecopy 1.7 · dc3dd 7.3.1 · dcfldd 1.9.1 · recoverdm 0.20 (apt)
Alternatives to ddrescue: **safecopy** (block skip/retry strategies), **dc3dd/dcfldd** (forensic `dd` variants: hash while copying, logging, splitting into parts — for *forensic images of healthy disks*), **recoverdm** (recovers from media with bad sectors; CD/DVD/floppy).

### 2.6 Guymager 0.8.13 (apt)
A forensic GUI for **`.dd`/`.E01` (EWF)/AFF images** with MD5/SHA hashing, verification, splitting into segments and case metadata. Designed for **healthy** disks or disks behind a *write blocker*; for a faulty disk use OSC/ddrescue. Uses the apt libewf.

### 2.7 Clonezilla 5.5.25 · Partclone · Partimage · FSArchiver (apt + ★)
Image/clone of **healthy disks**, copying only the **used** blocks (per filesystem):
* **Clonezilla** (`sudo clonezilla`, ncurses interface) — orchestrates Partclone/Partimage/dd; saves/restores whole disk/partition images, locally or over the network (SSH/SMB/NFS).
* **Partclone** — ★ **0.3.50** (compiled) with `partclone.ext4/ntfs/fat/xfs/btrfs/f2fs/hfsp/dd/restore/info/chkimg`. Understands the FS structure, copies only used blocks, produces a compact and verifiable image.
* **Partimage 0.6.9** — legacy (ext2/3, old NTFS, FAT…); only for restoring old images.
* **FSArchiver** — ★ **0.8.9**: archives filesystems **into a file** with compression and encryption, restores to a different partition size/type.

### 2.8 libewf / ewf-tools — ★ 20260924 (apt 20140814)
Library and tools for the **EWF/E01 (EnCase)** format: `ewfacquire`, `ewfinfo`, `ewfverify`, `ewfmount` (mounts the image as a disk), `ewfexport`, `ewfrecover`. The new tools live in `/usr/local/bin`; Guymager keeps using the old apt library.

### 2.9 afflib-tools 3.7 · xmount 0.7.6 · qemu-img 8.2 · squashfs-tools (apt)
* **AFF** (Advanced Forensic Format): `affinfo`, `affcat`, `affconvert`.
* **xmount**: converts/presents images (dd/E01/AFF) as another format, with a **cached write layer** (does not change the original image).
* **qemu-img/qemu-nbd**: converts and **mounts** VMDK/VHD/VHDX/QCOW2 as a disk (`qemu-nbd -c /dev/nbd0 file.vhdx`).

### 2.10 rclone — ★ 1.75.2 (apt 1.60.1)
"rsync for the cloud": copies/syncs to S3, Google Drive, OneDrive, SFTP, SMB, WebDAV… with hash verification. Used to **send the image/recovered files** to a remote destination. Configure with `rclone config`.

---

## 3. Data recovery (files and partitions)

### 3.1 DMDE — $ 4.4.4 (stable) + 4.5.0 beta (GTK3) · installed WITHOUT a license (Free Edition)
* **What it is:** the "Swiss army knife" of logical recovery (Dmitry Sidorov): **disk editor**, recovery by **reconstructed filesystem** and by **signature**, **RAID (including virtual)** reconstruction, cloning, partitioning, hex view.
* **How it works:** reads the partition table and the FS structures (NTFS, FAT/exFAT, ext2/3/4, HFS+, APFS, ReFS, Btrfs without RAID…), and **shows the file tree** – including deleted files – preserving names and folders. If the structure is destroyed, it does a **full scan** (*Full scan*) and rebuilds the most probable structure; there is also "RAW recovery" by signature.
* **Licensing:** DMDE is commercial software. This image installs it **without a license**, i.e. as the **Free Edition**, which limits recovery by folders/files per batch. If you own a license you can enter it in the program, or put it in the `lickey=` field of `/opt/dmde/dmde.ini`. In a live session this is **lost when the session ends**, so enter it again at each boot (or keep the key somewhere external). With a Professional license the program **recovers whole folders**. The program only starts with the working directory = `/opt/dmde`, which is why `dmde` and `dmde-beta` are **wrappers** in `/usr/local/bin` that `cd` first.
* **How to use:** *DMDE* shortcut (already runs `sudo`). Choose the language → **Select Drive** → the **cloned image** (preferred) → "Partitions" → open the volume → "Recover" the checked items (destination on **another** disk).
* **Cautions:** never write the recovery onto the same disk; do not use the editor in write mode on the original disk.

### 3.2 R-Studio 5.5 (build 191803) — $ demo until a license is activated
* **What it is:** a professional suite (R-TT) for multi-filesystem recovery (NTFS, ReFS, FAT, exFAT, HFS+, APFS, UFS, ext, Btrfs, XFS…), **RAID**, images, hex view, network.
* **How it works:** the same idea as DMDE (reconstruction + scan), with an automatic RAID assistant and **large-file editing**. The `.deb` installer puts everything in `/usr/local/R-Studio` (`/usr/bin/rstudio`). Demo: lists everything, recovers small files; a key is required for the rest. Activation does not persist in the live session.
* **Licensing:** proprietary, downloaded from the vendor by the build scripts; not in the repository. Use your own license.

### 3.3 R-Linux 6.5 (build 191754) — bin, free
The **free** version of R-Studio for **ext2/3/4 (and Btrfs/XFS in newer versions)**, same engine. Good for Linux/NAS volumes. Downloaded from the vendor by the build scripts; not in the repository; follow the vendor's license terms.

### 3.4 UFS Explorer Professional Recovery — $ installed in `/opt/ufs-explorer-pro`
* **What it is:** a program from **SysDev Laboratories**: cross-platform data recovery (NTFS, FAT, exFAT, APFS, HFS+, ext/Btrfs/XFS/ZFS, **Unix/BSD/Solaris UFS/ZFS**, RAID/Drobo/Synology/NAS, VMware/Hyper-V, BitLocker/LUKS…), with **strong support for RAID and images**.
* **Installation:** the installer is driven automatically (the SDL installer wizard is stepped through with `xdotool`, `../build/chroot/29-ufs.sh`) **only if the person building the ISO sets `ACCEPT_UFS_EULA=yes` after reading the SysDev EULA**; otherwise the UFS Explorer installation is skipped and the program is absent. When present, it asks for a **license** on opening (Sentinel/USB key, online, or **trial**) — you need your own license or trial. In a live session **nothing persists**: activate at every boot or keep the license file.
* **Sentinel License Manager:** UFS uses the **Sentinel LDK Runtime** (services `aksusbd` + `hasplmd`, port 1947). Without it you get *"The operation cannot be performed because Sentinel License Manager is not running"* (this happened in an early version of the image). The runtime (`trte64`, which ships with UFS) is now **installed and enabled at build time** and starts at boot; the self-test checks `systemctl is-active hasplmd`.

### 3.5 TestDisk / PhotoRec — ★ 7.2 (official static) + 7.3-WIP (`testdisk-wip`/`photorec-wip`) · apt 7.1
* **TestDisk** (terminal): **recovers lost partitions** and repairs the partition table/MBR/GPT, rebuilds the boot sector (FAT/NTFS), recovers files on FAT/NTFS/ext. It works by **reading** the disk, looking for filesystem "signatures" and proposing the table; it only writes when you tell it to **Write**.
* **PhotoRec** (terminal): **signature-based recovery** (*file carving*): ignores the FS and looks for headers of ~480 file types across the whole disk; recovers even with a destroyed/formatted FS, but **without names/folders** (`f1234.jpg`).
* **QPhotoRec** — ★ 7.2 compiled with Qt5: PhotoRec with a graphical interface (*QPhotoRec* shortcut).
* **Use:** `sudo photorec image.img` → choose the partition → file types → **destination on another disk**.
* `fidentify` (identifies file types) is included.

### 3.6 Carving and classic recovery (apt)
* **Foremost 1.5.7** and **Scalpel 1.60:** header/footer carving with configurable rules (`/etc/scalpel/scalpel.conf`, `/etc/foremost.conf`).
* **recoverjpeg 2.6.3** (+ `recovermov`): fragmented JPEG and MOV/MP4 videos from cards.
* **magicrescue 1.1.10:** carving based on "recipes".
* **scrounge-ntfs 0.9:** recovers files from NTFS by reading the MFT.
* **extundelete 0.2.4 / ext4magic 0.3.2 / ext3grep:** *undelete* on ext3/ext4 using the **journal** (only works if the FS was not heavily used after the deletion; old tools, treat them as an alternative).
* **ntfsundelete** (from ntfsprogs ★), **fatcat** (inspects/recovers FAT) and **testdisk** serve as support.

### 3.7 bulk_extractor — ★ 2.2.0
Scans the **whole image, without interpreting the FS**, extracting e-mails, URLs, card numbers, headers, phone numbers, GPS, keys and word lists into "feature" files; parallelized across all cores. Useful for fast forensic triage and for finding leads in unallocated areas.

### 3.8 binwalk 2.3.4 · yara 4.5 · libimage-exiftool-perl 12.76 · chntpw (apt)
* **binwalk:** finds files/firmware embedded in blobs (signatures + entropy). · **yara:** detection rules. · **exiftool:** reads/edits metadata of photos/videos/documents (useful to sort a carving result by capture date). · **chntpw:** resets/edits the password of local Windows accounts (SAM) with the NTFS drive mounted (**authorized** use only).

### 3.9 Double Commander 1.2.9 (GTK2) — ★ bin
A **two-pane** file manager (Total Commander style): copy/move large volumes between the mounted image and the destination, synchronize folders, compare by content, batch rename, file hashes. Desktop shortcut.

---

## 4. Filesystems, partitions, volumes, RAID and encryption

### 4.1 Partitioning
* **GParted** — ★ **1.8.1** (compiled) · apt 1.5.0: GUI to create/resize/move/copy/check partitions (uses `e2fsck`, `ntfsresize`, `xfs_repair`, etc.). **It writes to the disk.** Shortcut runs `sudo gparted`.
* **GNOME Disks 46** (`gnome-disks`): lists disks, **SMART**, benchmark, mounts/unmounts, creates/restores images, opens LUKS.
* **gdisk 1.0.10** (`gdisk`, `sgdisk`, `cgdisk`): **GPT/MBR** editor with GPT recovery from the backup table/MBR. **fdisk/sfdisk/parted/gpart** (apt) complete the set; **gpart** *guesses* lost partitions.
* **kpartx**: maps the partitions of an image as devices (`kpartx -av image.img` → `/dev/mapper/loop0p1`).
* **efibootmgr / os-prober:** UEFI entries and OS detection.

### 4.2 Filesystems (repair/query)
| Area | Tools | Version (origin) |
|---|---|---|
| **NTFS** | `ntfsclone`, `ntfsfix`, `ntfsinfo`, `ntfsls`, `ntfscat`, `ntfscluster`, `ntfscmp`, `ntfsundelete`, `ntfsresize`, `mkntfs`… | ★ **2026.9.28** in `/opt/ntfs-3g` (links in `/usr/local/bin`). Ubuntu's **`mount.ntfs-3g`** (2022.10.3, with security patches) remains the one used for mounting |
| **ext2/3/4** | `e2fsck`, `mke2fs`, `debugfs`, `dumpe2fs`, `resize2fs`, `tune2fs`, `e2image`, `badblocks` | ★ **1.47.4** in `/usr/local/sbin` (apt 1.47.0) |
| **Btrfs** | `btrfs`, `btrfs check/restore/rescue`, `btrfs-find-root`, `mkfs.btrfs` | ★ **7.1** (apt 6.6.3). `btrfs restore` extracts files from a damaged FS **without mounting** |
| **XFS** | `xfs_repair`, `xfs_db`, `xfs_metadump`, `xfs_growfs`, `xfs_copy`, `xfsdump` | ★ **7.2.1** (apt 6.6.0) |
| **FAT/exFAT** | `dosfsck`, `fsck.fat`, `fatcat`, `mkfs.exfat`, `fsck.exfat`, `dump.exfat`, `tune.exfat` | dosfstools 4.2 (apt) · ★ exfatprogs **1.4.3** (apt 1.2.2) |
| **F2FS / JFS / ReiserFS / HFS+ / NILFS2 / UDF** | `fsck.f2fs`, `jfs_fsck`, `reiserfsck`, `fsck.hfsplus`, `nilfs-*`, `udftools` | f2fs-tools 1.16.0 · jfsutils 1.1.15 · reiserfsprogs 3.6.27 · hfsprogs/hfsplus/hfsutils · ★ nilfs-utils **2.3.1** · udftools 2.3 |
| **ZFS** | `zpool`, `zfs` (OpenZFS 2.2.2 + kernel module) | apt. **Automatic import disabled**; use `zpool import -o readonly=on -R /mnt/x pool` |
| **bcache** | `bcache-super-show`, `make-bcache` | apt |
| **squashfs/ISO/UDF/CD** | `unsquashfs`, `mount -t iso9660/udf` | apt |

> **bcachefs** is not in the list: the Ubuntu 24.04 kernel 7.0 **does not ship** the bcachefs module (checked in the image kernel's `config`); the tool would have nothing to mount.

### 4.3 RAID, LVM, multipath
* **mdadm** — ★ **4.6** (apt 4.3): software RAID (md). Only the **new binaries** are installed; it does **not** assemble automatically. Assemble read-only: `sudo mdadm --assemble --scan --readonly`. `mdadm --examine /dev/sdX1` reads the member's superblock (essential to rebuild a RAID with a missing disk).
* **LVM2** (`pvs/vgs/lvs`, `vgchange -ay`), **dmraid** (BIOS/fake RAID), **thin-provisioning-tools**: activate volumes without creating anything new (`vgchange -ay --readonly` when possible).
* **multipath-tools:** installed but **disabled** (multipathd masked) so it does not claim SAN disks.

### 4.4 Encryption
* **cryptsetup** — ★ **2.8.0** (in `/opt/cryptsetup`, links `cryptsetup/veritysetup/integritysetup`; apt 2.7.0): opens **LUKS1/LUKS2**, dm-crypt, VeraCrypt/TrueCrypt (`--type tcrypt`). For a faulty disk, take a **LUKS header backup** (`cryptsetup luksHeaderBackup`) before anything else.
* **dislocker 0.7.3** + **libbde-utils**: open **BitLocker** volumes (with password/recovery key); `dislocker-fuse` exposes a `dislocker-file` with the decrypted volume, which is then mounted/recovered normally.
* **libvshadow-utils** (Windows shadow copies), **libvhdi/libvmdk/libqcow-utils** (virtual disks), **libfsapfs-utils** (APFS), **libfsntfs-utils**, **libvslvm-utils**, **libluksde-utils**: tools from the libyal family to **inspect/mount** these formats read-only.
* **ecryptfs-utils**: the encrypted home folder of old Ubuntu releases.

### 4.5 Virtualization/NAS
* **libguestfs-tools** (`guestfish`, `virt-ls`, `virt-copy-out`…): opens VM images/disks **without mounting** (uses a mini-VM), safe to extract files.
* **nbd-client, sshfs, nfs-common, cifs-utils:** mount remote NAS/servers (to **read the source** or **send the recovered data**).

---

## 5. Hardware diagnostics

| Tool | Version | What it does / how it works |
|---|---|---|
| **smartmontools** (`smartctl`, `smartd`) | ★ **7.5** (apt 7.4) | Reads **S.M.A.R.T.** (attributes, error log, self-tests) of SATA/SAS/NVMe/USB. `sudo smartctl -a /dev/sdX`; short test `-t short`; `smartctl --scan` lists. `smartd` stays disabled |
| **GSmartControl** | ★ **2.0.2** (apt 1.1.4) | GUI for smartctl: colored attributes, runs tests. Built with gcc 13 (C++20) |
| **Hard Disk Sentinel** (Linux, console) | bin 0.20c | **Health/performance/temperature** rating of the disks and prediction; `sudo hdsentinel`. Proprietary vendor binary downloaded by the build scripts (not in the repository); follow the vendor's license terms |
| **hdparm** | ★ 9.65 | ATA: `-I` identify, `-tT` benchmark, ATA security, **HPA/DCO** (`-N`), SATA link. Destructive options (`--security-erase`, `--yes-i-know-what-i-am-doing`) require explicit confirmation |
| **sdparm / sg3_utils** (`sg_*`) | sg3 ★ **1.49** | Raw **SCSI/SAS/SATA(SAT)** commands: `sg_inq`, `sg_readcap`, `sg_logs`, `sg_verify`, `sg_format`, `sg_scan`, `sg_sanitize`… |
| **nvme-cli** | ★ **3.1** (apt 2.8) | NVMe: `nvme list`, `nvme smart-log /dev/nvme0`, `id-ctrl`, format/sanitize |
| **lsscsi, smp-utils, lshw, inxi, hardinfo, cpu-x, dmidecode, lm-sensors, usbutils, pciutils** | apt | Hardware inventory (SAS ports/expander, temperature, devices) |
| **fio, bonnie++, stress-ng, memtester** | apt | Disk/CPU/RAM **benchmark** and **stress**; `memtester 2048 1` tests RAM in user mode |
| **memtest86+ 7.00** | apt | RAM test at boot ("Test memory" entry, BIOS only) |
| **f3** (`f3probe`, `f3write/f3read`) | 8.0 | Detects **counterfeit USB sticks/cards** (fake capacity) |
| **nwipe / wipe / secure-delete** | apt | Secure erase (**destructive**) |
| **badblocks, smartctl -t long, hdparm** | | Disk surface scan (`badblocks` is read-only by default) |
| **disktype, pv, ncdu, iotop, htop, baobab** | apt | Identifies media type; progress; disk usage |

---

## 6. Forensics and image analysis

* **The Sleuth Kit (TSK) — ★ 4.15.0** (apt 4.12.1): command-line tools that **read** images/disks without mounting: `mmls` (partitions), `fsstat`, `fls` (lists files, including deleted), `icat`, `ifind`, `istat`, `tsk_recover` (recovers deleted files), `blkls`, `mactime` (timeline), `hfind`. It is the engine of Autopsy.
* **Autopsy 4.23.1** (**optional, not in the default build**; when added it goes to `/opt/autopsy`): forensic GUI based on TSK and Java 17 (JavaFX in the jars). Creates **cases**, indexes, builds timelines, hash lookup, keyword search, recovery, metadata/browser extraction. Uses **a lot of RAM**; the first launch is slow; keep cases outside the live session.
* **bulk_extractor, binwalk, yara, exiftool**: see §3.7–3.8.
* **Hex editors:** `wxHexEditor` (GUI, **edits whole disks/large images**, opens a device directly), `ghex`, `hexedit`, `dhex`, `bvi`. Useful to inspect/re-examine MBR, GPT, boot sector, superblocks.
* **hexdump/xxd/dd/losetup/mount -o loop,ro,offset=...:** **read-only** mounting of images.

---

## 7. Network, productivity and comfort

| Program | Use on the bench |
|---|---|
| **Firefox** (official Mozilla deb; Ubuntu 24.04's is a *snap* and does not work well in a live session) | access manuals, download licenses/updates |
| **openssh-server** (disabled), **sshfs, rsync, lftp, rclone, curl, wget, nmap, tcpdump, iperf3, ethtool, traceroute/mtr, whois** | send/download images, measure the network, mount remote destinations |
| **x11vnc** | remote access to the live screen (start manually) |
| **tmux, mc, ranger, vim, git, gdb, strace, lsof, smem, sysstat** | terminal work/diagnostics |
| **p7zip-full / 7zip / unrar / unar / cabextract / pigz / zip / lzip** | unpack what was recovered |
| **fdupes, rdfind** | find duplicates after recovery |
| **xfburn, simplescreenrecorder, orage, gromit-mpx, screenruler** | burn disc/DVD, record the screen during a service session, calendar, draw on screen |
| **Thunar, Mousepad, Ristretto, Parole, Xfce Terminal, Task Manager, NetworkManager** | standard Xfce 4.18 desktop |

---

## 8. Appearance and desktop

* **Theme** Greybird, **icons** elementary-xfce-darker, **cursor** Xubuntu default, **font** Noto Sans 9, **buttons** `O|HMC`.
* **Language:** the desktop, folders, shortcuts and guides are in **English** in this edition.
* **Wallpaper (optional):** custom art can be placed in `build/assets/wallpaper-hawk-data-recovery.png` before building (it is not included in the repository); when present it is installed as `/usr/share/backgrounds/hddlive/wallpaper-hawk-data-recovery.png` and applied as the system default (zoom, with the icons falling on the dark area at the left).
* **LibreOffice is not included.** For spreadsheets/reports use Firefox (web) or install it in the session (`sudo apt install libreoffice-calc`, needs network and is lost at power-off).
* **Everything at hand — the Desktop has 9 folders ordered by the bench workflow**; every graphical program and every important terminal tool has a shortcut (terminal ones open a terminal that **shows usage examples** and leaves the prompt ready). Shortcuts for programs that are not in the image (e.g. Autopsy in the default build, the legacy HDDSuperClone modules, UFS Explorer if skipped) are omitted automatically.
  * **Root:** OpenSuperClone · DMDE · R-Studio · UFS Explorer · Double Commander · GParted · HDDSuperClone (legacy) · Terminal · HDDLive Self-Test · Disable Screensaver · Command Guide · **Install HDDLive to disk** · README.
  * `1-Diagnose`: GSmartControl, Hard Disk Sentinel, GNOME Disks, HardInfo, CPU-X, lshw-gtk, List disks, smartctl, hdparm/sg3/nvme, memtester, Task Manager
  * `2-Clone-First`: OpenSuperClone, OpenSuperTool, OSCViewer, ddrescueview, Guymager, Clonezilla, ddrescue, Partclone/FSArchiver, EWF/dc3dd, guide, HDDSuperClone/HDDSuperTool/HDDSCViewer (legacy)
  * `3-Recover-Files`: DMDE 4.4.4, DMDE 4.5.0 Beta, R-Studio, R-Linux, UFS Explorer, QPhotoRec, TestDisk, PhotoRec, TestDisk/PhotoRec 7.3-WIP, Double Commander, Foremost/Scalpel, bulk_extractor, undelete NTFS/ext, guide
  * `4-RAID-NAS-Encryption`: guide, GNOME Disks, root terminal, mdadm, LVM, LUKS/BitLocker, ZFS
  * `5-Analyze-Images`: Autopsy (only if added), wxHexEditor, GHex, Guymager, Double Commander, Sleuth Kit, exiftool/binwalk/yara, guide
  * `6-Repair-Safely`: guide, GParted, TestDisk, safe fsck (diagnose only), gdisk
  * `7-Scripts-and-Legacy`: HDDSuperClone 2.3.3 / HDDSuperTool / HDDSCViewer (legacy), the folders of the **`.osc` scripts**, of the old **hddscripts** and of **your own scripts**, scripts guide
  * `8-Network-Internet`: Firefox, Network Connections, rclone, mount server (sshfs/SMB/NFS), start SSH/VNC, Volume
  * `9-Utilities`: Baobab, Mousepad, Ristretto, Xfburn, Screen Recorder, Gromit-MPX, Screen Ruler, **nwipe (destructive)**, f3
* **Text guides (cheat sheets):** `/usr/share/hddlive/cheatsheets/` — `1-clone-first`, `2-raid-lvm-crypto`, `3-analyze-images`, `4-repair-safely`, `5-scripts`, `6-cli-tools`, `7-recover-files`, `8-install-to-disk`.

---

### 8.1 `hddlive-install` — make the live system permanent
The image has no graphical installer. `sudo hddlive-install` (Desktop shortcut "Install HDDLive to disk") copies the running system to an empty disk: GPT, BIOS + UEFI GRUB, your user, host name, no os-prober. It **erases the chosen disk** and refuses the live media and mounted disks. Details, persistence on the USB stick and the manual procedure: [INSTALL-TO-DISK.md](INSTALL-TO-DISK.md).

---

## 9. Versions: what came from apt and what was updated

| Program | In the ISO (★ = newer upstream) | Ubuntu 24.04 apt |
|---|---|---|
| Kernel | 7.0.0-38 | (same) |
| OpenSuperClone | ★ 2.6.0-alpha1 (fallback 2.5.0) | not in apt |
| ddrescue | ★ 1.30 | 1.27 |
| smartmontools | ★ 7.5 | 7.4 |
| hdparm | ★ 9.65 | 9.65 |
| sg3_utils | ★ 1.49 | 1.46 |
| nvme-cli | ★ 3.1 | 2.8 |
| mdadm | ★ 4.6 | 4.3 |
| TestDisk/PhotoRec | ★ 7.2 (+7.3-WIP) | 7.1 |
| Sleuth Kit | ★ 4.15.0 | 4.12.1 |
| libewf | ★ 20260924 | 20140814 |
| ntfsprogs | ★ 2026.9.28 | 2022.10.3 |
| e2fsprogs | ★ 1.47.4 | 1.47.0 |
| btrfs-progs | ★ 7.1 | 6.6.3 |
| xfsprogs | ★ 7.2.1 | 6.6.0 |
| partclone | ★ 0.3.50 | 0.3.27 |
| fsarchiver | ★ 0.8.9 | 0.8.7 |
| cryptsetup | ★ 2.8.0 | 2.7.0 |
| exfatprogs | ★ 1.4.3 | 1.2.2 |
| nilfs-utils | ★ 2.3.1 | — |
| GParted | ★ 1.8.1 | 1.5.0 |
| GSmartControl | ★ 2.0.2 | 1.1.4 |
| QPhotoRec | ★ 7.2 (Qt5) | — |
| bulk_extractor | ★ 2.2.0 | — |
| rclone | ★ 1.75.2 | 1.60.1 |
| DMDE | $ 4.4.4 + 4.5.0 beta (no license, Free Edition) | — |
| R-Studio / R-Linux | $ 5.5 / 6.5 | — |
| UFS Explorer Pro | $ latest from the vendor's site (only if `ACCEPT_UFS_EULA=yes`) | — |
| Hard Disk Sentinel | 0.20c | — |
| Double Commander | 1.2.9 | — |
| Autopsy | 4.23.1 (optional, not in the default build) | — |
| Firefox | 158 (Mozilla deb) | snap |

---

## 10. Limitations and cautions

1. **Secure Boot enabled ⇒ the `oscdriver` module does not load** (unsigned DKMS module). Disable Secure Boot to use Virtual Disk Mode.
2. The `oscdriver 2.6.8` driver is built for kernel **7.0.0-38**; if you change kernel, run `sudo dkms install oscdriver/2.6.8 -k <kernel>` (headers + gcc are in the image).
3. **OpenSuperClone 2.6.0-alpha1 is a pre-release.** Validate it on your own drives first; for critical production work use the 2.5.0 kept in the image, or ddrescue.
4. Nothing persists: save images/logs/licenses on an external disk.
5. **Commercial licenses:** none of the proprietary programs are in the repository; the build scripts download them from the vendors and each user must respect the vendors' licenses and EULAs. DMDE is installed without a license (Free Edition; enter your own license if you have one), R-Studio runs as a demo until activated, UFS Explorer needs your own license/trial (and is only installed if the builder set `ACCEPT_UFS_EULA=yes`), R-Linux and the Hard Disk Sentinel Linux console edition are distributed free by their vendors (check their current terms), and the legacy HDDSuperClone 2.3.3.pro modules are optional and proprietary.
6. **Destructive** tools: GParted, `nwipe`, `wipe`, OSC scripts (`ata*_write*`, `erase`, `security`, `wd_royl_*`), `hdparm --security-*`, `sg_format/sg_sanitize`, `mkfs.*`, `dd`. Check `/dev/sdX` with `lsblk -o NAME,SIZE,MODEL,SERIAL` **before** any write.
7. **Mechanical failure** (clicking, not spinning, stuck head): do not power it on repeatedly; take it to a lab.
8. Items **left out on purpose:** `hddtemp` (removed from Ubuntu 24.04; use `smartctl -A`/`hdsentinel`), `bless` (hex editor removed), `exfat-utils` (replaced by `exfatprogs`), `bcachefs-tools` (kernel without bcachefs), snaps (Firefox/Thunderbird/Snap Store removed), LibreOffice (see §8), Autopsy in the default build (see §6).

---

## 11. Where things are (for maintenance)

| Path | Content |
|---|---|
| `/opt/dmde`, `/opt/dmde-beta` | DMDE (license, if you have one, goes in `dmde.ini`, field `lickey=`) |
| `/opt/ufs-explorer-pro` | UFS Explorer (only if installed at build time) |
| `/opt/autopsy` | Autopsy (optional, not in the default build) |
| `/opt/doublecmd`, `/opt/ddrescueview`, `/opt/hdsentinel` | ready-made binaries |
| `/opt/testdisk-7.2`, `/opt/testdisk-7.3-wip` | static TestDisk/PhotoRec |
| `/opt/ntfs-3g`, `/opt/cryptsetup` | new versions kept isolated (links in `/usr/local`) |
| `/usr/local/bin`, `/usr/local/sbin` | compiled tools (precede apt in `PATH`) |
| `/usr/local/R-Studio`, `/usr/local/R-Linux` | R-Studio / R-Linux |
| `/usr/bin/oscscripts`, `/usr/share/opensuperclone` | OSC scripts and data |
| `/usr/share/hddlive/` | README, guides (`cheatsheets/`), OSC `.deb` (`osc-stable/`) |
| `/usr/src/oscdriver-2.6.8` | DKMS source of the virtual driver |
| `/usr/local/bin/hddsuperclone`, `hddscviewer`, `hddscripts/` | **legacy** HDDSuperClone 2.3.3 modules (optional) |
| `/var/hasplm`, `/usr/sbin/aksusbd_x86_64`, `hasplmd_x86_64` | Sentinel Runtime (UFS licenses) |
| `/usr/local/bin/hddlive-trust-launchers` + `/etc/xdg/autostart/hddlive-trust-launchers.desktop` | marks the launchers as trusted |
