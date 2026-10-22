# Step-by-step: build, test and write the HDDLive ISO

A copy-and-paste walkthrough. For the reasons behind each step, the pitfalls and the legal notes see [BUILD.md](BUILD.md); for what ends up in the image see [PROGRAMS.md](PROGRAMS.md).

Expected time on a modern machine with a fast connection: **about 60 minutes** (downloads + ~10 min compiling the newest tools + ~8 min compressing the squashfs).

## 0. Prepare the build host

You need Ubuntu 22.04 or newer with root, about 40 GB of free disk and internet access.

```bash
sudo apt update
sudo apt install xorriso squashfs-tools rsync curl unzip git
# only if you want to test the ISO in a VM:
sudo apt install qemu-system-x86 ovmf
```

Choose a working folder (default `/opt/hddlive-build`; any path works if you export `BUILD_ROOT`):

```bash
export BUILD_ROOT=/opt/hddlive-build
sudo mkdir -p "$BUILD_ROOT/dl"
```

Download the official **Xubuntu 24.04.5 desktop amd64** ISO and put it in `$BUILD_ROOT/dl/` as `xubuntu-24.04.5-desktop-amd64.iso`. `01-prepare.sh` verifies its SHA-256 and stops if it does not match.

Get the scripts:

```bash
git clone https://github.com/hawkinf/hddlive-osc
sudo cp -a hddlive-osc/build "$BUILD_ROOT/build"
cd "$BUILD_ROOT"
```

> All commands below run from `$BUILD_ROOT` as root. `sudo` keeps your exported `BUILD_ROOT` only if you use `sudo -E`; the examples therefore pass it explicitly. If you kept the default path you can drop the prefix.

## 1. Extract and merge the base image

```bash
sudo BUILD_ROOT="$BUILD_ROOT" bash build/01-prepare.sh
```

What it does: checks the ISO hash, extracts it to `iso-src/`, merges the layered squashfs (minimal + standard + live) into a single `rootfs/`, and saves the EFI partition image and the GRUB MBR needed to rebuild a hybrid ISO.
Check: `rootfs/` contains a full Linux tree and `logs/` has no errors.

## 2. Download what is not in apt

```bash
sudo BUILD_ROOT="$BUILD_ROOT" bash build/02-download.sh
```

Downloads OpenSuperClone, ddrescue, DMDE, Hard Disk Sentinel, R-Studio, R-Linux, Double Commander, TestDisk, smartmontools and the source tarballs of the tools compiled in step 8 into `dl/extras/` and `dl/extras-new/`. Existing files are skipped, so you can re-run it. If one vendor URL has changed, edit the matching `get` line in the script.

*Optional inputs* (skipped when absent): put the original HDDLive ISO `xubuntu-hddlive-x64.iso` in `dl/` before this step to also extract `ddrescueview` and the legacy HDDSuperClone 2.3.3 modules.

## 3. Install the base system (inside a chroot)

```bash
sudo BUILD_ROOT="$BUILD_ROOT" bash build/03-install.sh
```

Dist-upgrade, removes snaps and unwanted packages, installs Firefox from the Mozilla `.deb`, installs the apt tool kit, builds and installs OpenSuperClone with its DKMS driver for the image kernel, compiles ddrescue 1.30, installs Hard Disk Sentinel and R-Studio.
Check: the log `logs/10-install.log` ends with `END 10-install`, and `dkms status` inside the chroot lists `oscdriver ... installed`.

## 4. Compile the newest tool versions

```bash
sudo BUILD_ROOT="$BUILD_ROOT" bash build/08-newer.sh
```

Builds rclone, hdparm, sg3_utils, exfatprogs, nilfs-utils, mdadm, TestDisk 7.3-WIP, libewf, Sleuth Kit, ntfsprogs, bulk_extractor, QPhotoRec, GSmartControl, GParted, nvme-cli, btrfs-progs, xfsprogs, partclone, fsarchiver, cryptsetup, e2fsprogs. Each item is isolated: a failure keeps the apt version and is reported in `logs/newer/results.txt`.
Check: `logs/newer/results.txt` shows `OK` for every item and `all libraries resolved` at the end.

## 5. (Optional) UFS Explorer

```bash
sudo ACCEPT_UFS_EULA=yes BUILD_ROOT="$BUILD_ROOT" bash build/11-ufs.sh
```

Read the SysDev EULA first. This step drives the installer wizard and clicks "I accept" on your behalf, which is why it refuses to run without `ACCEPT_UFS_EULA=yes`. It also installs the Sentinel runtime the program needs for licensing. Skipping it is fine; the UFS launchers and self-test checks are then left out automatically.

## 6. (Optional) Autopsy

Not part of the default image. To add it:

```bash
sudo BUILD_ROOT="$BUILD_ROOT" bash build/10-autopsy.sh
```

Installs Java 17, Sleuth Kit with Java bindings and Autopsy 4.23.1 (about +1.8 GB). To remove it again from a rootfs that already has it: `STRIP=1 ONLY_LIGHT=1 bash build/14-both-finish.sh`.

## 7. Configure the desktop

```bash
sudo BUILD_ROOT="$BUILD_ROOT" bash build/04-configure.sh
```

Installs DMDE (Free Edition, no license), Double Commander, R-Linux, TestDisk 7.2, smartmontools 7.5, the legacy HDDSuperClone (if provided), removes LibreOffice, writes the 9 Desktop folders with launchers, the 7 cheat sheets, the README, the udev rule that disables auto-mount, the power/screensaver defaults and the `hddlive-selftest` command. An optional wallpaper placed in `build/assets/wallpaper-hawk-data-recovery.png` is installed here.
Safe to re-run after editing scripts (it rewrites the Desktop and guides).

## 8. Pack the ISO

```bash
sudo BUILD_ROOT="$BUILD_ROOT" bash build/05-pack.sh
```

Cleans the chroot, regenerates the initramfs, compresses `rootfs/` into a single `filesystem.squashfs` (xz), writes the GRUB menus, creates `md5sum.txt` and builds the hybrid BIOS+UEFI ISO.
Result: `$BUILD_ROOT/out/hddlive-osc-24.04.5-amd64.iso` and its `.sha256`. The log ends with `md5 failures: 0`.

If you only change desktop/config files later, repeat steps 7 and 8 (≈13 min); there is no need to redo the earlier steps.

## 9. Test in QEMU

```bash
# BIOS, as a CD
python3 build/07-test.py bios out/hddlive-osc-24.04.5-amd64.iso test/bios --cmds build/07-cmds-final.txt
# UEFI
python3 build/07-test.py uefi out/hddlive-osc-24.04.5-amd64.iso test/uefi --cmds build/07-cmds-final.txt
# BIOS, as a USB disk (how it will really be used)
USBMODE=1 python3 build/07-test.py bios out/hddlive-osc-24.04.5-amd64.iso test/usb --cmds build/07-cmds-final.txt
```

The script boots the ISO headless, takes screenshots (`test/*/bios-03-desktop.png`, `...-05a-selftest.png`) and runs `hddlive-selftest`. Expected: `Result: ~70 OK, 0 failed`. To open a different GRUB entry set `ENTRY_DOWN=<n>`.
A UFS Explorer license window may stay open at the end of the self-test; that is expected when UFS is installed and has no license.

## 10. Write it to a USB stick

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL                      # identify the stick: DOUBLE-CHECK /dev/sdX
sudo dd if=out/hddlive-osc-24.04.5-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

On Windows use Rufus in **"DD Image"** mode, or Ventoy. Boot in BIOS or UEFI; to use OpenSuperClone's *Virtual Disk* mode turn **Secure Boot off** (the DKMS module is unsigned).

## Troubleshooting

| Symptom | What to check |
|---|---|
| `01-prepare.sh` says the SHA-256 does not match | you downloaded a different 24.04 point release; the script is pinned to 24.04.5 |
| A vendor download fails in step 2 | the vendor changed the URL; fix the `get` line and re-run (finished files are skipped) |
| Boot stops with "Unable to find a medium containing a live file system" | the initramfs kept `casperize.conf` / `default-layer.conf`; `chroot/30-cleanup.sh` removes them before `update-initramfs` — see BUILD.md |
| DKMS fails to build `oscdriver` | the kernel headers of the image kernel are missing (they are installed in step 3) |
| A tool is missing after step 4 | read `logs/newer/<tool>.log`; the apt version stays installed as a fallback |
| Scripts fail with `\r: command not found` | the files have Windows line endings; the repository's `.gitattributes` forces LF — re-clone on Linux or run `sed -i 's/\r$//'` |
