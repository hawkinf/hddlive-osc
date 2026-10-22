# HDDLive — a data-recovery live ISO (Xubuntu 24.04 + OpenSuperClone)

Build scripts and documentation for **HDDLive**, a bootable live system for data recovery and disk cloning. It is a modern, fully scripted rebuild of the old "HDDLive" ISO (Xubuntu 18.04 + HDDSuperClone): **Xubuntu 24.04.5**, **kernel 7.0**, **[OpenSuperClone](https://github.com/ISpillMyDrink/OpenSuperClone)** (with its virtual-disk driver built through DKMS) and a large kit of cloning, recovery, forensic, RAID/crypto and diagnostics tools — most of them in their **newest upstream versions**.

> **This repository contains only scripts and documentation. It does not contain, and the scripts do not ship, any ISO or proprietary binary.** Everything third-party is downloaded from its vendor at build time. See [Legal notes](#legal-notes).

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

Details, pitfalls and the test procedure (QEMU BIOS/UEFI/USB): **[docs/BUILD.md](docs/BUILD.md)**.

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
docs/BUILD.md     how the image is built, lessons learned, how to test
```

## Legal notes

* **License of this repository:** MIT (scripts and documentation), see [LICENSE](LICENSE). Third-party software keeps its own licenses.
* **Proprietary software** (DMDE, R-Studio, R-Linux, UFS Explorer, Hard Disk Sentinel, and the optional legacy HDDSuperClone 2.3.3) is **not** part of this repository. The scripts download it from the vendors; you must comply with each vendor's license/EULA. UFS Explorer's installer wizard is only automated if *you* set `ACCEPT_UFS_EULA=yes` after reading the EULA. **An ISO that contains these programs may not be redistributable** — check each license before sharing an image.
* **Trademarks:** Ubuntu, Xubuntu and Firefox are trademarks of their owners. If you publish an image built from this repository, give it your own name.
* **GPL:** the image contains GPL software; if you distribute an image, you must also offer the corresponding source (the Ubuntu archives and the upstream project pages are the sources used here).
* DMDE, R-Studio etc. are products of their respective authors; this project is not affiliated with them, with Canonical, or with the OpenSuperClone project.
