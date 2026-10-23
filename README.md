# HDDLive — a data-recovery live ISO (Xubuntu 24.04 + OpenSuperClone)

Build scripts and documentation for **HDDLive**, a bootable live system for data recovery and disk cloning. It is a modern, fully scripted rebuild of the old "HDDLive" ISO (Xubuntu 18.04 + HDDSuperClone): **Xubuntu 24.04.5**, **kernel 7.0**, **[OpenSuperClone](https://github.com/ISpillMyDrink/OpenSuperClone)** (with its virtual-disk driver built through DKMS) and a large kit of cloning, recovery, forensic, RAID/crypto and diagnostics tools — most of them in their **newest upstream versions**.

> **This repository contains only scripts and documentation. It does not contain, and the scripts do not ship, any ISO or proprietary binary.** Everything third-party is downloaded from its vendor at build time. See [Legal notes](#legal-notes).

## What is this distribution?

HDDLive is a **rescue live system** (it boots from a USB stick or DVD, runs from RAM and does not install anything on the computer) whose only job is **to get data off failing or damaged storage devices safely**. It is plain Xubuntu 24.04 with its installer and consumer software removed, a **recent kernel** (7.0), and a curated, pre-configured toolbox for the whole recovery workflow: *diagnose the drive → clone it first → recover files from the clone → open RAID/encrypted volumes → analyze images → repair only on a copy*. The desktop is organized in that order, and every tool has a launcher or a cheat sheet.

The central piece is **[OpenSuperClone](https://github.com/ISpillMyDrink/OpenSuperClone)** — an open-source (GPLv2) fork of HDDSuperClone, a cloning tool made specifically for drives with bad sectors, with direct AHCI/IDE/USB access and a *virtual disk* mode — together with GNU ddrescue and the usual recovery suites.

## Why it was created

* The classic "HDDLive" ISO that bundled HDDSuperClone was built on **Xubuntu 18.04 (end of life)**: an old kernel with poor support for current hardware (NVMe, new SATA/USB controllers, UEFI laptops) and years-old versions of every tool. HDDSuperClone itself is closed source and its development moved to the open **OpenSuperClone** fork.
* Rebuilding that image by hand every time is slow and error-prone. This project **scripts the whole build** so it is reproducible, updatable (new upstream versions are a one-line change) and testable (automatic QEMU boot test + in-image self-test).
* Distribution repositories lag behind upstream for exactly the tools that matter here (ddrescue, TestDisk, smartmontools, nvme-cli, Sleuth Kit, btrfs/xfs/e2fs tools, cryptsetup...). The scripts compile or download the **newest upstream releases** and keep the distro versions installed as a fallback.
* Data-recovery work needs **safe defaults** (nothing auto-mounts, RAID/ZFS never auto-assembles, no suspend during a 3-day clone) and a **consistent bench workflow**, which a stock live ISO does not give you.

## Advantages

* **Modern hardware support** — Ubuntu 24.04 base with kernel 7.0, BIOS + UEFI hybrid image, works as a CD or a USB stick.
* **Newest tool versions** — ddrescue 1.30, smartmontools 7.5, nvme-cli 3.1, Sleuth Kit 4.15, btrfs-progs 7.1, xfsprogs 7.2, e2fsprogs 1.47.4, cryptsetup 2.8, mdadm 4.6, GParted 1.8, GSmartControl 2.0 and more; the distro versions stay installed as a fallback.
* **Everything in one place** — cloning, imaging, file/partition recovery, forensics, RAID/LVM/LUKS/BitLocker/ZFS, SMART/NVMe diagnostics, hex editors, network upload (rclone/sshfs), plus launchers for the proprietary suites you license yourself.
* **OpenSuperClone with a working virtual-disk driver** (DKMS, built for the image kernel) and its 65 ATA/Seagate/WD scripts; the stable 2.5.0 package is kept as a fallback.
* **Safe by default** — no auto-mount, no RAID/ZFS/multipath auto-assembly, no screensaver/suspend/auto-updates, a `disable ataX` boot entry to keep Linux away from a bad drive, read-only recipes in the cheat sheets.
* **Permanent install on demand** — `sudo hddlive-install` (also a Desktop shortcut) copies the live system to a disk with GRUB for Legacy/BIOS **and** UEFI; or keep it on the USB stick with persistence. See [docs/INSTALL-TO-DISK.md](docs/INSTALL-TO-DISK.md).
* **Guided, discoverable desktop** — 9 numbered folders that follow the recovery workflow, a launcher for every GUI and for the important terminal tools (it opens a terminal showing example commands), 7 cheat sheets, and a self-test command that checks ~70 things.
* **Reproducible and auditable** — the entire image is built by readable bash scripts; no opaque binary blobs are stored in this repository.
* **Free to rebuild** — only scripts and documentation are published; you choose which proprietary tools (if any) to add and under which license.

## Disadvantages and limitations

* **OpenSuperClone 2.6.0-alpha1 is a pre-release**; the stable 2.5.0 is included as a fallback. Its *Virtual Disk* mode needs the unsigned DKMS module, so **Secure Boot must be off**.
* **It is a live system** — nothing persists after shutdown (images, logs, licenses must be saved to an external disk), and the image is large (~4 GB) and wants RAM (several GB recommended, more for Autopsy).
* **You must build it yourself, and a ready-made ISO may not be shareable** — the proprietary programs (DMDE, R-Studio, R-Linux, UFS Explorer, Hard Disk Sentinel) cannot simply be redistributed, so this repo ships scripts, not an ISO. A full build takes about an hour and needs a Linux host, ~40 GB free and internet access.
* **A very new kernel (7.0) and many freshly compiled tools** can carry regressions that long-term-supported versions do not; the distro versions of most tools remain installed so you can compare.
* **Software cannot fix hardware** — clicking or non-spinning drives, failed heads or damaged platters need a clean-room lab; powering them up repeatedly makes things worse. Dedicated hardware imagers are still the right tool for severely damaged drives.
* **Several tools are destructive by design** (partition editors, wipe tools, ATA security/ROM scripts, `mkfs`, `dd`). Always identify the disk with `lsblk` and work on a clone.
* **Scope** — amd64 only, English-only edition, no installer, no official support or community; Autopsy and UFS Explorer are optional build steps, not part of the default image; the legacy HDDSuperClone 2.3.3 modules are optional and need the original HDDLive ISO as an input.

## What the image gives you

| Area | Programs (selection) |
|---|---|
| **Clone / image a failing drive** | OpenSuperClone 2.6 (virtual disk mode, direct AHCI/IDE/USB access, 65 ATA/Seagate/WD scripts), GNU ddrescue 1.30, ddrescueview, ddrutility, Guymager, Clonezilla, Partclone, FSArchiver, libewf/E01 tools, dc3dd |
| **Recover files / partitions** | TestDisk & PhotoRec 7.2 (+7.3-WIP), QPhotoRec, Foremost, Scalpel, bulk_extractor, ntfsundelete, extundelete, DMDE\*, R-Studio\*, R-Linux\*, UFS Explorer\* |
| **File systems / RAID / crypto** | newest e2fsprogs, btrfs-progs, xfsprogs, ntfsprogs, exfatprogs, mdadm 4.6, LVM, cryptsetup 2.8, dislocker (BitLocker), OpenZFS, libyal tools |
| **Diagnostics** | smartmontools 7.5, GSmartControl 2.0, Hard Disk Sentinel\*, hdparm, sg3_utils, nvme-cli 3.1, fio, memtester, f3 |
| **Forensics** | Sleuth Kit 4.15, libewf, exiftool, yara, binwalk, hex editors, Autopsy (optional step) |
| **Safety defaults** | no auto-mount, no RAID/ZFS auto-assembly, no screensaver/suspend, `disable ataX` boot entry, read-only recipes in the built-in cheat sheets |
| **Desktop** | Xfce, English UI, 9 numbered Desktop folders that follow the bench workflow (Diagnose → Clone first → Recover → RAID/Crypto → Analyze → Repair → Scripts → Network → Utilities), a launcher for every GUI tool and for the important CLI tools, 7 cheat sheets, and a self-test (`hddlive-selftest`) that checks ~70 things and opens every GUI |

\* proprietary — downloaded by the scripts from the vendor, subject to the vendor's license (DMDE runs as Free Edition unless you enter your own license).

Per-program documentation with how it works, how to use it and cautions: **[docs/PROGRAMS.md](docs/PROGRAMS.md)**. The complete one-line list is right below.

## Complete software list

One line per program. ★ = newest upstream version built/downloaded by the scripts (the distro version stays installed as a fallback), **$** = proprietary (downloaded from the vendor at build time, not in this repo). Versions are those used for the October 2026 build. For *how it works / how to use it / cautions* see **[docs/PROGRAMS.md](docs/PROGRAMS.md)**. Exact versions found in the built image (167 main programs, with source and description) are in **[docs/SOFTWARE-LIST.md](docs/SOFTWARE-LIST.md)**, and every one of the 2166 installed packages is in **[docs/ALL-PACKAGES.md](docs/ALL-PACKAGES.md)**.

<details open>
<summary><b>1. Cloning and imaging of failing drives</b></summary>

| Program | What it does |
|---|---|
| **OpenSuperClone** ★ 2.6.0-alpha1 (2.5.0 fallback) | Open-source cloner/imager for drives with bad sectors: phased copy with a map/log, direct AHCI/IDE/USB access, USB-relay power cycling, 65 ATA/Seagate/WD scripts, and a *Virtual Disk* kernel driver (DKMS) that serves only the sectors a tool asks for |
| **OSCViewer / OpenSuperTool** | Graphical viewer of the OpenSuperClone log/domain; CLI tool mode of OpenSuperClone |
| **GNU ddrescue** ★ 1.30 | The reference command-line cloner: copies around read errors, records a resumable mapfile, retries later |
| **ddrescueview** 0.4.5 | Colored block map of a ddrescue mapfile (optional, from the original HDDLive ISO) |
| **ddrutility** 2.8 | ddrescue helpers: finds *which files* are hit by the bad sectors (`ddru_findbad`), copies only used NTFS clusters |
| **safecopy, dc3dd, dcfldd, recoverdm** | Alternative imagers: block skip/retry strategies; forensic `dd` with hashing/logging; recovery from bad optical/floppy media |
| **Guymager** | Forensic imager GUI (dd/E01/AFF) with hashes, verification and case metadata |
| **Clonezilla, Partclone** ★ 0.3.50, **Partimage, FSArchiver** ★ 0.8.9 | Image/clone *healthy* disks copying only used blocks; file-system archives with compression/encryption |
| **libewf / ewf-tools** ★ 20260924, **afflib-tools, xmount, qemu-img/nbd** | Create/verify/mount E01 and AFF evidence images; present or convert images (VMDK/VHD/QCOW2) without touching the original |
| **rclone** ★ 1.75 | "rsync for the cloud": upload images/recovered files to Drive, OneDrive, S3, SFTP, SMB… |
| **HDDSuperClone 2.3.3, HDDSuperTool, HDDSCViewer + 47 `hddscripts`** **$** *(optional)* | The original proprietary tools of the old HDDLive, kept as a fallback; only if you supply the original ISO |

</details>

<details>
<summary><b>2. File and partition recovery</b></summary>

| Program | What it does |
|---|---|
| **DMDE** **$** 4.4.4 + 4.5.0 beta | Disk editor and logical recovery: rebuilds file systems, scans for lost structures, RAID reconstruction, clone/hex tools (runs as Free Edition unless you enter your own license) |
| **R-Studio** **$** 5.5 | Professional multi-filesystem recovery with RAID assistant and hex editor (demo until licensed) |
| **R-Linux** **$** 6.5 | Free edition of R-Studio's engine for ext2/3/4 (and newer Btrfs/XFS support) |
| **UFS Explorer Professional Recovery** **$** *(optional)* | Cross-platform recovery with strong RAID/NAS/VM support (UFS/ZFS, Drobo, Synology, VMware…); installed only if you set `ACCEPT_UFS_EULA=yes` |
| **TestDisk** ★ 7.2 / 7.3-WIP | Recovers lost partitions, repairs MBR/GPT and boot sectors |
| **PhotoRec / QPhotoRec** ★ 7.2 | Signature-based carving of ~480 file types, with a Qt GUI version |
| **Foremost, Scalpel** | Header/footer file carving with configurable rules |
| **recoverjpeg / recovermov, magicrescue** | Photo/video carving from cards; "recipe"-based carving |
| **ntfsundelete, scrounge-ntfs, extundelete, ext4magic, ext3grep, fatcat** | Undelete / MFT-based recovery on NTFS, journal-based undelete on ext3/4, FAT inspection |
| **bulk_extractor** ★ 2.2.0 | Scans a whole image without a file system and extracts e-mails, URLs, cards, phone numbers, GPS… |
| **binwalk, yara, exiftool, chntpw** | Find embedded files/firmware; pattern rules; read/edit file metadata; reset local Windows passwords (authorized use only) |
| **Double Commander** 1.2.9 | Two-pane file manager to copy recovered data around |

</details>

<details>
<summary><b>3. Partitions, file systems, RAID and encryption</b></summary>

| Program | What it does |
|---|---|
| **GParted** ★ 1.8.1, **GNOME Disks, gdisk/sgdisk, fdisk/parted, gpart, kpartx** | Partition editors and inspectors (GParted writes to the disk!); gpart guesses lost partitions; kpartx maps partitions of an image |
| **ntfs-3g / ntfsprogs** ★ 2026.9.28 | `ntfsclone`, `ntfsfix`, `ntfsresize`, `ntfsundelete`… (mounting still uses Ubuntu's patched ntfs-3g) |
| **e2fsprogs** ★ 1.47.4, **btrfs-progs** ★ 7.1, **xfsprogs** ★ 7.2.1 | Check/repair/inspect ext2/3/4, Btrfs (`btrfs restore` extracts without mounting) and XFS |
| **exfatprogs** ★ 1.4.3, dosfstools, **nilfs-utils** ★ 2.3.1, f2fs-tools, jfsutils, reiserfsprogs, hfsprogs/hfsplus, udftools, bcache-tools | Tools for exFAT, FAT, NILFS2, F2FS, JFS, ReiserFS, HFS+, UDF, bcache |
| **OpenZFS** 2.2 (`zpool`, `zfs`) | ZFS pools — automatic import disabled, use `zpool import -o readonly=on` |
| **mdadm** ★ 4.6, **LVM2, dmraid, multipath-tools** | Software RAID, logical volumes, fake-RAID; nothing is assembled automatically |
| **cryptsetup** ★ 2.8.0, **dislocker, libbde-utils, ecryptfs-utils** | Open LUKS/VeraCrypt volumes, BitLocker volumes and old encrypted home folders |
| **libyal tools** (libvshadow, libvhdi, libvmdk, libqcow, libfsapfs, libfsntfs, libvslvm) | Inspect/mount Windows shadow copies, virtual disks, APFS… read-only |
| **libguestfs-tools** | Open VM images without booting or mounting them |
| **nbd-client, sshfs, nfs-common, cifs-utils** | Mount remote NAS/servers as source or destination |

</details>

<details>
<summary><b>4. Hardware diagnostics</b></summary>

| Program | What it does |
|---|---|
| **smartmontools** ★ 7.5 | `smartctl` reads S.M.A.R.T. data and runs self-tests on SATA/SAS/NVMe/USB drives (`smartd` is disabled) |
| **GSmartControl** ★ 2.0.2 | Graphical front-end for smartctl |
| **Hard Disk Sentinel** **$** 0.20c (Linux console) | Health/performance/temperature rating of disks |
| **hdparm** ★ 9.65, **sdparm, sg3_utils** ★ 1.49 | ATA identify/benchmark/HPA/security; raw SCSI/SAS/SAT commands |
| **nvme-cli** ★ 3.1 | NVMe identify, SMART log, format/sanitize |
| **lsscsi, smp-utils, lshw, inxi, HardInfo, CPU-X, dmidecode, lm-sensors, usbutils, pciutils** | Hardware inventory: ports, expanders, sensors, USB/PCI devices |
| **fio, bonnie++, stress-ng, memtester, memtest86+** | Disk/CPU/RAM benchmarks, stress tests and RAM tests |
| **f3** | Detects counterfeit USB sticks and memory cards |
| **nwipe, wipe, secure-delete** | Secure erase (**destructive**) |
| **disktype, pv, ncdu, iotop, htop, Baobab** | Media type, progress, disk usage, I/O and process monitors |

</details>

<details>
<summary><b>5. Forensics and image analysis</b></summary>

| Program | What it does |
|---|---|
| **The Sleuth Kit** ★ 4.15 | `mmls`, `fls`, `icat`, `tsk_recover`, `mactime`… read images without mounting (lists deleted files, timelines) |
| **Autopsy** 4.23.1 *(optional build step)* | Graphical forensic platform on top of Sleuth Kit: cases, timeline, keyword/hash search |
| **wxHexEditor, GHex, hexedit, dhex, bvi** | Hex editors (wxHexEditor edits whole disks and huge images) |
| **ewf tools, exiftool, yara, binwalk, bulk_extractor** | See the sections above — evidence formats, metadata, signatures, firmware, feature extraction |

</details>

<details>
<summary><b>6. Network, desktop and utilities</b></summary>

| Program | What it does |
|---|---|
| **Firefox** (Mozilla deb) | Web browser (Ubuntu's snap version is removed because it does not work well live) |
| **openssh-server** (off by default), **rsync, lftp, curl, wget, nmap, tcpdump, iperf3, ethtool, mtr, whois, x11vnc** | Remote access, transfers and network diagnostics |
| **tmux, mc, ranger, vim, git, gdb, strace, lsof, smem, sysstat** | Terminal workflow and troubleshooting tools |
| **p7zip, 7zip, unrar, unar, cabextract, pigz, zip, lzip, fdupes, rdfind** | Unpack archives; find duplicate files after a recovery |
| **Xfburn, SimpleScreenRecorder, Orage, Gromit-MPX, Screen Ruler, Mousepad, Ristretto, Parole** | Burn discs, record the screen, calendar, draw on screen, edit text, view images/media |
| **Xfce 4.18** (Greybird theme, elementary-xfce-darker icons) | The desktop, with the 9 numbered folders, launchers, cheat sheets and `hddlive-selftest` |

</details>

## Quick start

Requirements: Ubuntu 22.04+ build host with root, ~40 GB free, `xorriso squashfs-tools rsync curl unzip`; QEMU + OVMF only if you want to test.

```bash
sudo mkdir -p /opt/hddlive-build/dl && cd /opt/hddlive-build
# 1) put the official xubuntu-24.04.5-desktop-amd64.iso in dl/  (its SHA-256 is verified by 01-prepare.sh)
# 2) copy this repository's build/ folder to /opt/hddlive-build/build
sudo bash build/01-prepare.sh      # extract the ISO and merge its layered squashfs
sudo bash build/02-download.sh     # fetch upstream tarballs / vendor downloads
sudo bash build/03-install.sh      # dist-upgrade, apt kit, OpenSuperClone + DKMS driver, ddrescue ...
sudo bash build/08-newer.sh        # compile the newest versions of the filesystem/forensic tools
# optional: sudo ACCEPT_UFS_EULA=yes bash build/11-ufs.sh   (read the SysDev EULA first!)
sudo bash build/04-configure.sh    # desktop, launchers, cheat sheets, self-test
sudo bash build/05-pack.sh         # squashfs + hybrid BIOS/UEFI ISO  ->  $BUILD_ROOT/out/
```

A complete copy-and-paste walkthrough (every step, checks, QEMU tests, writing to USB, troubleshooting): **[docs/STEP-BY-STEP.md](docs/STEP-BY-STEP.md)**.
Details, pitfalls and the legal notes: **[docs/BUILD.md](docs/BUILD.md)**.

## Status — please read

* The pipeline (steps 01, 03, 08, 11, 04, 05) was run end to end and the resulting ISO was **tested in QEMU/KVM** (BIOS, UEFI and as a USB disk; self-test ≈70 checks OK).
* **Tested on real hardware, booting in both UEFI and Legacy (BIOS/CSM) modes.**
* The OpenSuperClone *Virtual Disk* mode needs Secure Boot **off** (the DKMS module is unsigned). OpenSuperClone 2.6.0-alpha1 is a pre-release; the stable 2.5.0 `.deb` is kept in the image as a fallback.
* The download step (02) was validated against the URL list but not re-run from a completely empty tree.
* Data recovery can destroy data. **Clone first, work on the copy.** Several bundled scripts/tools are destructive by design (see the cheat sheets).

## Repository layout

```
build/            the build pipeline (bash) — run on a Linux build host
  chroot/         scripts that run INSIDE the image chroot
  assets/         optional extras (e.g. your own wallpaper) — see assets/README.md
docs/PROGRAMS.md  what every program in the image does and how to use it
docs/SOFTWARE-LIST.md  main programs with the exact versions in the image
docs/ALL-PACKAGES.md   every installed package (dpkg) with version and description
docs/STEP-BY-STEP.md  copy-and-paste build / test / USB walkthrough
docs/INSTALL-TO-DISK.md  install the live system to a disk (hddlive-install) or use persistence
docs/BUILD.md     how the image is built, lessons learned, how to test
```

## Legal notes

* **License of this repository:** MIT (scripts and documentation), see [LICENSE](LICENSE). Third-party software keeps its own licenses.
* **Proprietary software** (DMDE, R-Studio, R-Linux, UFS Explorer, Hard Disk Sentinel, and the optional legacy HDDSuperClone 2.3.3) is **not** part of this repository. The scripts download it from the vendors; you must comply with each vendor's license/EULA. UFS Explorer's installer wizard is only automated if *you* set `ACCEPT_UFS_EULA=yes` after reading the EULA. **An ISO that contains these programs may not be redistributable** — check each license before sharing an image.
* **Trademarks:** Ubuntu, Xubuntu and Firefox are trademarks of their owners. If you publish an image built from this repository, give it your own name.
* **GPL:** the image contains GPL software; if you distribute an image, you must also offer the corresponding source (the Ubuntu archives and the upstream project pages are the sources used here).
* DMDE, R-Studio etc. are products of their respective authors; this project is not affiliated with them, with Canonical, or with the OpenSuperClone project.
