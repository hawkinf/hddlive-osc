#!/bin/bash
# Runs INSIDE the chroot: builds OpenSuperClone 2.6.0-alpha1 from source on Ubuntu 20.04 (the official .deb was built on 22.04 and requires GLIBC 2.34),
# produces a .deb for focal (+ libconfig9 dependency) and installs it together with the DKMS driver for the image kernel.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)
X=/root/extras
NEWK=$(ls /lib/modules | sort -V | tail -1)
echo "image kernel: $NEWK"

shim_on() {
  [ -e /usr/bin/uname.real ] || mv /usr/bin/uname /usr/bin/uname.real
  printf '#!/bin/sh\nif [ "$1" = "-r" ]; then echo %s; else exec /usr/bin/uname.real "$@"; fi\n' "$1" > /usr/bin/uname
  chmod 755 /usr/bin/uname
}
shim_off() { if [ -e /usr/bin/uname.real ]; then mv -f /usr/bin/uname.real /usr/bin/uname; fi; }
trap shim_off EXIT

apt-get update
# (24.04) names change (t64): pick the one that exists
pick() { for c in "$@"; do if apt-cache show "$c" >/dev/null 2>&1; then echo "$c"; return; fi; done; }
G=$(pick libgtk-3-0t64 libgtk-3-0); U=$(pick libusb-0.1-4t64 libusb-0.1-4); C=$(pick libconfig9t64 libconfig9)
echo "runtime: $G $U $C"
BUILD_DEPS="cmake libgtk-3-dev libconfig-dev $(pick libusb-dev libusb-0.1-4-dev) pkg-config gettext"
"${APT[@]}" install $BUILD_DEPS $C $U $G dkms "linux-headers-$NEWK" build-essential

B=/usr/src/osc-build; rm -rf $B /tmp/oscpkg; mkdir -p $B
tar xzf "$X/osc-2.6.0-alpha1.tar.gz" -C $B --strip-components=1
cd $B
# the tarball is not a git repository: `git rev-parse` fails and GIT_REVISION stays empty (=> "undeclared" at compile time). Pin the revision = tag.
sed -i 's|^# Set compiler flags|if(NOT GIT_REVISION)\n    set(GIT_REVISION "v2.6.0-alpha1")\nendif()\n\n# Set compiler flags|' CMakeLists.txt
# package.sh builds the .deb and then the .rpm (without rpmbuild it fails AFTER producing the .deb): tolerate it, the .deb is what matters
THREADS=$(nproc) sh ./package.sh >/tmp/osc-package.log 2>&1 || true
tail -8 /tmp/osc-package.log
DEB=$(find $B -name '*.deb' | head -1)
[ -n "$DEB" ] || { echo "no .deb was produced"; exit 1; }
echo "deb built: $DEB"; dpkg-deb -I "$DEB" | sed -n '1,20p'

# the generated .deb does not declare libconfig9 -> add it
dpkg-deb -R "$DEB" /tmp/oscpkg
# Depends using the names that exist in this release (t64)
sed -i '/^Depends:/d;/^[[:space:]]*$/d' /tmp/oscpkg/DEBIAN/control   # no blank lines (otherwise it becomes a 2nd paragraph)
echo "Depends: $G, $U, $C" >> /tmp/oscpkg/DEBIAN/control
sed -i 's/^Version: .*/Version: 2.6.0~alpha1-1focal/' /tmp/oscpkg/DEBIAN/control
cat /tmp/oscpkg/DEBIAN/control
chmod 755 /tmp/oscpkg/DEBIAN/postinst /tmp/oscpkg/DEBIAN/prerm
mkdir -p /usr/share/hddlive
dpkg-deb -b /tmp/oscpkg /usr/share/hddlive/opensuperclone_2.6.0~alpha1-1focal_amd64.deb

# install (the postinst runs `dkms install oscdriver/<ver>` for `uname -r`: the shim points to the image kernel)
shim_on "$NEWK"
if dpkg -s opensuperclone >/dev/null 2>&1; then dpkg --purge opensuperclone || true; fi
"${APT[@]}" install /usr/share/hddlive/opensuperclone_2.6.0~alpha1-1focal_amd64.deb
shim_off

OSCV=$(ls -d /usr/src/oscdriver-* | head -1 | sed 's/.*oscdriver-//')
dkms status | grep -q "oscdriver, $OSCV, $NEWK.*installed" || { dkms add -m oscdriver -v "$OSCV" || true; dkms install -m oscdriver -v "$OSCV" -k "$NEWK"; }
dkms status
modinfo -k "$NEWK" oscdriver | head -4

echo "== library check"
for b in /usr/bin/opensuperclone /usr/bin/oscviewer; do
  ldd "$b" | grep 'not found' && { echo "MISSING LIBS in $b"; exit 1; } || echo "$b: libs ok"
  echo -n "  max GLIBC: "; objdump -T "$b" | grep -o "GLIBC_[0-9.]*" | sort -V | uniq | tail -1
done
ls /usr/bin/oscscripts | head -5; ls /usr/share/opensuperclone/

# remove only what was needed to build (cmake and -dev); keep gcc/make/headers/dkms so the driver can be rebuilt for another kernel
rm -rf $B /tmp/oscpkg
"${APT[@]}" purge cmake libgtk-3-dev libconfig-dev $(pick libusb-dev libusb-0.1-4-dev)
"${APT[@]}" autoremove --purge
"${APT[@]}" install $C $U     # ensure the runtime packages (autoremove must not remove them)
/usr/bin/opensuperclone --help 2>&1 | head -5 || true
echo "OSC build OK"
