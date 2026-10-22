#!/bin/bash
# Runs INSIDE the chroot: installs UFS Explorer Professional Recovery by driving the graphical installer wizard (SDL Software Manager)
# under Xvfb + xdotool. The wizard clicks "I have read and accept the EULA": the person running the build is responsible for having read
# and accepted the SysDev EULA (11-ufs.sh refuses to run unless ACCEPT_UFS_EULA=yes).
# Coordinates validated on a 1024x768 screen (Xvfb): language/Start (637,544); Next (755,568); checkbox (396,541); "Start now" (419,354); Close (755,568).
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive DISPLAY=:77
X=/root/extras
APT=(apt-get -y -o Dpkg::Options::=--force-confold)
dpkg-query -W -f='${Package}\n' | sort > /root/pkgs-before-ufs.txt
apt-get update >/dev/null 2>&1
"${APT[@]}" install --no-install-recommends xvfb xdotool xauth >/dev/null 2>&1 || { echo "FAILED: xvfb/xdotool"; exit 1; }

rm -rf /usr/src/ufsx; mkdir -p /usr/src/ufsx; cd /usr/src/ufsx
tar xJf "$X/ufsxpci.tar.xz"; chmod +x ufs-explorer-pro.install
POS=$(grep -a -m1 -o 'scenario_pos="[0-9]*"' ufs-explorer-pro.install | grep -o '[0-9]*')
dd if=ufs-explorer-pro.install of=sdlsoftmgr bs=32 count=192320 skip=46 2>/dev/null; chmod +x sdlsoftmgr
# idempotency: leftovers from a previous install make the wizard open on the maintenance screen (wrong clicks)
rm -rf /opt/ufs-explorer-pro /root/.sdl /etc/sdlcfg /usr/bin/sdlsoftmgr /usr/share/applications/sdl-ufs-*.desktop /usr/share/pixmaps/ufs-explorer-pro.png
Xvfb :77 -screen 0 1024x768x24 >/dev/null 2>&1 & XV=$!; sleep 3
./sdlsoftmgr install "$PWD/ufs-explorer-pro.install" "$POS" >/usr/src/ufsx/mgr.log 2>&1 & MP=$!
click() { xdotool mousemove "$1" "$2" click 1; }
sleep 8;  click 637 544            # language (English) -> Start
sleep 4;  click 755 568            # Introduction -> Next
sleep 3;  click 396 541; sleep 1; click 755 568     # Important notes: "I have read and understood" -> Next
sleep 3;  click 396 541; sleep 1; click 755 568     # EULA: "I have read and accept" (acceptance by the person running the build) -> Next
sleep 3;  click 755 568            # Location (/opt/ufs-explorer-pro) -> Next (installs)
sleep 15                           # copying ~50 MB
click 419 354; sleep 1             # untick "Start UFS Explorer now"
click 755 568; sleep 3             # Close
kill $MP 2>/dev/null; kill $XV 2>/dev/null; sleep 1

[ -x /opt/ufs-explorer-pro/ufs-explorer-pro ] || { echo "FAILED: UFS Explorer was not installed"; cat /usr/src/ufsx/mgr.log | head; exit 1; }
ls -la /opt/ufs-explorer-pro | head -12
ldd /opt/ufs-explorer-pro/ufs-explorer-pro | grep 'not found' && { echo "FAILED: missing libs"; exit 1; }

# Sentinel Runtime Environment (aksusbd + hasplmd): without the "Sentinel License Manager" UFS cannot activate a license/trial
# ("The operation cannot be performed because Sentinel License Manager is not running"). Manual install of trte64 (the official script
# tries to start the daemon inside the chroot): extract, copy the units and enable them; the services start at live boot.
RT=/opt/ufs-explorer-pro
gzip -dc "$RT/trte64.tar.gz" | tar -xf - -C / || { echo "FAILED: trte64"; exit 1; }
cp -p /var/hasplm/init/aksusbd_x86_64.service /etc/systemd/system/aksusbd.service
cp -p /var/hasplm/init/hasplmd_x86_64.service /etc/systemd/system/hasplmd.service
systemctl enable aksusbd hasplmd 2>&1 | tail -2
[ -x /usr/sbin/hasplmd_x86_64 ] && [ -x /usr/sbin/aksusbd_x86_64 ] || { echo "FAILED: Sentinel RTE not installed"; exit 1; }
echo "Sentinel RTE installed and enabled"

# cleanup: remove the installer and the virtual-screen tools (only what did not exist before)
rm -rf /usr/src/ufsx /opt/ufs-installer /tmp/sdlsoftmgr /tmp/sdlsoftmgr.gz
dpkg-query -W -f='${Package}\n' | sort > /root/pkgs-after-ufs.txt
NEW=$(comm -13 /root/pkgs-before-ufs.txt /root/pkgs-after-ufs.txt)
"${APT[@]}" purge xvfb xdotool xauth >/dev/null 2>&1 || true
"${APT[@]}" autoremove --purge >/dev/null 2>&1 || true
rm -f /root/pkgs-before-ufs.txt /root/pkgs-after-ufs.txt
echo "ufs OK: $(du -sh /opt/ufs-explorer-pro | cut -f1)"
