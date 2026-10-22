#!/bin/bash
# Runs INSIDE the chroot: the items that were still missing from the earlier tool lists.
# Each item runs in isolation (try): if it fails, the apt version stays in effect and the rest continues. Results in /root/newer-results.txt.
# Everything goes to /usr/local (or /opt) and does NOT replace anything in the system; the root/sudo/user PATH already prefers /usr/local.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)
X=/root/extras
LOGD=/var/log/hddlive-newer; mkdir -p $LOGD; [ -n "${ONLY:-}" ] || rm -f /root/newer-results.txt
J=$(nproc)
SRC=/usr/src/newer-build; rm -rf $SRC; mkdir -p $SRC

try() { # try <name> <function>   (REAL status: the subshell runs as a simple command so set -e applies)
  local n="$1"; shift
  if [ -n "${ONLY:-}" ] && ! echo " $ONLY " | grep -q " $n "; then return 0; fi
  echo "##### $n #####"
  ( set -e; "$@" ) >"$LOGD/$n.log" 2>&1
  local rc=$?
  if [ $rc -eq 0 ]; then echo "OK   $n" >>/root/newer-results.txt; echo "  -> OK"
  else echo "FAIL $n (rc=$rc)" >>/root/newer-results.txt; echo "  -> FAILED (see $LOGD/$n.log):"; tail -12 "$LOGD/$n.log" | cut -c1-160; fi
}
unpack() { # unpack <file> <dir>  (strip 1 level)
  rm -rf "$2"; mkdir -p "$2"; tar xf "$1" -C "$2" --strip-components=1
}

echo "##### build dependencies #####"
dpkg-query -W -f='${Package}\n' | sort > /root/pkgs-before.txt
DEPS="autoconf automake libtool pkg-config cmake gettext intltool itstool yelp-tools autoconf-archive gnome-common flex bison
 libgtkmm-3.0-dev libparted-dev uuid-dev libblkid-dev libmount-dev libselinux1-dev libudev-dev libsqlite3-dev libssl-dev libexpat1-dev
 libxml2-dev zlib1g-dev libbz2-dev libfuse-dev libjson-c-dev libdbus-1-dev libkeyutils-dev libext2fs-dev comerr-dev libjpeg-dev libncurses-dev
 libntfs-3g-dev qtbase5-dev qttools5-dev-tools qt5-qmake libafflib-dev libewf-dev python3-venv python3-pip libsgutils2-dev libpcre2-dev libgcrypt20-dev libgnutls28-dev libreadline-dev libre2-dev libhwloc-dev
 libzstd-dev liblzo2-dev liblz4-dev liblzma-dev libattr1-dev libinih-dev liburcu-dev libedit-dev libicu-dev libdevmapper-dev libpopt-dev libargon2-dev libncursesw5-dev libbtrfs-dev xfslibs-dev libf2fs-dev libxxhash-dev"
apt-get update >/dev/null 2>&1      # BEFORE filtering (the apt lists were deleted during cleanup)
AVAIL=""; for p in $DEPS; do apt-cache show "$p" >/dev/null 2>&1 && AVAIL="$AVAIL $p" || echo "(no package: $p)"; done
"${APT[@]}" install --no-install-recommends $AVAIL || echo "!!! WARNING: partial failure installing dependencies"
[ -n "${ONLY:-}" ] || { rm -rf /usr/local/include/libewf* /usr/local/lib/libewf* /usr/local/lib/pkgconfig/libewf.pc; ldconfig; }   # TSK 4.15 only builds against apt's libewf (old API)

# ---------------------------------------------------------------- simple items (prebuilt binaries / plain make)
f_rclone() { rm -rf $SRC/rclone; mkdir -p $SRC/rclone; unzip -q "$X/rclone-current-linux-amd64.zip" -d $SRC/rclone
  install -m755 $SRC/rclone/*/rclone /usr/local/bin/rclone; /usr/local/bin/rclone version | head -1 || true; }
f_hdparm() { unpack "$X/hdparm_9.65+ds.orig.tar.xz" $SRC/hdparm; cd $SRC/hdparm; make -j$J; install -m755 hdparm /usr/local/sbin/hdparm; /usr/local/sbin/hdparm -V; }
f_sg3() { unpack "$X/sg3_utils-1.49.tar.xz" $SRC/sg3; cd $SRC/sg3; ./autogen.sh >/dev/null 2>&1; ./configure --prefix=/usr/local >/dev/null; make -j$J >/dev/null; make install >/dev/null; ldconfig; /usr/local/bin/sg_inq --version 2>&1 | head -1 || true; }
f_exfatprogs() { unpack "$X/exfatprogs-1.4.3.tar.xz" $SRC/exfat; cd $SRC/exfat; ./configure --prefix=/usr/local --sbindir=/usr/local/sbin >/dev/null; make -j$J >/dev/null; make install >/dev/null; /usr/local/sbin/mkfs.exfat -V 2>&1 | head -1 || true; }
f_nilfs() { unpack "$X/nilfs-utils-2.3.1.tar.gz" $SRC/nilfs; cd $SRC/nilfs; (./autogen.sh || autoreconf -fi) >/dev/null 2>&1; ./configure --prefix=/usr/local --sbindir=/usr/local/sbin --sysconfdir=/etc >/dev/null; make -j$J >/dev/null; make install >/dev/null; ldconfig; /usr/local/sbin/mkfs.nilfs2 -V 2>&1 | head -1 || true; }
f_mdadm() { unpack "$X/mdadm-4.6.tar.gz" $SRC/mdadm; cd $SRC/mdadm; make -j$J mdadm mdmon >/dev/null; install -m755 mdadm mdmon /usr/local/sbin/; /usr/local/sbin/mdadm --version 2>&1 | head -1 || true; }   # binaries only: apt's udev rules/services stay as they are (automount disabled)
f_testdisk73() { rm -rf /opt/testdisk-7.3-wip; mkdir -p /opt; tar xjf "$X/testdisk-7.3-WIP.linux26-x86_64.tar.bz2" -C /opt; mv /opt/testdisk-7.3* /opt/testdisk-7.3-wip 2>/dev/null || true
  ls /opt/testdisk-7.3-wip | head; for t in testdisk photorec; do ln -sf /opt/testdisk-7.3-wip/${t}_static /usr/local/bin/${t}-wip; done; /usr/local/bin/testdisk-wip --version 2>&1 | head -2 || true; }

# ---------------------------------------------------------------- forensic libraries/tools (order matters)
f_libewf() { unpack "$X/libewf-experimental-20260924.tar.gz" $SRC/libewf; cd $SRC/libewf; OPTS=$(./configure --help | grep -o -E -- "--with-lib[a-z0-9]+" | sort -u | grep -v -E "libfuse|libcrypto" | sed "s/$/=no/" | tr "\n" " "); echo "opts: $OPTS"; ./configure --prefix=/usr/local $OPTS >/dev/null; make -j$J >/dev/null; make install >/dev/null; ldconfig; /usr/local/bin/ewfinfo -V 2>&1 | head -1 || true; }
f_tsk() { unpack "$X/sleuthkit-4.15.0.tar.gz" $SRC/tsk; cd $SRC/tsk; ./configure --prefix=/usr/local --disable-java >/dev/null; make -j$J >/dev/null; make install >/dev/null; ldconfig; /usr/local/bin/mmls -V 2>&1 | head -1 || true; }
f_ntfs3g() { unpack "$X/ntfs-3g_ntfsprogs-2026.9.28.tgz" $SRC/ntfs; cd $SRC/ntfs
  # separate prefix and NO mount helper: only the tools (ntfsclone, ntfsundelete, ntfsfix...) go in PATH; apt's mount.ntfs-3g (with Ubuntu patches) remains the official one
  LDFLAGS="-Wl,-rpath,/opt/ntfs-3g/lib" ./configure --prefix=/opt/ntfs-3g --disable-mount-helper --disable-ldconfig --enable-ntfsprogs --disable-static >/dev/null
  make -j$J >/dev/null; make install >/dev/null
  for b in ntfsclone ntfsfix ntfsinfo ntfsls ntfscat ntfscluster ntfscmp ntfsundelete ntfsresize ntfscp ntfslabel mkntfs ntfswipe ntfsusermap ntfssecaudit ntfstruncate ntfsfallocate ntfsdecrypt ntfsrecover; do
    [ -x /opt/ntfs-3g/bin/$b ] && ln -sf /opt/ntfs-3g/bin/$b /usr/local/bin/$b; [ -x /opt/ntfs-3g/sbin/$b ] && ln -sf /opt/ntfs-3g/sbin/$b /usr/local/bin/$b; done
  /usr/local/bin/ntfsclone --version 2>&1 | head -1 || true; ls /usr/local/bin | grep -c ntfs; }
f_bulk() { unpack "$X/bulk_extractor-2.2.0.tar.gz" $SRC/bulk; cd $SRC/bulk; (./bootstrap.sh) >/dev/null 2>&1 || true; ./configure --prefix=/usr/local >/dev/null; for m in $(find . -name Makefile); do sed -i "s/ -Werror//g; s/ -std=c++11//g" $m; done; make -j$J >/dev/null; make install >/dev/null; /usr/local/bin/bulk_extractor -V 2>&1 | head -1 || true; }
f_qphotorec() { unpack "$X/testdisk-7.2.tar.bz2" $SRC/td; cd $SRC/td; ./configure --prefix=/usr/local --enable-qt >/dev/null || ./configure --prefix=/usr/local >/dev/null; make -j$J >/dev/null
  Q=$(find . -name qphotorec -type f -perm -u+x | head -1); [ -n "$Q" ] || { echo "qphotorec was not built"; exit 1; }; install -m755 "$Q" /usr/local/bin/qphotorec; ldd /usr/local/bin/qphotorec | grep 'not found' && exit 1; echo "qphotorec ok"; }

# ---------------------------------------------------------------- graphical interface / NVMe
f_gsmart() { unpack "$X/gsmartcontrol-2.0.2.tar.gz" $SRC/gsc; cd $SRC/gsc; cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local >/dev/null; cmake --build build -j$J >/dev/null; cmake --install build >/dev/null; GS=$(ls /usr/local/sbin/gsmartcontrol /usr/local/bin/gsmartcontrol 2>/dev/null | head -1) || true; [ -x "$GS" ] || exit 1; [ "$GS" = /usr/local/bin/gsmartcontrol ] || ln -sf "$GS" /usr/local/bin/gsmartcontrol; echo "gsmartcontrol at $GS"; }
f_gparted() { # Ubuntu 24.04 does not ship the polkit ITS rules (msgfmt of org.gnome.gparted.policy.in): create minimal ones
  mkdir -p /usr/share/gettext/its
  cat > /usr/share/gettext/its/polkit.its <<'ITS'
<?xml version="1.0"?>
<its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
  <its:translateRule selector="/policyconfig/action/description | /policyconfig/action/message | /policyconfig/vendor" translate="yes"/>
</its:rules>
ITS
  cat > /usr/share/gettext/its/polkit.loc <<'LOC'
<?xml version="1.0"?>
<locatingRules>
  <locatingRule name="Polkit" pattern="*.policy.in"><documentRule localName="policyconfig" target="polkit.its"/></locatingRule>
  <locatingRule name="Polkit" pattern="*.policy"><documentRule localName="policyconfig" target="polkit.its"/></locatingRule>
</locatingRules>
LOC
  unpack "$X/gparted-1.8.1.tar.gz" $SRC/gp; cd $SRC/gp; (./autogen.sh --prefix=/usr/local --disable-doc || (autoreconf -fi && ./configure --prefix=/usr/local --disable-doc)) ; [ -x ./configure ] || exit 1; ./configure --prefix=/usr/local --disable-doc >/dev/null; make -j$J >/dev/null; make install >/dev/null; test -x /usr/local/bin/gparted; ls -la /usr/local/bin/gparted /usr/local/libexec/gpartedbin; }
f_nvme() { python3 -m venv /opt/mesonvenv; export PATH=/opt/mesonvenv/bin:$PATH; /opt/mesonvenv/bin/pip install -q meson ninja; unpack "$X/nvme-cli-3.1.tar.gz" $SRC/nvme; cd $SRC/nvme
  /opt/mesonvenv/bin/meson setup build --prefix=/usr/local --sbindir=sbin -Ddocs=false -Dpython=disabled; /opt/mesonvenv/bin/ninja -C build >/dev/null; /opt/mesonvenv/bin/ninja -C build install >/dev/null
  rm -rf /opt/mesonvenv; ldconfig; (/usr/local/sbin/nvme version || /usr/local/bin/nvme version) 2>&1 | head -1 || true; }


# ---------------------------------------------------------------- file systems / imaging / crypto at the LATEST upstream versions (go to /usr/local or /opt; apt's stay as a fallback)
XN=/root/extras-new
f_btrfs() { unpack "$XN/btrfs-progs-v7.1.tar.xz" $SRC/btrfs; cd $SRC/btrfs; ./configure --prefix=/usr/local --disable-documentation --disable-python >/dev/null; make -j$J >/dev/null; make install >/dev/null; ldconfig; /usr/local/bin/btrfs --version | head -1; }
f_xfs() { unpack "$XN/xfsprogs-7.2.1.tar.xz" $SRC/xfs; cd $SRC/xfs; ./configure --prefix=/usr/local >/dev/null; make -j$J >/dev/null
  ST=$SRC/xfs-stage; rm -rf $ST; make install DESTDIR=$ST >/dev/null
  find $ST -type f -perm -u+x \( -path '*/sbin/*' -o -path '*/bin/*' \) | while read -r f; do install -m755 "$f" /usr/local/sbin/; done
  /usr/local/sbin/xfs_repair -V; /usr/local/sbin/mkfs.xfs -V; }
f_e2fs() { unpack "$XN/e2fsprogs-1.47.4.tar.xz" $SRC/e2; cd $SRC/e2; ./configure --prefix=/usr/local --with-root-prefix=/usr/local --disable-elf-shlibs --disable-fuse2fs --disable-uuidd --disable-fsck --disable-libblkid --disable-libuuid >/dev/null; make -j$J >/dev/null; make install >/dev/null
  /usr/local/sbin/e2fsck -V 2>&1 | head -1; /usr/local/sbin/mke2fs -V 2>&1 | head -1; /usr/local/sbin/debugfs -V 2>&1 | head -1; }
f_partclone() { unpack "$XN/partclone-0.3.50.tar.gz" $SRC/pc; cd $SRC/pc; autoreconf -fi >/dev/null 2>&1
  EN="--enable-extfs --enable-ntfs --enable-fat --enable-hfsp --enable-btrfs --enable-xfs --enable-f2fs --enable-ncursesw"
  CPPFLAGS=-I/opt/ntfs-3g/include LDFLAGS="-L/opt/ntfs-3g/lib -Wl,-rpath,/opt/ntfs-3g/lib" PKG_CONFIG_PATH=/opt/ntfs-3g/lib/pkgconfig ./configure --prefix=/usr/local $EN >/dev/null; make -j$J >/dev/null; make install-exec >/dev/null;   # install-exec: the GitHub tarball does not include the generated man pages
  /usr/local/sbin/partclone.extfs --version 2>&1 | head -2; ls /usr/local/sbin | grep -c partclone; }
f_fsarchiver() { unpack "$XN/fsarchiver-0.8.9.tar.gz" $SRC/fsa; cd $SRC/fsa; ./configure --prefix=/usr/local --sbindir=/usr/local/sbin >/dev/null; make -j$J >/dev/null; make install >/dev/null; /usr/local/sbin/fsarchiver --version 2>&1 | head -1; }
f_cryptsetup() { unpack "$XN/cryptsetup-2.8.0.tar.xz" $SRC/cs; cd $SRC/cs
  LDFLAGS="-Wl,-rpath,/opt/cryptsetup/lib" ./configure --prefix=/opt/cryptsetup --libdir=/opt/cryptsetup/lib --disable-udev --disable-ssh-token --disable-asciidoc --disable-static --disable-nls >/dev/null
  make -j$J >/dev/null; make install >/dev/null
  for b in cryptsetup veritysetup integritysetup; do ln -sf /opt/cryptsetup/sbin/$b /usr/local/sbin/$b; done
  /usr/local/sbin/cryptsetup --version; }

# ---------------------------------------------------------------- apt (light and optional)
f_apt_extra() { "${APT[@]}" install binwalk; binwalk --help 2>&1 | head -1 || true; }
f_guestfs() { SIM=$(apt-get -s install --no-install-recommends libguestfs-tools | grep -E '^Inst linux-(image|modules|generic)' || true); [ -z "$SIM" ] || { echo "libguestfs would pull in another kernel: $SIM"; exit 1; }
  "${APT[@]}" install --no-install-recommends libguestfs-tools; guestfish --version | head -1 || true; }
f_multipath() { "${APT[@]}" install multipath-tools; systemctl mask multipathd.service multipathd.socket 2>/dev/null; ln -sf /dev/null /etc/udev/rules.d/56-multipath.rules; ln -sf /dev/null /etc/udev/rules.d/11-dm-mpath.rules; multipath -h 2>&1 | head -1 || true; }

# ---------------------------------------------------------------- UFS Explorer (commercial; SDL installer driven unattended)
f_ufs() { echo "UFS Explorer: actually installed by 29-ufs.sh (step 11); the person running the build is responsible for reading and accepting the EULA."; }

try rclone f_rclone
try hdparm f_hdparm
try sg3_utils f_sg3
try exfatprogs f_exfatprogs
try nilfs_utils f_nilfs
try mdadm f_mdadm
try testdisk_7_3_wip f_testdisk73
try sleuthkit f_tsk
try libewf f_libewf
try ntfsprogs f_ntfs3g
try bulk_extractor f_bulk
try qphotorec f_qphotorec
try gsmartcontrol f_gsmart
try gparted f_gparted
try nvme_cli f_nvme
try btrfs_progs f_btrfs
try xfsprogs f_xfs
try partclone f_partclone
try fsarchiver f_fsarchiver
try cryptsetup f_cryptsetup
try e2fsprogs f_e2fs
try binwalk f_apt_extra
try libguestfs f_guestfs
try multipath f_multipath
try ufs_explorer f_ufs

echo "##### cleanup of build dependencies #####"
# 1) mark as MANUAL the runtime libraries used by the new binaries (so autoremove does not remove them)
for b in /usr/local/bin/* /usr/local/sbin/* /opt/ntfs-3g/bin/* /opt/ntfs-3g/sbin/* /opt/cryptsetup/sbin/* /usr/local/libexec/* /opt/ntfs-3g/lib/*.so* /opt/cryptsetup/lib/*.so*; do [ -f "$b" ] && ldd "$b" 2>/dev/null; done | awk '/=>/ {print $3}' | sort -u | while read -r lib; do
  pkg=$(dpkg -S "$(readlink -f "$lib")" 2>/dev/null | head -1 | cut -d: -f1);   # (noble: /lib -> /usr/lib; dpkg -S needs the real path)
   [ -n "$pkg" ] && apt-mark manual "$pkg" >/dev/null 2>&1; done
# 2) remove only build tools/-dev packages (that did not exist before)
dpkg-query -W -f='${Package}\n' | sort > /root/pkgs-after.txt
NEW=$(comm -13 /root/pkgs-before.txt /root/pkgs-after.txt)
PURGE=$(echo "$NEW" | grep -E -- '-dev$|^(autoconf|automake|libtool|cmake|cmake-data|intltool|itstool|yelp-tools|autoconf-archive|gnome-common|qttools5-dev-tools|qt5-qmake|python3-venv|python3-pip|flex|bison|m4|libtool-bin)$' || true)
echo "removing: $(echo $PURGE | wc -w) development packages"
"${APT[@]}" purge $PURGE >/dev/null 2>&1 || true
"${APT[@]}" autoremove --purge >/dev/null 2>&1 || true
ldconfig
rm -rf $SRC /usr/src/ufsx /root/pkgs-before.txt /root/pkgs-after.txt /tmp/sdlsoftmgr
echo "##### check: missing libraries in the new binaries #####"
MISS=0; for b in /usr/local/bin/* /usr/local/sbin/* /usr/local/libexec/* /opt/ntfs-3g/bin/* /opt/ntfs-3g/sbin/* /opt/cryptsetup/sbin/*; do
  [ -f "$b" ] && [ ! -L "$b" -o -e "$b" ] && file -L "$b" | grep -q ELF && { m=$(ldd "$b" 2>&1 | grep 'not found' || true); [ -n "$m" ] && { echo "MISSING in $b: $m"; MISS=1; }; }; done
[ $MISS -eq 0 ] && echo "all libraries resolved" | tee -a /root/newer-results.txt || echo "FAIL missing_libs" >> /root/newer-results.txt
echo; echo "===== RESULT ====="; cat /root/newer-results.txt
