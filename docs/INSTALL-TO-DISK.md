# Making HDDLive permanent: install to a disk, or keep it on the USB stick

HDDLive normally runs as a **live system**: it boots from the USB stick or DVD, runs from RAM, and forgets everything at shutdown. There is **no graphical installer** in the image (it is a rescue system, so the installer was removed on purpose). There are two supported ways to make it permanent:

| | Install to a disk | Persistence on the USB stick |
|---|---|---|
| What you get | A normal installed system on an internal/external disk, boots by itself | The live USB keeps your changes (settings, licenses, files) |
| Effort | one command: `hddlive-install` | create one partition + pick a boot entry |
| Boots in | Legacy/BIOS **and** UEFI | whatever the stick boots in |
| Risk | **erases the chosen disk** | changes live on the stick |

> **Never use the failing customer disk as the target.** Both methods are for *your own* disks.

## 1. `hddlive-install` — install to a disk

Run it from the live session. There is also a **Desktop shortcut** ("Install HDDLive to disk") and a built-in cheat sheet (`/usr/share/hddlive/cheatsheets/8-install-to-disk.txt`).

```bash
sudo hddlive-install                                   # interactive: lists the disks and asks everything
sudo hddlive-install /dev/sdb --user tech --hostname hddlive
sudo hddlive-install --help
```

Options: `DISK` (e.g. `/dev/sdb`, `/dev/nvme0n1`), `--user NAME`, `--hostname NAME` (default `hddlive`), `--squashfs PATH`, `--yes` (skips the final *type the device and ERASE* confirmation; passwords are always asked).

### What it does, in order
1. Finds `casper/filesystem.squashfs` on the live media (`/cdrom`, `/run/live/medium`…). If you booted with *load into RAM*, mount the USB stick yourself and pass `--squashfs /path/casper/filesystem.squashfs`.
2. Shows the disks (size, model, serial, transport) and **refuses** the disk that holds the live media, anything that is not a whole disk, a disk with mounted partitions, and disks smaller than 12 GB.
3. Asks for the user name, host name and password **before** touching the disk, then asks you to type the device path and the word `ERASE` (unless `--yes`).
4. Partitions the target as **GPT**: 2 MiB `bios_grub`, 512 MiB EFI System Partition (FAT32), the rest as ext4 (`hddlive`).
5. Copies the system with `unsquashfs`, writes `fstab` (by UUID), host name and `hosts`.
6. In a chroot: creates your user (groups `sudo adm plugdev dialout cdrom disk`) and sets the password, rebuilds the initramfs, installs GRUB for **BIOS** (`i386-pc`) and for **UEFI** twice — the normal entry (`--bootloader-id=ubuntu`, which also writes the firmware boot entry when you booted in UEFI) and the **removable fallback** (`EFI/BOOT/BOOTX64.EFI`) — and runs `update-grub`.
7. Unmounts and tells you to reboot and remove the USB stick.

### Design decisions you should know about
* **os-prober is disabled** in the installed system (`GRUB_DISABLE_OS_PROBER=true`). os-prober mounts other disks to look for operating systems; on a rescue machine you do not want the bootloader doing that on its own. Add other systems to GRUB by hand if you need a dual-boot.
* The **bench protections stay on**: no auto-mounting (udev rule `99-disable-udisk-automount.rules`), RAID/ZFS/multipath not assembled automatically, no screensaver/suspend. To get normal desktop behaviour back, remove that udev rule and `systemctl unmask` the services you want.
* The OpenSuperClone driver (`oscdriver`) is built for the image kernel; if `apt` installs a newer kernel, DKMS rebuilds it (headers and gcc are in the image). The module still does not load with **Secure Boot** enabled (it is unsigned).
* The installed system keeps the HDDLive desktop, launchers, cheat sheets and self-test.

### Why both GRUB variants are installed
On Ubuntu, the signed GRUB used for UEFI reads its configuration from `EFI/ubuntu`, not from `EFI/BOOT`. In a first test using only `--removable`, the UEFI boot stopped at the `grub>` prompt; adding the normal `--bootloader-id=ubuntu` install fixed it. If the live session was booted in Legacy mode, firmware boot entries cannot be written (no NVRAM access), so the script uses `--no-nvram` and relies on the removable fallback.

### Tested
* `hddlive-install` was run end to end **from the live ISO in QEMU** onto a blank 24 GB virtual disk (about 7 minutes: partitioning, copying the system, initramfs, GRUB for BIOS and UEFI).
* The disk it produced **booted to the login screen and the desktop in BIOS (SeaBIOS) and in UEFI (OVMF)**, with the user and password given to the script.
* Not verified: installation onto every kind of real disk/controller (NVMe naming `p1/p2/p3` is handled by the script but was not exercised), and the persistence entry on real USB sticks.

## 2. Persistence on the USB stick

Casper (the live-boot component) can store changes in a partition labeled `casper-rw`.

1. Write the ISO to the stick (`dd` or Rufus in *DD Image* mode). Free space remains after the image.
2. Create a partition in the free space and label it `casper-rw` (replace `sdX`; check with `lsblk` first):
   ```bash
   sudo parted /dev/sdX mkpart persist ext4 <end-of-the-last-partition> 100%
   sudo mkfs.ext4 -L casper-rw /dev/sdX3
   ```
3. Boot the entry **"HDDLive - persistent (needs a partition labeled casper-rw)"**.

Without that partition nothing is saved. Persistence keeps settings, installed packages, DMDE/UFS license entries and files on the stick; do not store recovered customer data there. This entry exists in the image's GRUB menus; the persistence behaviour itself relies on casper and was not separately verified on real sticks.

## 3. Doing it by hand (what the script automates)

Use an empty disk `sdX`; everything on it is lost.

```bash
sudo parted -s /dev/sdX mklabel gpt mkpart bios 1MiB 3MiB set 1 bios_grub on \
     mkpart ESP fat32 3MiB 515MiB set 2 esp on mkpart root ext4 515MiB 100%
sudo mkfs.vfat -F32 /dev/sdX2 && sudo mkfs.ext4 -L hddlive /dev/sdX3
sudo mount /dev/sdX3 /mnt && sudo mkdir -p /mnt/boot/efi && sudo mount /dev/sdX2 /mnt/boot/efi
sudo unsquashfs -f -d /mnt /cdrom/casper/filesystem.squashfs
sudo bash -c 'echo "UUID=$(blkid -s UUID -o value /dev/sdX3) / ext4 defaults 0 1" > /mnt/etc/fstab'
sudo bash -c 'echo "UUID=$(blkid -s UUID -o value /dev/sdX2) /boot/efi vfat umask=0077 0 1" >> /mnt/etc/fstab'
echo hddlive | sudo tee /mnt/etc/hostname
for d in dev dev/pts proc sys run; do sudo mount --bind /$d /mnt/$d; done
sudo chroot /mnt /bin/bash
```

Inside the chroot:

```bash
useradd -m -s /bin/bash -G sudo,adm,plugdev,dialout,cdrom,disk tech && passwd tech
update-initramfs -u -k all
grub-install --target=i386-pc /dev/sdX
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu     # add --no-nvram if you booted in Legacy mode
grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --no-nvram
echo 'GRUB_DISABLE_OS_PROBER=true' >> /etc/default/grub
update-grub
exit
```

Then `sudo umount -R /mnt` and reboot.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `squashfs not found` | You booted with *load into RAM*: mount the USB stick and use `--squashfs` |
| It refuses my disk | It holds the live media, has mounted partitions, is a partition (not a whole disk) or is smaller than 12 GB |
| UEFI stops at `grub>` | The ESP has only the removable fallback: re-run the three `grub-install` lines above |
| Wi-Fi/network missing after install | Same drivers as the live image; check `nmcli` / NetworkManager |
| `oscdriver` will not load | Secure Boot is on, or the kernel changed: `sudo dkms status`, `sudo dkms install oscdriver/2.6.8 -k $(uname -r)` |
