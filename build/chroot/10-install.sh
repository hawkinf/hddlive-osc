#!/bin/bash
# (24.04) Runs INSIDE the chroot: updates the system, removes snaps and unneeded packages, installs the HDD kit + OpenSuperClone + third-party programs.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)
X=/root/extras
warn() { echo "!!! WARNING: $*"; }
# install only the packages that exist in the repository (names change between releases: t64, removals...)
install_existing() {
  local avail="" miss=""
  local c
  for p in "$@"; do
    c=$(apt-cache policy "$p" 2>/dev/null | sed -n 's/^ *Candidate: //p')   # no grep -q: pipefail + SIGPIPE
    if [ -n "$c" ] && [ "$c" != "(none)" ]; then avail="$avail $p"; else miss="$miss $p"; fi
  done
  [ -n "$miss" ] && echo "(no package in noble:$miss)"
  "${APT[@]}" install $avail
}

# dkms resets PATH and uses `uname -r`; during the install we replace /usr/bin/uname with a shim that returns the image's kernel.
shim_on() {
  [ -e /usr/bin/uname.real ] || mv /usr/bin/uname /usr/bin/uname.real
  printf '#!/bin/sh\nif [ "$1" = "-r" ]; then echo %s; else exec /usr/bin/uname.real "$@"; fi\n' "$1" > /usr/bin/uname
  chmod 755 /usr/bin/uname
}
shim_off() { if [ -e /usr/bin/uname.real ]; then mv -f /usr/bin/uname.real /usr/bin/uname; fi; }
trap shim_off EXIT

echo "##### 1. update everything (dist-upgrade) #####"
apt-get update
"${APT[@]}" dist-upgrade

echo "##### 2. snaps and anything unsuitable for a recovery live image #####"
# Ubuntu 24.04 Firefox/Thunderbird are SNAPS (they do not work well in a live image/chroot): remove snapd and install Mozilla's Firefox .deb.
REMOVE="firefox thunderbird thunderbird-gnome-support pidgin pidgin-data pidgin-otr pidgin-libnotify transmission-gtk transmission-common
 gnome-mines gnome-sudoku sgt-puzzles snapd snapd-desktop-integration gnome-software gnome-software-common gnome-software-plugin-snap
 apport apport-gtk apport-symptoms whoopsie popularity-contest ubuntu-advantage-tools ubuntu-pro-client ubuntu-pro-client-l10n
 update-notifier update-notifier-common update-manager update-manager-core unattended-upgrades xfce4-notes xfce4-notes-plugin
 ubuntu-release-upgrader-core ubuntu-release-upgrader-gtk"
PRESENT=""; for p in $REMOVE; do dpkg -s "$p" >/dev/null 2>&1 && PRESENT="$PRESENT $p"; done
echo "to remove:$PRESENT"
SIM=$(apt-get -s purge $PRESENT | grep -E '^(Remv|Purg)' || true)
if echo "$SIM" | grep -Eq '(Remv|Purg) (xubuntu-desktop|xubuntu-desktop-minimal|xubuntu-core|lightdm|xfce4-session|casper|network-manager|xfce4-panel|thunar|libreoffice-core)\b'; then
  echo "$SIM" | grep -E '(Remv|Purg) (xubuntu-desktop|xubuntu-desktop-minimal|xubuntu-core|lightdm|xfce4-session|casper|network-manager|xfce4-panel|thunar|libreoffice-core)\b'
  echo "ABORTING: the removal would drag in an essential package"; exit 1
fi
dpkg --configure -a || true
mkdir -p /var/lib/whoopsie; touch /var/lib/whoopsie/whoopsie-id
"${APT[@]}" purge $PRESENT
rm -rf /var/lib/snapd /snap /var/snap /root/snap /usr/lib/snapd
"${APT[@]}" autoremove --purge

echo "##### 2b. Firefox (official Mozilla .deb) #####"
"${APT[@]}" install curl ca-certificates gnupg
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg -o /etc/apt/keyrings/packages.mozilla.org.asc
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" > /etc/apt/sources.list.d/mozilla.list
printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1001\n' > /etc/apt/preferences.d/mozilla
for t in 1 2 3 4 5 6; do   # the Mozilla mirror is sometimes mid-sync ("unexpected size")
  apt-get update && break
  echo "apt-get update failed (attempt $t), waiting..."; sleep 30
done
install_existing firefox || warn "Firefox did not install"
firefox --version 2>&1 | head -1 || true
rm -f /etc/apt/sources.list.d/mozilla.list   # do not leave a third-party repository in the image (the pin then has no effect)

echo "##### 3. kernel: keep only the newest #####"
NEWK=$(ls /lib/modules | sort -V | tail -1)
echo "newest kernel: $NEWK"
for k in $(ls /lib/modules | grep -v "^$NEWK$" || true); do
  echo "removing old kernel $k"
  OLDPK=$(dpkg-query -W -f='${Package}\n' | grep -E "^linux-(image|modules|modules-extra|headers|hwe-[0-9.]+-headers)-${k%-generic}(-generic)?$" || true)
  [ -n "$OLDPK" ] && { "${APT[@]}" purge $OLDPK || warn "failed to remove $k"; }
done
rm -rf $(ls -d /lib/modules/* | grep -v "/$NEWK$" || true)

echo "##### 4. HDD kit and extra packages #####"
PKGS="smartmontools gsmartcontrol testdisk sleuthkit nvme-cli hddtemp hdparm sdparm sg3-utils lsscsi smp-utils
 gddrescue ddrutility foremost scalpel safecopy dc3dd dcfldd ewf-tools afflib-tools guymager partclone fsarchiver
 extundelete ext4magic ext3grep recoverjpeg magicrescue fatcat dislocker xmount qemu-utils mdadm f2fs-tools
 hfsprogs hfsplus hfsutils exfat-utils exfat-fuse exfatprogs jfsutils reiserfsprogs xfsprogs btrfs-progs ntfs-3g cryptsetup lvm2 dmraid kpartx
 efibootmgr os-prober gnome-disk-utility gparted f3 nwipe wipe secure-delete memtester stress-ng fio bonnie++ hardinfo cpu-x lshw lshw-gtk
 disktype pv ncdu htop iotop tmux mc nmap ethtool whois traceroute mtr-tiny hexedit dhex bvi ghex bless wxhexeditor
 openssh-server sshfs nfs-common cifs-utils x11vnc unrar unar p7zip-full rsync git curl wget vim gdb strace lsof inxi lm-sensors dmidecode
 usbutils pciutils xfburn simplescreenrecorder orage gromit-mpx screenruler baobab
 libgtk2.0-0t64 libusb-0.1-4 libgtk-3-0t64 unzip zip lzip build-essential gettext pkg-config
-base libconfig9 xdg-utils"
install_existing $PKGS

echo "##### 5. OpenSuperClone + DKMS driver for the image kernel ($NEWK) #####"
mkdir -p /usr/share/hddlive/osc-stable
cp "$X/opensuperclone_2.5.0-1_amd64.deb" /usr/share/hddlive/osc-stable/
"${APT[@]}" install dkms "linux-headers-$NEWK"
bash /root/hddlive/15-osc-build.sh
OSCV=$(ls -d /usr/src/oscdriver-* | head -1 | sed 's/.*oscdriver-//')
echo "OSC driver: $OSCV"
dkms status
modinfo -k "$NEWK" oscdriver | head -8 || warn "modinfo oscdriver failed"

echo "##### 6. ddrescue 1.30 (built from source) #####"
B=/usr/src/ddrescue-build; rm -rf $B; mkdir -p $B; cd $B
tar --lzip -xf "$X/ddrescue-1.30.tar.lz"; cd ddrescue-1.30
./configure --prefix=/usr/local >/dev/null && make -j"$(nproc)" >/dev/null && make install
ddrescue --version | head -1
cd /; rm -rf $B

echo "##### 7. (DMDE/Double Commander/R-Linux/TestDisk/smartmontools: see 25-extras.sh) #####"

echo "##### 8. ddrescueview 0.4.5 (from the old ISO) #####"
if [ -d "$X/ddrescueview-linux-x86_64" ]; then
  rm -rf /opt/ddrescueview; mkdir -p /opt/ddrescueview
  cp -a "$X/ddrescueview-linux-x86_64/." /opt/ddrescueview/
  chmod 755 /opt/ddrescueview/ddrescueview
  ln -sf /opt/ddrescueview/ddrescueview /usr/local/bin/ddrescueview
  ldd /opt/ddrescueview/ddrescueview | grep 'not found' && warn "ddrescueview has missing libs" || echo "ddrescueview: libs ok"
else warn "ddrescueview binary not provided (optional): skipped"; fi

echo "##### 9. HD Sentinel 0.20 (Linux, console) #####"
rm -rf /opt/hdsentinel; mkdir -p /opt/hdsentinel; unzip -q -o "$X/hdsentinel-020c-x64.zip" -d /opt/hdsentinel
chmod 755 /opt/hdsentinel/*; ls -la /opt/hdsentinel
HDS=$(ls /opt/hdsentinel | grep -i '^hdsentinel' | head -1); ln -sf "/opt/hdsentinel/$HDS" /usr/local/sbin/hdsentinel

echo "##### 10. R-Studio 5 (Linux) #####"
if [ -s "$X/RStudio5_x64.deb" ]; then
  "${APT[@]}" install "$X/RStudio5_x64.deb" || warn "R-Studio did not install"
  dpkg -L rstudio 2>/dev/null | grep -Ei 'bin/|\.desktop$' | head -10
else warn "RStudio5_x64.deb missing"; fi

echo "##### 11. mdadm/smartd/ssh/snap: never touch disks on their own #####"
ln -sf /dev/null /etc/udev/rules.d/64-md-raid-assembly.rules
systemctl mask mdadm.service mdmonitor.service mdadm-waitidle.service smartmontools.service smartd.service apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service fstrim.timer motd-news.timer esm-cache.service 2>&1 | tail -3 || true
systemctl disable ssh.service ssh.socket 2>&1 | tail -2 || true
[ -f /etc/mdadm/mdadm.conf ] && sed -i '/^ARRAY/d;/^MAILADDR/d;/^# definitions of existing MD arrays/d' /etc/mdadm/mdadm.conf && echo "mdadm.conf cleaned" || true
echo "##### END 10-install #####"
