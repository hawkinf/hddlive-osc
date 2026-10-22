# Software and versions in the HDDLive image

Generated from the built image (Xubuntu 24.04.5, October 2026). Three sections:

1. **System base** — OS, kernel, driver and runtimes.
2. **Main programs** — what the image is for, with the version found in the image, where it comes from, and a one-line description.
3. **Every installed Debian package** — see [ALL-PACKAGES.md](ALL-PACKAGES.md) (full `dpkg` list with versions and descriptions).

> Where a newer upstream release was built or downloaded, the **apt version stays installed as a fallback** and is shown in the *Source* column. Items marked *optional* are only present if you supplied the required input at build time (see [BUILD.md](BUILD.md)). Proprietary programs are downloaded from their vendors and are not part of this repository.

## 1. System base

| Component | Version |
|---|---|
| Operating system | Ubuntu 24.04.5 LTS "Noble Numbat" (Xubuntu flavour) |
| Kernel | 7.0.0-38-generic (HWE) |
| OpenSuperClone virtual-disk driver (`oscdriver`, DKMS) | 2.6.8 (built for the image kernel) |
| GRUB / shim (boot) | grub-efi-amd64-signed 1.202.5+2.12-1ubuntu7.3 / shim-signed 1.58+15.8-0ubuntu1 |
| Live boot (casper) | 1.498 |
| Python | 3.12.3 |
| GCC / build tools in the image | 13.3.0 (kept so DKMS can rebuild the driver) |
| Desktop | Xfce 4.18, Greybird theme, elementary-xfce-darker icons, Noto Sans 9 |
| Packages installed (dpkg) | 2166 |

## 2. Main programs

### Cloning and imaging of failing drives

| Program | Version | Source | What it does |
|---|---|---|---|
| OpenSuperClone | 2.6.0-alpha1 (stable 2.5.0 kept as fallback) | built from source (.deb + DKMS driver `oscdriver` 2.6.8) | open-source cloner/imager for drives with bad sectors: phased copy with a map, direct AHCI/IDE/USB access, virtual-disk mode |
| OSCViewer / OpenSuperTool | 2.6.0-alpha1 | part of OpenSuperClone | viewer for the OpenSuperClone log/domain; CLI tool mode |
| GNU ddrescue / ddrescuelog | 1.30 | built from source (apt fallback: 1.27-1) | copies around read errors, keeps a resumable mapfile |
| ddrescueview | 0.4.5 | vendor binary (optional) | colored block map of a ddrescue mapfile |
| ddrutility | 2.8-4 | Ubuntu apt | finds which files are hit by the bad sectors of a mapfile |
| safecopy | 1.7-7 | Ubuntu apt | alternative imager with block skip/retry strategies |
| dc3dd | 7.3.1-2 | Ubuntu apt | forensic dd with hashing and logging |
| dcfldd | 1.9.1-1ubuntu2 | Ubuntu apt | dd with on-the-fly hashing |
| recoverdm | 0.20-8 | Ubuntu apt | recovery from bad optical/floppy media |
| Guymager | 0.8.13-2build2 | Ubuntu apt | forensic imager GUI (dd/E01/AFF) |
| Clonezilla | 5.5.25-1 | Ubuntu apt | image/clone healthy disks |
| Partclone | 0.3.50 | built from source (apt fallback: 0.3.27+repack-2build2) | file-system-aware imaging of used blocks only |
| Partimage | 0.6.9-11build2 | Ubuntu apt | legacy partition imaging |
| FSArchiver | 0.8.9 | built from source (apt fallback: 0.8.7-1build2) | file-system archives with compression/encryption |
| libewf tools (ewfacquire, ewfinfo, ewfverify, ewfmount...) | 20260924 | built from source (apt fallback: 20140814-1build3) | create/verify/mount EnCase E01 images |
| afflib-tools | 3.7.20-1.1ubuntu5 | Ubuntu apt | AFF forensic image tools |
| xmount | 0.7.6-3build2 | Ubuntu apt | present images as another format with a write cache |
| qemu-utils (qemu-img, qemu-nbd) | 1:8.2.2+ds-0ubuntu1.18 | Ubuntu apt | convert and mount VMDK/VHD/QCOW2 |
| rclone | 1.75.2 | upstream binary (apt fallback: 1.60.1+dfsg-3ubuntu0.24.04.6) | upload to Drive, OneDrive, S3, SFTP, SMB... |
| HDDSuperClone (legacy) | 2.3.3_20220430 | proprietary, optional (from the original HDDLive ISO) | original cloner, kept as a fallback |
| HDDSCViewer (legacy) + 47 hddscripts | 1.0_20220212 | proprietary, optional | log viewer and shell scripts of the original HDDSuperClone |

### File and partition recovery

| Program | Version | Source | What it does |
|---|---|---|---|
| DMDE | 4.4.4.842 (stable) and 4.5.0.849 Beta (GTK3) | vendor binary — installed without a license (Free Edition) | disk editor and logical recovery |
| R-Studio | 5.5.191803 | vendor .deb (proprietary, demo until licensed) | professional multi-filesystem recovery |
| R-Linux | 6.5.191754 | vendor .deb (check the vendor license terms) | recovery for ext2/3/4 (and newer Btrfs/XFS support) |
| UFS Explorer Professional Recovery | latest from the vendor at build time | vendor installer (optional, needs ACCEPT_UFS_EULA=yes) | cross-platform recovery with strong RAID/NAS support |
| TestDisk / PhotoRec | 7.2 (static) and 7.3-WIP | upstream binaries (apt fallback: 7.1-5+nmu1build2) | partition recovery and signature carving |
| QPhotoRec | 7.2 (Qt5) | built from source | PhotoRec with a graphical interface |
| Foremost | 1.5.7-11 | Ubuntu apt | header/footer file carving |
| Scalpel | 1.60+git20240110.6960eb2-1build1 | Ubuntu apt | configurable file carving |
| recoverjpeg (+ recovermov) | 2.6.3-5 | Ubuntu apt | photo/video carving |
| magicrescue | 1.1.10+dfsg-2build2 | Ubuntu apt | recipe-based carving |
| extundelete | 0.2.4-3build2 | Ubuntu apt | undelete on ext3/ext4 using the journal |
| ext4magic | 0.3.2-14build2 | Ubuntu apt | undelete on ext3/ext4 |
| ext3grep | 0.10.2-5 | Ubuntu apt | ext3 undelete helper |
| scrounge-ntfs | 0.9-10 | Ubuntu apt | recover files from NTFS via the MFT |
| fatcat | 1.1.1-3 | Ubuntu apt | inspect/recover FAT file systems |
| bulk_extractor | 2.2.0 | built from source | extracts e-mails, URLs, cards, phone numbers from raw images |
| binwalk | 2.3.4+dfsg1-5 | Ubuntu apt | find embedded files/firmware |
| YARA | 4.5.0-1build2 | Ubuntu apt | pattern-matching rules |
| ExifTool | 12.76+dfsg-1 | Ubuntu apt | read/write file metadata |
| chntpw | 140201-1 | Ubuntu apt | reset local Windows account passwords (authorized use only) |
| Double Commander | 1.2.9 (GTK2) | upstream binary | two-pane file manager |

### Partitions, file systems, RAID and encryption

| Program | Version | Source | What it does |
|---|---|---|---|
| GParted | 1.8.1 | built from source (apt fallback: 1.5.0-1build4) | partition editor (writes to the disk) |
| GNOME Disks | 46.0-1ubuntu3 | Ubuntu apt | SMART, benchmark, partitions, images |
| gdisk / sgdisk | 1.0.10-1build1 | Ubuntu apt | GPT/MBR editor and recovery |
| gpart | 1:0.3-10 | Ubuntu apt | guesses lost partitions |
| kpartx | 0.9.4-5ubuntu8.2 | Ubuntu apt | map partitions of an image |
| efibootmgr | 18-1build2 | Ubuntu apt | UEFI boot entries |
| os-prober | 1.81ubuntu4 | Ubuntu apt | detect installed operating systems |
| ntfs-3g / ntfsprogs tools | 2026.9.28 | built from source (mount still uses the apt ntfs-3g) (apt fallback: 1:2022.10.3-1.2ubuntu3.2) | ntfsclone, ntfsfix, ntfsresize, ntfsundelete... |
| e2fsprogs | 1.47.4 | built from source (apt fallback: 1.47.0-2.4~exp1ubuntu4.1) | ext2/3/4 tools |
| btrfs-progs | 7.1 | built from source (apt fallback: 6.6.3-1.1build2) | Btrfs tools (check, restore, rescue) |
| xfsprogs | 7.2.1 | built from source (apt fallback: 6.6.0-1ubuntu2.1) | XFS tools |
| xfsdump | 3.1.11-0.1build1 | Ubuntu apt | XFS dump/restore |
| dosfstools | 4.2-1.1build1 | Ubuntu apt | FAT tools |
| exfatprogs | 1.4.3 | built from source (apt fallback: 1.2.2-1build1) | exFAT tools |
| nilfs-utils | 2.3.1 | built from source | NILFS2 tools |
| f2fs-tools | 1.16.0-1 | Ubuntu apt | F2FS tools |
| jfsutils | 1.1.15-5build4 | Ubuntu apt | JFS tools |
| reiserfsprogs | 1:3.6.27-7.1build1 | Ubuntu apt | ReiserFS tools |
| hfsprogs / hfsplus / hfsutils | hfsprogs 540.1.linux3-5build3; hfsplus 1.0.4-17.1build1; hfsutils 3.2.6-16 | Ubuntu apt | HFS/HFS+ tools |
| udftools | 2.3-1build2 | Ubuntu apt | UDF tools |
| bcache-tools | 1.0.8-5build1 | Ubuntu apt | bcache tools |
| OpenZFS (zfsutils-linux) | 2.2.2-0ubuntu9.5 | Ubuntu apt | ZFS tools (automatic import disabled) |
| mdadm | 4.6 | built from source (binaries only) (apt fallback: 4.3-1ubuntu2.1) | software RAID |
| LVM2 | 2.03.16-3ubuntu3.2 | Ubuntu apt | logical volumes |
| dmraid | 1.0.0.rc16-12ubuntu2 | Ubuntu apt | fake/BIOS RAID |
| multipath-tools | 0.9.4-5ubuntu8.2 | Ubuntu apt | multipath (installed but disabled) |
| cryptsetup | 2.8.0 | built from source (in /opt/cryptsetup) (apt fallback: 2:2.7.0-1ubuntu4.2) | LUKS / dm-crypt / VeraCrypt |
| dislocker | 0.7.3-3.1build2 | Ubuntu apt | open BitLocker volumes |
| libbde-utils | 20190102-2.1build2 | Ubuntu apt | BitLocker inspection |
| libvshadow-utils | 20190323-2.1build1 | Ubuntu apt | Windows shadow copies |
| libvhdi / libvmdk / libqcow utils | libvhdi-utils 20210425-1build5; libvmdk-utils 20200926-2build5; libqcow-utils 20201213-1.1build2 | Ubuntu apt | virtual disk formats |
| libfsapfs-utils | 20201107-1.1build2 | Ubuntu apt | APFS |
| libfsntfs-utils | 20200921-2.1build1 | Ubuntu apt | NTFS inspection |
| libvslvm-utils | 20181227-1.2build1 | Ubuntu apt | LVM2 volumes |
| ecryptfs-utils | 111-6ubuntu3 | Ubuntu apt | eCryptfs encrypted folders |
| libguestfs-tools | 1:1.52.0-5ubuntu3 | Ubuntu apt | inspect VM images without booting |
| nbd-client | 1:3.26.1-1ubuntu0.1 | Ubuntu apt | network block devices |
| sshfs | 3.7.3-1.1build3 | Ubuntu apt | mount over SSH |
| nfs-common | 1:2.6.4-3ubuntu5.1 | Ubuntu apt | NFS client |
| cifs-utils | 2:7.0-2ubuntu0.6 | Ubuntu apt | SMB/CIFS client |

### Hardware diagnostics

| Program | Version | Source | What it does |
|---|---|---|---|
| smartmontools (smartctl, smartd) | 7.5 | built from source (apt fallback: 7.4-2build1) | S.M.A.R.T. reading and self-tests |
| GSmartControl | 2.0.2 | built from source (apt fallback: 1.1.4-1build2) | graphical front-end for smartctl |
| Hard Disk Sentinel (Linux console) | 0.20c | vendor binary (proprietary) | health/performance/temperature rating |
| hdparm | 9.65 | built from source (apt fallback: 9.65+ds-1build1) | ATA identify, benchmark, HPA, security |
| sdparm | 1.12-1 | Ubuntu apt | SCSI/SAS parameter tool |
| sg3_utils | 1.49 | built from source (apt fallback: 1.46-3ubuntu4.1) | raw SCSI/SAS/SAT commands |
| nvme-cli | 3.1 | built from source (apt fallback: 2.8-1ubuntu0.1) | NVMe identify, SMART log, format |
| lsscsi | 0.32-1build1 | Ubuntu apt | list SCSI/SATA devices |
| smp-utils | 0.99-1 | Ubuntu apt | SAS expander management |
| lshw / lshw-gtk | lshw 02.19.git.2021.06.19.996aaad9c7-2ubuntu0.24.04.1; lshw-gtk 02.19.git.2021.06.19.996aaad9c7-2ubuntu0.24.04.1 | Ubuntu apt | hardware inventory |
| inxi | 3.3.34-1-1 | Ubuntu apt | system information |
| HardInfo | 0.5.1+git20180227-2.1build3 | Ubuntu apt | hardware info and benchmark |
| CPU-X | 5.0.3-2build2 | Ubuntu apt | CPU/board/RAM information |
| dmidecode | 3.5-3ubuntu0.2 | Ubuntu apt | DMI/SMBIOS tables |
| lm-sensors | 1:3.6.0-9build1 | Ubuntu apt | temperature/fan sensors |
| usbutils | 1:017-3build1 | Ubuntu apt | lsusb |
| pciutils | 1:3.10.0-2build1 | Ubuntu apt | lspci |
| fio | 3.36-1ubuntu0.1 | Ubuntu apt | disk benchmark |
| bonnie++ | 2.00a+nmu2build1 | Ubuntu apt | file system benchmark |
| stress-ng | 0.17.06-1build1 | Ubuntu apt | CPU/RAM/IO stress tests |
| memtester | 4.6.0-1 | Ubuntu apt | RAM test from user mode |
| memtest86+ | 7.00-1build1 | Ubuntu apt | RAM test at boot (BIOS) |
| f3 | 8.0-2build2 | Ubuntu apt | detect counterfeit flash drives |
| nwipe | 0.34-1build2 | Ubuntu apt | secure disk wipe (destructive) |
| wipe | 0.24-9 | Ubuntu apt | secure file wipe |
| secure-delete | 3.1-8 | Ubuntu apt | secure deletion tools |
| disktype | 9-12 | Ubuntu apt | identify media/file system types |
| pv | 1.8.5-2build1 | Ubuntu apt | pipe progress |
| ncdu | 1.19-0.1 | Ubuntu apt | disk usage (terminal) |
| iotop | 0.6-42-ga14256a-0.2build1 | Ubuntu apt | I/O monitor |
| htop | 3.3.0-4build1 | Ubuntu apt | process monitor |
| Baobab | 46.0-1build1 | Ubuntu apt | disk usage (GUI) |

### Forensics and analysis

| Program | Version | Source | What it does |
|---|---|---|---|
| The Sleuth Kit | 4.15.0 | built from source (apt fallback: 4.12.1+dfsg-1.1ubuntu2) | mmls, fls, icat, tsk_recover, mactime... |
| Autopsy | 4.23.1 | optional build step (not in the default image) | graphical forensic platform |
| wxHexEditor | 0.24+repack-2build3 | Ubuntu apt | hex editor for disks and huge images |
| GHex | 46.0-1build1 | Ubuntu apt | simple hex editor |
| hexedit | 1.6-1 | Ubuntu apt | terminal hex editor |
| dhex | 0.69-4 | Ubuntu apt | terminal hex diff editor |
| bvi | 1.4.2-2 | Ubuntu apt | vi-like binary editor |

### Desktop, network and utilities

| Program | Version | Source | What it does |
|---|---|---|---|
| Firefox (Mozilla deb) | 158.0.1~build1 | Ubuntu apt | web browser |
| Xfce session | 4.18.3-1build2 | Ubuntu apt | desktop environment (Xfce 4.18) |
| Xfce panel | 4.18.4-1ubuntu0.1 | Ubuntu apt | panel |
| xfdesktop | 4.18.1-1build3 | Ubuntu apt | desktop and wallpaper manager |
| Thunar | 4.18.8-1build3 | Ubuntu apt | file manager |
| LightDM | 1.30.0-0ubuntu14 | Ubuntu apt | display manager (autologin) |
| Mousepad | 0.6.1-1build2 | Ubuntu apt | text editor |
| Ristretto | 0.13.1-1build2 | Ubuntu apt | image viewer |
| Parole | 4.18.1-1build2 | Ubuntu apt | media player |
| Xfburn | 0.7.0-1build2 | Ubuntu apt | CD/DVD burning |
| SimpleScreenRecorder | 0.4.4-3build4 | Ubuntu apt | screen recording |
| Orage | 4.18.0-1build3 | Ubuntu apt | calendar |
| Gromit-MPX | 1.5.1-1build2 | Ubuntu apt | draw on the screen |
| Screen Ruler | 1.2.1-1 | Ubuntu apt | measure in pixels |
| OpenSSH server | 1:9.6p1-3ubuntu13.20 | Ubuntu apt | remote shell (disabled by default) |
| rsync | 3.2.7-1ubuntu1.5 | Ubuntu apt | file synchronization |
| lftp | 4.9.2-2ubuntu1.1 | Ubuntu apt | FTP/SFTP client |
| curl | 8.5.0-2ubuntu10.16 | Ubuntu apt | HTTP client |
| wget | 1.21.4-1ubuntu4.5 | Ubuntu apt | downloader |
| nmap | 7.94+git20230807.3be01efb1+dfsg-3build2 | Ubuntu apt | network scanner |
| tcpdump | 4.99.4-3ubuntu4.24.04.1 | Ubuntu apt | packet capture |
| iperf3 | 3.16-1build2 | Ubuntu apt | network throughput test |
| ethtool | 1:6.7-1build1 | Ubuntu apt | NIC settings |
| mtr-tiny | 0.95-1.1ubuntu0.1 | Ubuntu apt | traceroute+ping |
| whois | 5.5.22 | Ubuntu apt | whois client |
| x11vnc | 0.9.16-10 | Ubuntu apt | VNC server for the live screen |
| tmux | 3.4-1ubuntu0.2 | Ubuntu apt | terminal multiplexer |
| Midnight Commander | 3:4.8.30-1ubuntu0.1 | Ubuntu apt | terminal file manager |
| ranger | 1.9.3-5ubuntu0.24.04.1 | Ubuntu apt | terminal file manager |
| vim | 2:9.1.0016-1ubuntu7.20 | Ubuntu apt | text editor |
| git | 1:2.43.0-1ubuntu7.4 | Ubuntu apt | version control |
| gdb | 15.1-1ubuntu1~24.04.1 | Ubuntu apt | debugger |
| strace | 6.8-0ubuntu2 | Ubuntu apt | system call tracer |
| lsof | 4.95.0-1build3 | Ubuntu apt | open files |
| smem | 1.5-2 | Ubuntu apt | memory reporting |
| sysstat | 12.6.1-2 | Ubuntu apt | sar/iostat/mpstat |
| p7zip-full | 16.02+transitional.1 | Ubuntu apt | 7z archives |
| 7zip | 23.01+dfsg-11 | Ubuntu apt | 7-Zip |
| unrar | 1:7.0.7-1build1 | Ubuntu apt | RAR extraction |
| unar | 1.10.7+ds1+really1.10.1-3build1 | Ubuntu apt | universal archive extractor |
| cabextract | 1.11-2 | Ubuntu apt | CAB extraction |
| pigz | 2.8-1 | Ubuntu apt | parallel gzip |
| fdupes | 1:2.3.0-1build1 | Ubuntu apt | find duplicate files |
| rdfind | 1.6.0-1build3 | Ubuntu apt | find duplicate files |
| squashfs-tools | 1:4.6.1-1build1 | Ubuntu apt | squashfs tools |
| mtools | 4.0.43-1build1 | Ubuntu apt | MS-DOS/FAT tools |

*167 entries.* The 65 OpenSuperClone scripts live in `/usr/bin/oscscripts/` and the 47 legacy scripts (if provided) in `/usr/local/bin/hddscripts/`.
