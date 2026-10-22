#!/bin/bash
# Runs INSIDE the chroot: Autopsy 4.23.1 (uses Sleuth Kit 4.15.0 + Java bindings + OpenJDK 17; JavaFX comes in Autopsy's own jars).
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)
X=/root/extras
JH=/usr/lib/jvm/java-17-openjdk-amd64
LOGD=/var/log/hddlive-newer; mkdir -p $LOGD
SRC=/usr/src/autopsy-build; rm -rf $SRC; mkdir -p $SRC

echo "##### Java 17 + ant (to build the TSK Java bindings) #####"
apt-get update >/dev/null 2>&1
dpkg-query -W -f='${Package}\n' | sort > /root/pkgs-before-aut.txt
"${APT[@]}" install openjdk-17-jdk ant || { echo "FAILED: java/ant"; exit 1; }
[ -x $JH/bin/javac ] || { echo "FAILED: javac missing in $JH"; exit 1; }
apt-mark manual openjdk-17-jre openjdk-17-jre-headless >/dev/null 2>&1

echo "##### Sleuth Kit 4.15.0 with Java bindings #####"
# TSK 4.15 only builds against APT's libewf (old API). Set the NEW libewf (/usr/local) aside while building.
"${APT[@]}" install libewf-dev >/dev/null 2>&1
ASIDE=/root/ewf-aside; rm -rf $ASIDE; mkdir -p $ASIDE
for f in /usr/local/include/libewf* /usr/local/lib/libewf* /usr/local/lib/pkgconfig/libewf.pc; do [ -e "$f" ] && mv "$f" $ASIDE/; done; ldconfig
rm -rf $SRC/tsk; mkdir -p $SRC/tsk; tar xf "$X/sleuthkit-4.15.0.tar.gz" -C $SRC/tsk --strip-components=1; cd $SRC/tsk
export JAVA_HOME=$JH
( ./configure --prefix=/usr/local --enable-java && make -j"$(nproc)" && make install ) >"$LOGD/tsk-java.log" 2>&1
rc=$?; echo "tsk-java rc=$rc"; tail -n 6 "$LOGD/tsk-java.log" | cut -c1-170
# restore the new libewf (the ewf* tools in /usr/local depend on it)
mkdir -p /usr/local/include /usr/local/lib/pkgconfig
for f in $ASIDE/libewf*.pc; do [ -e "$f" ] && mv "$f" /usr/local/lib/pkgconfig/; done
for f in $ASIDE/libewf*; do [ -e "$f" ] || continue; case "$f" in *.h|*/libewf) mv "$f" /usr/local/include/;; *) mv "$f" /usr/local/lib/;; esac; done
[ -d $ASIDE/libewf ] && mv $ASIDE/libewf /usr/local/include/ 2>/dev/null
ldconfig; /usr/local/bin/ewfinfo -V 2>&1 | head -1
[ $rc -eq 0 ] || { echo "FAILED: TSK with Java bindings"; exit 1; }
ldconfig
JAR=$(find /usr/local /usr -name 'sleuthkit-4.15.0.jar' 2>/dev/null | head -1); JNI=$(find /usr/local /usr -name 'libtsk_jni.so' 2>/dev/null | head -1)
echo "jar: $JAR"; echo "jni: $JNI"
[ -n "$JAR" ] && [ -n "$JNI" ] || { echo "FAILED: TSK jar/jni not found"; exit 1; }
mkdir -p /usr/local/share/java; [ "$JAR" = /usr/local/share/java/sleuthkit-4.15.0.jar ] || cp -f "$JAR" /usr/local/share/java/sleuthkit-4.15.0.jar
ln -sf "$JNI" /usr/lib/libtsk_jni.so      # the default java.library.path does NOT include /usr/local/lib

echo "##### Autopsy 4.23.1 #####"
rm -rf /opt/autopsy /opt/autopsy-4.23.1; unzip -q "$X/autopsy-4.23.1.zip" -d /opt; mv /opt/autopsy-4.23.1 /opt/autopsy
cd /opt/autopsy; chmod +x unix_setup.sh bin/autopsy 2>/dev/null
./unix_setup.sh -j $JH -n autopsy 2>&1 | tail -n 8
[ -x /opt/autopsy/bin/autopsy ] || { echo "FAILED: bin/autopsy missing"; exit 1; }
chmod -R a+rX /opt/autopsy
ln -sf /opt/autopsy/bin/autopsy /usr/local/bin/autopsy
du -sh /opt/autopsy | cut -f1

echo "##### cleanup: remove JDK/ant (keep only the JRE) #####"
dpkg-query -W -f='${Package}\n' | sort > /root/pkgs-after-aut.txt
NEW=$(comm -13 /root/pkgs-before-aut.txt /root/pkgs-after-aut.txt)
"${APT[@]}" purge ant openjdk-17-jdk openjdk-17-jdk-headless libewf-dev >/dev/null 2>&1 || true
"${APT[@]}" autoremove --purge >/dev/null 2>&1 || true
[ -x $JH/bin/java ] || { echo "FAILED: the JRE was removed by accident"; exit 1; }
$JH/bin/java -version 2>&1 | head -1
ldconfig; rm -rf $SRC /root/pkgs-before-aut.txt /root/pkgs-after-aut.txt
echo "autopsy OK"
