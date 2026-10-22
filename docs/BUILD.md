# Build guide

How to build the HDDLive live ISO (Xubuntu 24.04.5 remaster for disk diagnostics, cloning and data recovery) from the scripts in `build/`, how the pipeline works, what can go wrong, and how to test the result.

- [1. Purpose and scope](#1-purpose-and-scope)
- [2. Test status (read this first)](#2-test-status-read-this-first)
- [3. Requirements](#3-requirements)
- [4. Quick start](#4-quick-start)
- [5. The pipeline](#5-the-pipeline)
- [6. How the chroot works](#6-how-the-chroot-works)
- [7. How the ISO is assembled](#7-how-the-iso-is-assembled)
- [8. What is compiled or downloaded beyond apt](#8-what-is-compiled-or-downloaded-beyond-apt)
- [9. Pitfalls and lessons learned](#9-pitfalls-and-lessons-learned)
- [10. Testing with QEMU](#10-testing-with-qemu)
- [11. Writing the ISO to a USB stick](#11-writing-the-iso-to-a-usb-stick)
- [12. Optional assets and optional inputs](#12-optional-assets-and-optional-inputs)
- [13. Legal notes](#13-legal-notes)

## 1. Purpose and scope

The scripts take the official **Xubuntu 24.04.5 desktop amd64** ISO, unpack its root filesystem, install and compile a disk-recovery toolkit inside a chroot, and repack everything into a new hybrid (BIOS + UEFI) live ISO. The toolkit centres on [OpenSuperClone](https://github.com/ISpillMyDrink/OpenSuperClone) (compiled from source, plus its DKMS driver), GNU ddrescue, DMDE, TestDisk/PhotoRec, smartmontools, GParted, forensic tools (Sleuth Kit, libewf, bulk_extractor) and up-to-date file system tools. The Desktop is organised into nine folders and the image is English-only.

What the build does **not** do:

- It does not install anything to disk; the result is a live image only.
- It does not ship any proprietary software in this repository. Vendor programs are downloaded at build time (see [Legal notes](#13-legal-notes)).
- It does not embed any license key. DMDE runs as the Free Edition unless you enter your own license in the running program.

## 2. Test status (read this first)

| Item | Status |
|---|---|
| Steps 01 (prepare), 03 (install), 08 (newer), 11 (ufs), 04 (configure), 05 (pack) | Executed; the resulting ISO was produced. |
| Resulting ISO in QEMU: BIOS (CD), UEFI (OVMF), and as a USB stick (`qemu-xhci` + `usb-storage`) | Booted to the desktop. `hddlive-selftest` reported about 70 checks OK, 0 failed (the exact count depends on which optional parts are installed). `md5sum -c` of the mounted media passed. |
| Step 02 (download) | **Only partially exercised end to end.** The download list was validated, but a fresh run of the whole step against all vendor servers has not been completed. Vendor URLs are pinned to specific versions and may move or disappear. |
| Step 10 (Autopsy, optional) | Present in the pipeline; not part of the final tested configuration. |
| Real hardware | **Booted and used on physical PCs in both UEFI and Legacy (BIOS/CSM) modes.** Not covered by this document: Secure Boot (the DKMS module is unsigned, so the virtual-disk mode needs it off) and commercial license activation (UFS Explorer, R-Studio). |

Treat the first build as an experiment: read the logs in `$BUILD_ROOT/logs/` after every step.

## 3. Requirements

Build host:

- Ubuntu 22.04 or newer (other Debian-family hosts may work but are untested), **root** access (`sudo -i`), network access.
- About **40 GB** of free disk space under `$BUILD_ROOT` (base ISO, extracted ISO tree, unpacked root filesystem, downloads, new squashfs and ISO).
- Packages on the host:

```bash
sudo apt-get update
sudo apt-get install xorriso squashfs-tools rsync curl unzip util-linux file coreutils
```

  (`unshare`, `mount`, `dd`, `sha256sum` come from `util-linux`/`coreutils`.)
- For testing only: `qemu-system-x86_64`, `qemu-utils` (`qemu-img`), `ovmf` (the test script expects `/usr/share/OVMF/OVMF_CODE_4M.fd` and `OVMF_VARS_4M.fd`), `python3`, and KVM (`/dev/kvm`).

Inputs:

- **Required:** `xubuntu-24.04.5-desktop-amd64.iso` placed in `$BUILD_ROOT/dl/`. `01-prepare.sh` compares its SHA-256 with the value hard-coded in the script and aborts on a mismatch. Download it from the official Xubuntu release site (and verify it against Canonical's `SHA256SUMS`).
- **Optional:** the original HDDLive ISO as `$BUILD_ROOT/dl/xubuntu-hddlive-x64.iso` (see [section 12](#12-optional-assets-and-optional-inputs)).
- **Optional:** a wallpaper at `build/assets/wallpaper-hawk-data-recovery.png`.

Environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `BUILD_ROOT` | `/opt/hddlive-build` | Working tree. Everything below lives under it. Must be exported identically for every step. |
| `ACCEPT_UFS_EULA` | unset | Must be `yes` for step 11 to run (see [step 11](#step-notes)). |
| `ONLY` | unset | Step 08 only: space-separated list of item names (for example `ONLY="partclone gparted"`) to rebuild only those. |
| `REPACK_ONLY` | unset | Step 05 only: `1` skips cleanup and squashfs and only regenerates the boot menus, `md5sum.txt` and the ISO. |
| `SKIP11`, `STRIP`, `ONLY_LIGHT` | unset | Used by `14-both-finish.sh` (see [section 5](#5-the-pipeline)). |
| `USBMODE`, `ENTRY_DOWN` | unset | Used by `07-test.py` (see [section 10](#10-testing-with-qemu)). |

Layout created under `$BUILD_ROOT`:

```text
build/        the scripts from this repository (must be at $BUILD_ROOT/build)
dl/           inputs and downloads (base ISO, extras/, extras-new/, optional original ISO)
iso-src/      files extracted from the base ISO (becomes the new ISO tree)
rootfs/       the unpacked, merged root filesystem (the chroot)
old-hddlive/  optional files taken from the original HDDLive ISO
out/          resulting ISO and its .sha256
logs/         one log per step (build.log, 10-install.log, 27-newer.log, ...)
efi-part.img, grub-mbr.img   boot pieces saved from the base ISO by step 01
```

## 4. Quick start

The scripts locate each other through `$BUILD_ROOT/build`, so the repository's `build/` directory has to be at that path.

```bash
sudo -i
export BUILD_ROOT=/opt/hddlive-build          # default; change if you want another location
cp -a /path/to/this/repo/build "$BUILD_ROOT/build"
cp /path/to/xubuntu-24.04.5-desktop-amd64.iso "$BUILD_ROOT/dl/"

cd "$BUILD_ROOT"
bash build/01-prepare.sh
bash build/02-download.sh
bash build/03-install.sh
bash build/08-newer.sh
ACCEPT_UFS_EULA=yes bash build/11-ufs.sh      # optional; read the EULA first (see step notes)
bash build/04-configure.sh
bash build/05-pack.sh
ls -la out/
```

Notes:

- Make sure the scripts have **LF** line endings (see [pitfalls](#9-pitfalls-and-lessons-learned)) and are readable by root.
- Run long steps under `nohup`/`tmux`; for example `nohup bash build/08-newer.sh > logs/08.out 2>&1 &`.
- Step 01 refuses to run if `iso-src/` or `rootfs/` is not empty. To start over, remove `rootfs/` and `iso-src/` yourself (the chroot mounts are private and already gone, so a plain `rm -rf` is safe, but double-check the path first).
- The result is `$BUILD_ROOT/out/hddlive-osc-24.04.5-amd64.iso` plus a `.sha256` file next to it. The file name comes from `NEW_ISO_NAME` in `00-common.sh`.

## 5. The pipeline

Run the steps in this order. Each script sources `00-common.sh` (variables, `log()`, `in_chroot()`), writes logs to `$BUILD_ROOT/logs/` and stops on the first error.

| Step | Script | What it does |
|---|---|---|
| 01 prepare | `01-prepare.sh` | Verifies the base ISO's SHA-256. Extracts the ISO to `iso-src/` with xorriso. Saves the appended EFI partition (`efi-part.img`, located from the xorriso system-area report) and the 432-byte GRUB MBR (`grub-mbr.img`). Merges the three layered squashfs files of the 24.04 ISO (`minimal`, `minimal.standard`, `minimal.standard.live`) into one `rootfs/`: the first layer is unsquashed, later layers are unsquashed to a temp dir, overlayfs whiteouts (character device 0:0) are turned into deletions in `rootfs/`, then rsync'd on top. |
| 02 download | `02-download.sh` | Downloads everything that is not in apt into `dl/extras/` (OpenSuperClone `.deb` files and source tarball, ddrescue, DMDE, HD Sentinel, R-Studio, R-Linux, Double Commander, TestDisk, smartmontools, the source tarballs listed in [section 8](#8-what-is-compiled-or-downloaded-beyond-apt), the UFS Explorer installer) and `dl/extras-new/` (btrfs-progs, xfsprogs, e2fsprogs, partclone, fsarchiver, cryptsetup). Each file is skipped if it already exists, so the step can be re-run. If the original HDDLive ISO is present it also extracts ddrescueview and packs the legacy HDDSuperClone modules (see [section 12](#12-optional-assets-and-optional-inputs)). R-Studio and R-Linux downloads are allowed to fail; every other failed download aborts the step. |
| 03 install | `03-install.sh` runs `chroot/10-install.sh` | Copies `dl/extras/` and the chroot scripts into the rootfs and runs `10-install.sh`: `dist-upgrade`; purges snaps and software that does not belong on a recovery system (guarded by an `apt-get -s purge` simulation that aborts if an essential package would be removed); installs the Firefox `.deb` from Mozilla's apt repository (pinned, repository removed afterwards); keeps only the newest kernel; installs the apt toolkit; builds OpenSuperClone and its DKMS driver (`15-osc-build.sh`); builds ddrescue 1.30; installs ddrescueview (if provided), HD Sentinel and R-Studio; masks services that could touch disks on their own (mdadm, smartd, apt timers) and disables SSH. |
| 08 newer | `08-newer.sh` runs `chroot/27-newer.sh` | Installs compile-time dependencies, then builds/installs the newer versions listed in [section 8](#8-what-is-compiled-or-downloaded-beyond-apt). Each item runs in its own `try` wrapper: a failure is recorded as `FAIL <name>` in `logs/newer/results.txt` and the apt version stays in use. Finishes by purging the `-dev` packages and by running `ldd` on every new binary to report missing libraries. Use `ONLY="name ..."` to redo single items. |
| 11 ufs (optional) | `11-ufs.sh` runs `chroot/29-ufs.sh` | Installs UFS Explorer Professional Recovery by driving the vendor's graphical installer under Xvfb with `xdotool`, then installs the Sentinel LDK runtime (`aksusbd`, `hasplmd`) that the program needs for licensing. **Does nothing unless `ACCEPT_UFS_EULA=yes`** (see step notes). |
| 10 autopsy (optional) | `10-autopsy.sh` runs `chroot/28-autopsy.sh` | Installs Java 17, rebuilds Sleuth Kit 4.15.0 with Java bindings and installs Autopsy 4.23.1 (about 1.2 GB more). Run it after 08 and before 04/05. Downloads the Autopsy zip itself if it is not in `dl/autopsy/`. |
| 04 configure | `04-configure.sh` runs `chroot/25-extras.sh` then `chroot/20-config.sh` | `25-extras.sh`: extra apt packages, removes LibreOffice and the Portuguese language packs (English-only image), installs DMDE (stable 4.4.4 and 4.5.0 beta GTK3, **without a license**), Double Commander, R-Linux, TestDisk/PhotoRec 7.2, compiles smartmontools 7.5, writes the seven text guides in `/usr/share/hddlive/cheatsheets/` and `hddlive-selftest`. `20-config.sh`: Desktop in nine folders, udev rule that disables automounting, power/screen-saver settings that never suspend, theme, README, trusted-launcher autostart, wallpaper (if provided). Shortcuts for programs that are not installed are silently omitted. |
| 05 pack | `05-pack.sh` (+ `06-bootmenus.sh`, `chroot/30-cleanup.sh`) | Final cleanup in the chroot, copies kernel and initrd to the ISO tree, builds the single squashfs, writes the manifest, generates the GRUB menus, creates `md5sum.txt` and the hybrid ISO. Details in [section 7](#7-how-the-iso-is-assembled). |
| finish helper | `14-both-finish.sh` | For an already-installed rootfs (01, 03, 08 done): runs 11 (skip with `SKIP11=1`), then 04 and 05 and saves `out/light.iso`; then, unless `ONLY_LIGHT=1`, runs 10, 04 and 05 again and saves `out/full.iso` (with Autopsy). `STRIP=1` first removes Autopsy from a rootfs that already contains it (`chroot/31-strip-autopsy.sh`). |
| test | `07-test.py` + `07-cmds.txt` / `07-cmds-final.txt` | Boot test in QEMU. See [section 10](#10-testing-with-qemu). |

<a id="step-notes"></a>
Step notes:

- **Re-running.** Steps 08, 04 and 05 are meant to be repeatable on the same `rootfs/` (08 supports `ONLY=`); 04 + 05 are the usual "I changed a shortcut or a guide" loop (about 13 minutes on the author's machine). Step 01 must be preceded by deleting `rootfs/` and `iso-src/`.
- **Step 11 and the EULA.** The vendor installer shows a license agreement. The script clicks "I accept" on your behalf, which is why it refuses to run unless you export `ACCEPT_UFS_EULA=yes` after reading and accepting the vendor's EULA yourself. The click coordinates are hard-coded for a 1024x768 Xvfb screen; a different installer version will probably break the automation. If you skip step 11 the image simply has no UFS Explorer, and the self-test skips the related checks.
- **Step 10 versus 14.** `14-both-finish.sh` builds the light ISO first, so Autopsy is added afterwards. If your rootfs already has Autopsy and you want the light ISO, use `STRIP=1`.
- The 05-only variant `REPACK_ONLY=1 bash build/05-pack.sh` is useful after editing only `06-bootmenus.sh`.

## 6. How the chroot works

All work on the root filesystem goes through the `in_chroot` function in `00-common.sh`. It exists so that a build can neither leak mounts to the host nor touch the host's disks.

1. `unshare --mount --propagation private` creates a **private mount namespace**. Every mount made inside disappears when the command exits; nothing is left to unmount and nothing propagates to the host.
2. `/dev` of the chroot is a **minimal tmpfs** (16 MB) populated by hand with `null`, `zero`, `full`, `random`, `urandom`, `tty`, `console`, a fresh `devpts` instance (`/dev/pts`, `/dev/ptmx`), `/dev/shm` and the usual `fd`/`stdin`/`stdout`/`stderr` symlinks. The host's `/dev` is **not** bind-mounted, so the chroot cannot see the build machine's disks and tools like `grub-install`, `mdadm` or `lvm` cannot alter them.
3. `proc`, `sysfs` and tmpfs mounts are added for `/proc`, `/sys`, `/run` and `/tmp` (so anything left in the chroot's `/tmp` is gone after each call).
4. `/etc/resolv.conf` is saved as `resolv.conf.hddlive-orig` and replaced with `nameserver 1.1.1.1`. Edit `00-common.sh` if you prefer another resolver. `05-pack.sh` restores the original file at the end.
5. `/usr/sbin/policy-rc.d` is written with `exit 101`, so package installs never start services inside the chroot. It is removed again by `05-pack.sh`.
6. The command is started through `chroot ... /usr/bin/env -i` with a clean environment (`HOME=/root`, a fixed `PATH` that puts `/usr/local` first, `DEBIAN_FRONTEND=noninteractive`, `LC_ALL=C`).

Scripts and downloads are copied into `rootfs/root/` before each step and removed again afterwards; `30-cleanup.sh` also deletes `/root/extras`, `/root/hddlive`, caches, logs, SSH host keys, `machine-id` and the random seed so none of the build leaks into the image.

DKMS and `uname`: DKMS builds the OpenSuperClone driver for `uname -r`, which inside the chroot is the *host's* kernel. `10-install.sh` and `15-osc-build.sh` therefore temporarily replace `/usr/bin/uname` with a shim that answers `-r` with the newest kernel installed in the image (an `EXIT` trap restores the real binary).

## 7. How the ISO is assembled

Done by `05-pack.sh` (with `06-bootmenus.sh`):

1. **Cleanup in the chroot** (`30-cleanup.sh`): clears build-host RAID/crypt configuration so the initramfs does not try to assemble the build server's volumes, disables cloud-init, **removes `casperize.conf` and `default-layer.conf` from `/etc/initramfs-tools/conf.d/`** (see [pitfall 1](#9-pitfalls-and-lessons-learned)), runs `update-initramfs -u`, `depmod`, `autoremove --purge`, `apt-get clean`, and wipes logs, SSH host keys and `machine-id`.
2. **Kernel and initrd** are copied from the rootfs to `iso-src/casper/vmlinuz` and `initrd` (newest kernel in `/lib/modules`).
3. **Single squashfs.** The layered `*.squashfs`, manifests, `SHA256SUMS*` and `install-sources.yaml` of the base ISO are removed and the whole merged rootfs is written as `casper/filesystem.squashfs` (`mksquashfs ... -comp xz -Xbcj x86 -b 1M`). `filesystem.manifest` (package list) and `filesystem.size` are regenerated.
4. **Boot menus** (`06-bootmenus.sh`): on 24.04 both BIOS and UEFI boot through GRUB, so only `boot/grub/grub.cfg` and `loopback.cfg` are written. Entries: try without installing; disable one SATA port (`libata.force=X:disable`, press `e` and replace `X`); load into RAM (`toram`); safe graphics (`nomodeset`); check disc for defects (`integrity-check`); plus "Boot from next volume" and "UEFI Firmware Settings" on UEFI, or "Test memory" on BIOS. `boot=casper` is passed explicitly because the initrd regenerated in the chroot does not assume casper on its own. The menu title is English and `.disk/info` is rewritten.
5. **`md5sum.txt` in two passes.** The first pass hashes the tree and builds the ISO. xorriso then patches `boot/grub/i386-pc/eltorito.img` (boot-info-table / GRUB2 boot info), so the file inside the ISO no longer matches the hash of the file in the tree and "Check disc for defects" would report an error. The second pass extracts the patched `eltorito.img` back into the tree, regenerates `md5sum.txt` and builds the ISO again.
6. **Hybrid ISO** with a single xorriso (`-as mkisofs`) call, equivalent to what Ubuntu uses:

```text
xorriso -as mkisofs -r -V "HDDLive 24.04.5" -J -joliet-long -cache-inodes -iso-level 3 \
  --grub2-mbr grub-mbr.img --protective-msdos-label \
  -partition_cyl_align off -partition_offset 16 --mbr-force-bootable \
  -append_partition 2 <EFI-system-partition-GUID> efi-part.img -appended_part_as_gpt \
  -iso_mbr_part_type <basic-data-GUID> \
  -c /boot.catalog -b /boot/grub/i386-pc/eltorito.img -no-emul-boot -boot-load-size 4 \
     -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot -e '--interval:appended_partition_2:::' -no-emul-boot -boot-load-size 10160 \
  -o out/hddlive-osc-24.04.5-amd64.iso iso-src
```

   BIOS boots from the GRUB El Torito image, UEFI from the appended FAT partition (`efi-part.img`, taken unchanged from the base ISO), and the GPT/MBR layout lets the same file be written to a USB stick.
7. **Verification and checksum.** In a private mount namespace the new ISO is loop-mounted (temporary mount point `/mnt/hddliveiso24`) and `md5sum -c md5sum.txt` is run; the number of OK and failed entries is printed and logged to `logs/md5-verify.log`. Finally `sha256sum` is written to `out/<iso>.sha256`.

The ISO tree still carries `pool/`, `dists/`, `install/` and `preseed/` from the official ISO; these are candidates for pruning if you want a smaller image.

## 8. What is compiled or downloaded beyond apt

Everything below goes to `/usr/local` or `/opt` and wins in `PATH`; the apt version stays installed as a fallback. Versions are those pinned in the scripts.

| Group | Items | Where |
|---|---|---|
| Built from source in `10-install.sh` | OpenSuperClone 2.6.0-alpha1 (re-packaged `.deb` + DKMS driver `oscdriver`; the stable 2.5.0 `.deb` is kept in `/usr/share/hddlive/osc-stable/`), ddrescue 1.30 | `15-osc-build.sh`, `10-install.sh` |
| Pre-built vendor binaries (`10-install.sh`, `25-extras.sh`, `27-newer.sh`) | HD Sentinel 0.20c, R-Studio 5 (`.deb`), R-Linux 6 (`.deb`), DMDE 4.4.4 and 4.5.0 beta GTK3, Double Commander 1.2.9, TestDisk/PhotoRec 7.2 (static), TestDisk 7.3-WIP (static, as `testdisk-wip`/`photorec-wip`), rclone (current release at download time) | `/opt`, `/usr/local` |
| Compiled by `27-newer.sh` (`try`-isolated) | hdparm 9.65, sg3_utils 1.49, exfatprogs 1.4.3, nilfs-utils 2.3.1, mdadm 4.6 (binaries only), libewf 20260924, Sleuth Kit 4.15.0 (no Java), ntfs-3g/ntfsprogs 2026.9.28 (tools only, in `/opt/ntfs-3g`), bulk_extractor 2.2.0, QPhotoRec (from TestDisk 7.2 sources), GSmartControl 2.0.2, GParted 1.8.1, nvme-cli 3.1, btrfs-progs 7.1, xfsprogs 7.2.1, e2fsprogs 1.47.4, partclone 0.3.50, fsarchiver 0.8.9, cryptsetup 2.8.0 (in `/opt/cryptsetup`) | `/usr/local`, `/opt` |
| Compiled in `25-extras.sh` | smartmontools 7.5 | `/usr/local` |
| Extra apt installs in `27-newer.sh` | binwalk, libguestfs-tools (only if it does not pull another kernel), multipath-tools (masked) | apt |
| Optional | UFS Explorer Professional Recovery plus Sentinel LDK runtime (step 11), Autopsy 4.23.1 with Java 17 and Sleuth Kit Java bindings (step 10) | `/opt` |
| Optional (from the original HDDLive ISO) | ddrescueview 0.4.5, legacy HDDSuperClone 2.3.3 / HDDSCViewer / `hddscripts` | see [section 12](#12-optional-assets-and-optional-inputs) |

Packages that are masked or disabled on purpose so a recovery session never touches disks by itself: mdadm and smartd services, the udev rule that auto-assembles MD RAID, all ZFS import/mount services, multipath, SSH (installed but off), plus the `99-disable-udisk-automount` udev rule.

## 9. Pitfalls and lessons learned

Read these before changing the scripts. Most were found the hard way while building 24.04.

1. **casper: "Unable to find a medium containing a live file system".** The initramfs generated inside the chroot inherits `/etc/initramfs-tools/conf.d/casperize.conf` (`CASPER_GENERATE_UUID=1`, which writes a UUID to `/conf/uuid.conf` that the ISO would have to carry in `.disk/casper-uuid-generic`) and `default-layer.conf` (`LAYERFS_PATH=minimal.standard.live.squashfs`). Because our ISO has **one** squashfs, both files are removed before `update-initramfs` (`30-cleanup.sh`). To diagnose boot problems: `unmkinitramfs` the initrd and boot with `qemu -kernel ... -initrd ...` plus `console=ttyS0`.
2. **`dpkg -S /lib/...` fails on 24.04 (usrmerge).** The step that marks runtime libraries as manually installed before `autoremove` left `bulk_extractor` without `libre2`. The script now resolves each library with `readlink -f` first, and there is a final `ldd` check over all newly installed binaries.
3. **`apt-cache show` does not detect "no candidate"** (virtual or removed packages such as `hddtemp`, `exfat-utils`). Use `apt-cache policy` and read the `Candidate:` line. Do not pipe it into `grep -q` under `pipefail`: the early exit raises SIGPIPE and kills `apt-cache`.
4. **`curl` is missing in the live rootfs.** Install `curl ca-certificates gnupg` before adding Mozilla's repository, and retry `apt-get update` (the mirror is sometimes mid-sync: "File has unexpected size").
5. **OpenSuperClone `.deb` repacking.** After rewriting the `Depends:` line in `DEBIAN/control`, remove blank lines; otherwise `dpkg-deb` complains about "several package info entries". The source tarball is not a git checkout, so `GIT_REVISION` is empty and the build fails with "undeclared"; the script injects the tag name into `CMakeLists.txt`. `package.sh` also tries to build an `.rpm` and fails without `rpmbuild` after the `.deb` is already produced; that failure is tolerated. The `oscdriver` DKMS module is built against the image's kernel, not the host's (shim for `uname -r`, see section 6); it may need patches for kernels newer than the one used when this was written.
6. **GSmartControl, GParted, partclone specifics.** GSmartControl 2.0.2 installs into `/usr/local/sbin`, not `bin` (the script adds a symlink). GParted needs polkit ITS rules for `msgfmt`; the script creates `/usr/share/gettext/its/polkit.its` and `polkit.loc`. partclone needs `libxxhash-dev`, the ntfs-3g headers from `/opt/ntfs-3g`, and `make install-exec` (the GitHub tarball has no generated man pages).
7. **UFS Explorer leftovers.** The installer wizard leaves `/etc/sdlcfg` and `/root/.sdl`; if they exist, reinstalling shows "Damaged software installation detected". `29-ufs.sh` removes them first. The program also needs the **Sentinel LDK runtime** (`aksusbd` + `hasplmd`); without it you get "Sentinel License Manager is not running". The script extracts the vendor's `trte64.tar.gz`, copies the unit files and enables the services; the self-test checks that `hasplmd` is active.
8. **GRUB only.** On the 24.04 ISO both BIOS and UEFI use GRUB; the `-e '--interval:appended_partition_2:::'` option takes the EFI image from the appended partition. `md5sum.txt` needs two passes (section 7).
9. **Packages that vanished or were renamed in noble:** `hddtemp`, `bless`, `exfat-utils` (use `exfatprogs`), `dd-rescue`, `testdisk-doc`, `sleuthkit-doc`. `t64` names such as `libgtk2.0-0t64`, `libgtk-3-0t64`. Firefox and Thunderbird are snaps in Ubuntu: snapd is removed and Firefox comes from Mozilla's apt repository (pin priority 1001); the repository file is deleted at the end so the image carries no third-party sources.
10. **Xfce 4.18 "Untrusted application launcher".** Thunar/xfdesktop only run `.desktop` files that have `+x` **and** a `metadata::xfce-exe-checksum` attribute equal to the file's SHA-256. The live home is created from `/etc/skel` at every boot, so `hddlive-trust-launchers` runs at login (autostart) and calls `gio set` on every launcher.
11. **Wallpaper canvas trick.** xfdesktop does not inherit the colour from `rgba1`, so "scaled + black background" produced blue bars. Solution: supply the wallpaper already padded onto a **4:3 canvas** and set `image-style=5` (zoom). No bars, and the logo is not cropped at 4:3 or 16:10.
12. **`apt-get -s purge` prints `Purg`, not `Remv`.** Any safety check that greps the simulation (the snap removal in `10-install.sh`, the LibreOffice removal in `25-extras.sh`, `31-strip-autopsy.sh`) must match both. When removing LibreOffice, first mark the dependencies of the `xubuntu-desktop` meta package as manual, otherwise a later `autoremove` takes Xfce with it.
13. **Script line endings must be LF.** Editing or checking out on Windows can convert `.sh` files to CRLF and break them in baffling ways. Use `.gitattributes` with `*.sh text eol=lf` or `git config core.autocrlf input`.
14. **Never `pkill -f` with an empty pattern** (it matches everything and kills the session). The self-test builds the target name defensively, aborts if it is empty and uses `pkill -x`. Likewise never purge from raw `comm` package lists without an explicit filter: `27-newer.sh` removes only `-dev` packages and a short named list of build tools that did not exist before.
15. **`set -e` is ignored inside `if ( ... )`** and in functions called from a condition. `try()` in `27-newer.sh` runs the item as a plain command in a subshell (`( set -e; "$@" )`) so that a failure is detected.
16. **Build order and versions.** Build Sleuth Kit **before** the new libewf (TSK 4.15 only compiles against apt's older libewf API; `27-newer.sh` removes any libewf from `/usr/local` first, and `28-autopsy.sh` moves it aside temporarily). `bulk_extractor` needs `-Werror` and `-std=c++11` stripped from every Makefile. nvme-cli 3.x needs meson 1.0 or newer (installed in a throw-away venv). sg3_utils 1.49 needs `./autogen.sh`. ntfs-3g tools are installed in their own prefix without the mount helper so Ubuntu's patched `mount.ntfs-3g` stays in charge. The xfsprogs install is staged and only binaries are copied.
17. **DMDE only starts with its own directory as the working directory** (from another directory it exits silently). `/usr/local/bin/dmde` is therefore a small wrapper that `cd`s into `/opt/dmde` and runs `./dmde`. Remove any old symlink at `/usr/local/bin/dmde` *before* writing the wrapper, otherwise the redirect overwrites the real binary and the wrapper calls itself forever. DMDE is installed with no license; the Desktop README tells users that they can enter their own license in the running program (Help > License) or in `dmde.ini`; it is lost when the live session ends.
18. **Mounts and `/dev` in the chroot.** Never bind-mount the host's `/dev` into the chroot for convenience; the whole point of `in_chroot` is that the chroot cannot see real disks.
19. **Autopsy needs its own care.** The TSK Java bindings need `/usr/lib/libtsk_jni.so` (a symlink; the default `java.library.path` does not include `/usr/local/lib`), JavaFX comes inside Autopsy's jars, and only the JRE is kept after the JDK and `ant` are purged.
20. **Compile-time packages must never be removed blindly.** `27-newer.sh` snapshots the package list before installing dependencies and purges only the difference that matches `-dev`/build-tool patterns; the final `ldd` loop tells you if you broke something.

## 10. Testing with QEMU

`build/07-test.py` boots an ISO headless under QEMU/KVM, takes screenshots through the QMP socket, opens a terminal, types commands and saves PNGs.

```bash
# BIOS (CD-ROM)
python3 build/07-test.py bios out/hddlive-osc-24.04.5-amd64.iso test/bios --cmds build/07-cmds-final.txt
# UEFI (OVMF)
python3 build/07-test.py uefi out/hddlive-osc-24.04.5-amd64.iso test/uefi --cmds build/07-cmds-final.txt
# the same ISO as a USB stick (qemu-xhci + usb-storage)
USBMODE=1 python3 build/07-test.py bios out/hddlive-osc-24.04.5-amd64.iso test/usb --cmds build/07-cmds-final.txt
```

What it does:

- Starts `qemu-system-x86_64 -enable-kvm -cpu host -m 4096 -smp 4`, a 512 MB raw "test disk" (serial `HDDLIVE-TEST`) so there is something to list, and for UEFI the OVMF 4M firmware with a fresh copy of the variables file.
- Screenshots at 4 s (boot menu), 35 s (booting) and 125 s (desktop); then presses Ctrl+Alt+T (twice), runs the commands from the file and takes a screenshot every third command.
- `ENTRY_DOWN=n` presses the Down key *n* times and Enter in the boot menu, to test other menu entries.
- Keystrokes are sent as **US-layout** scancodes, so non-US layouts would produce different characters.
- The command file supports `@sleep N`, `@key NAME` and `@shot NAME` lines. `07-cmds.txt` is a quick sanity list (kernel, `lsblk`, `modprobe oscdriver`, tool versions, DKMS status). `07-cmds-final.txt` runs `hddlive-selftest`, waits 5 minutes, greps for `FAIL`, then starts DMDE and takes a screenshot of its start dialog so you can see which edition it reports (it should be the Free Edition).

For a manual look without the script:

```bash
qemu-system-x86_64 -enable-kvm -cpu host -m 4096 -smp 4 -vga std -cdrom out/hddlive-osc-24.04.5-amd64.iso -boot d
# UEFI: add the OVMF pflash drives, e.g.
#   -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd
#   -drive if=pflash,format=raw,file=/path/to/copy-of/OVMF_VARS_4M.fd
```

In the boot menu, "Check disc for defects" runs `md5sum.txt` verification against the media.

### What the self-test checks

`hddlive-selftest` (installed by `25-extras.sh`; run it as the live user in a terminal) prints `[ OK ]` / `[FAIL]` per check and a final `Result: N OK, M failed`. Checks cover:

- Kernel and `modprobe oscdriver` (needs root; Secure Boot must be off).
- Presence of the main commands and about 30 installed programs (DMDE and the beta, R-Studio, HD Sentinel, PhotoRec, GParted, Guymager, GSmartControl, ddrescueview, wxHexEditor, Clonezilla, partclone, fsarchiver, foremost, scalpel, mdadm, LVM, cryptsetup, dislocker, Sleuth Kit, ewf tools, R-Linux ...).
- Pinned versions of the compiled tools: hdparm 9.65, mdadm 4.6, nvme-cli 3.x, Sleuth Kit 4.15, ddrescue 1.30, smartmontools 7.5, btrfs-progs 7.x, xfsprogs 7.x, e2fsprogs 1.47.4, partclone 0.3.50, fsarchiver 0.8.9, cryptsetup 2.8, ntfsprogs 2026.x, bulk_extractor 2.2, GSmartControl in `/usr/local/sbin`.
- ZFS module and tools, Firefox from the Mozilla `.deb` (not the snap), the anti-automount udev rule, the English-only check (no `language-pack-pt*`) and the trusted-launcher metadata.
- Conditional checks that only run if the part is installed: Autopsy and Java 17, UFS Explorer and the Sentinel License Manager, legacy HDDSuperClone.
- With a graphical session, it opens each GUI (DMDE, Double Commander, GSmartControl, GParted, Guymager, ddrescueview, wxHexEditor, HardInfo, UFS Explorer, QPhotoRec, OpenSuperClone viewer and main window, Autopsy) for 10 seconds, checks that the process is still alive and closes only that program.

If you skip optional inputs (for example no ddrescueview), the corresponding checks are expected to fail; edit the list in `chroot/25-extras.sh` if you want a clean report.

## 11. Writing the ISO to a USB stick

The image is a hybrid ISO and boots in BIOS and UEFI mode from a USB stick. **Everything on the stick is overwritten**; double-check the device name, because writing to the wrong device destroys data.

Linux:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN            # identify the stick, e.g. /dev/sdX (not a partition like sdX1)
sudo umount /dev/sdX* 2>/dev/null
sudo dd if=out/hddlive-osc-24.04.5-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

Windows or macOS: use a tool that writes the raw image, for example Rufus (choose **DD Image** mode when asked) or balenaEtcher.

Afterwards verify the file with the `.sha256` that `05-pack.sh` wrote next to the ISO (`sha256sum -c`). On real hardware remember:

- Disable Secure Boot if you need the `oscdriver` kernel module (it is not signed). Booting itself should work because the EFI partition is the one from the official ISO, but this has not been verified.
- To keep a failing drive from being touched by the kernel at all, use the "disable ataX" boot entry.
- The live user is `xubuntu` with passwordless `sudo`; SSH is installed but off. Automatic mounting of disks is disabled.

## 12. Optional assets and optional inputs

**Wallpaper (`build/assets/`).** If `build/assets/wallpaper-hawk-data-recovery.png` exists, `04-configure.sh` copies it into the chroot and `20-config.sh` installs it as the default Xfce wallpaper. The image must already be padded onto a 4:3 canvas (see pitfall 11). If the file is missing, a warning is printed and the stock Xubuntu wallpaper stays. The `assets/` directory in the repository may be empty.

**Original HDDLive ISO (`$BUILD_ROOT/dl/xubuntu-hddlive-x64.iso`).** Entirely optional. If present, `02-download.sh`:

- extracts `home/ddrescueview-linux-x86_64` into `$BUILD_ROOT/old-hddlive/`. `03-install.sh` copies it into the rootfs and `10-install.sh` installs it under `/opt/ddrescueview`, with a `ddrescueview` symlink in `/usr/local/bin`;
- packs the legacy HDDSuperClone 2.3.3 programs (`hddsuperclone`, `hddscviewer`, the 47 `hddscripts` and the uninstall scripts) into `dl/extras-new/legacy-hddsuperclone-2.3.3.tar.gz`.

If the ISO is absent, those parts are **skipped**: no ddrescueview (the install script prints a warning) and no legacy tarball. The Desktop generator omits shortcuts whose programs are missing, so the image still builds.

Step 04 (`chroot/25-extras.sh`) unpacks `dl/extras-new/legacy-hddsuperclone-2.3.3.tar.gz` into the image when it exists. OpenSuperClone already provides equivalent scripts (`/usr/bin/oscscripts`), so nothing essential is lost without it.

## 13. Legal notes

- **This repository contains only scripts and documentation**, released under the MIT license. It does not contain, and the MIT license does not cover, any of the third-party software the scripts download.
- **Proprietary software is downloaded from the vendors at build time**: DMDE, R-Studio, R-Linux, UFS Explorer (with its Sentinel LDK runtime), Hard Disk Sentinel and, if you supply the original HDDLive ISO, the legacy HDDSuperClone modules. Each is subject to its own vendor license, which you must read and accept yourself. In particular, step 11 will not run until you set `ACCEPT_UFS_EULA=yes`, and by doing so you declare that you have read and accepted the vendor's EULA. No license keys are included or required for the build; DMDE is installed without a license.
- **The resulting ISO may not be redistributable** if it includes any of those proprietary components. Treat an ISO built with them as being for your own use. Check each vendor's terms before sharing it, or build a variant without them (skip step 11, remove the corresponding downloads and installs).
- **Trademarks.** Ubuntu and Xubuntu are trademarks of Canonical Ltd.; Firefox and Mozilla are trademarks of the Mozilla Foundation. The image is a derivative remix and is not endorsed by either. If you publish an ISO, **rename the product** (volume label, boot menu titles, `.disk/info`, wallpaper) and follow Canonical's and Mozilla's trademark and redistribution policies.
- **GPL and other open-source licenses.** The image contains many GPL-licensed programs (the Linux kernel, GNU ddrescue, Sleuth Kit, GParted, GSmartControl, partclone, the OpenSuperClone driver and others), some of them compiled by these scripts. If you distribute the ISO, you must comply with their licenses, including making the corresponding source available or providing a written offer for it. Keep the source tarballs from `dl/extras/` and `dl/extras-new/`, the patches applied by the scripts, and the matching source packages for the Ubuntu packages (`apt-get source`, or Canonical's source archives) for that purpose.
- **No warranty and data-loss warning.** The tools in the image can irreversibly modify or erase disks (partition editors, firmware and erase scripts, wipe tools). Always work on a clone and test on disposable media first. This is not legal advice.
