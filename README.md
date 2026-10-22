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
* **Guided, discoverable desktop** — 9 numbered folders that follow the recovery workflow, a launcher for every GUI and for the important terminal tools (it opens a terminal showing example commands), 7 cheat sheets, and a self-test command that checks ~70 things.
* **Reproducible and auditable** — the entire image is built by readable bash scripts; no opaque binary blobs are stored in this repository.
* **Free to rebuild** — only scripts and documentation are published; you choose which proprietary tools (if any) to add and under which license.

## Disadvantages and limitations

* **Not tested on real hardware yet** — it was tested in QEMU/KVM only (BIOS, UEFI, USB). Validate on your own machines before trusting it with a customer's data.
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

Full per-program documentation (what each tool does, how it works, how to use it, cautions): **[docs/PROGRAMS.md](docs/PROGRAMS.md)**.

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
* **Not tested on real hardware yet.** The OpenSuperClone *Virtual Disk* mode needs Secure Boot **off** (the DKMS module is unsigned). OpenSuperClone 2.6.0-alpha1 is a pre-release; the stable 2.5.0 `.deb` is kept in the image as a fallback.
* The download step (02) was validated against the URL list but not re-run from a completely empty tree.
* Data recovery can destroy data. **Clone first, work on the copy.** Several bundled scripts/tools are destructive by design (see the cheat sheets).

## Repository layout

```
build/            the build pipeline (bash) — run on a Linux build host
  chroot/         scripts that run INSIDE the image chroot
  assets/         optional extras (e.g. your own wallpaper) — see assets/README.md
docs/PROGRAMS.md  what every program in the image does and how to use it
docs/STEP-BY-STEP.md  copy-and-paste build / test / USB walkthrough
docs/BUILD.md     how the image is built, lessons learned, how to test
```

## Legal notes

* **License of this repository:** MIT (scripts and documentation), see [LICENSE](LICENSE). Third-party software keeps its own licenses.
* **Proprietary software** (DMDE, R-Studio, R-Linux, UFS Explorer, Hard Disk Sentinel, and the optional legacy HDDSuperClone 2.3.3) is **not** part of this repository. The scripts download it from the vendors; you must comply with each vendor's license/EULA. UFS Explorer's installer wizard is only automated if *you* set `ACCEPT_UFS_EULA=yes` after reading the EULA. **An ISO that contains these programs may not be redistributable** — check each license before sharing an image.
* **Trademarks:** Ubuntu, Xubuntu and Firefox are trademarks of their owners. If you publish an image built from this repository, give it your own name.
* **GPL:** the image contains GPL software; if you distribute an image, you must also offer the corresponding source (the Ubuntu archives and the upstream project pages are the sources used here).
* DMDE, R-Studio etc. are products of their respective authors; this project is not affiliated with them, with Canonical, or with the OpenSuperClone project.
