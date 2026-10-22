#!/bin/bash
# Runs INSIDE the chroot: removes Autopsy (and the JRE only it uses) to produce the LIGHT ISO from a rootfs that already has it.
export DEBIAN_FRONTEND=noninteractive
rm -rf /opt/autopsy /usr/local/bin/autopsy /usr/lib/libtsk_jni.so /usr/local/share/java/sleuthkit-4.15.0.jar
SIM=$(apt-get -s purge openjdk-17-jre openjdk-17-jre-headless 2>/dev/null | grep -E '^(Remv|Purg)' || true)
echo "simulated purge:"; echo "$SIM" | head -20
# only remove if the simulation touches nothing but java/jre packages (nothing important dragged along)
if echo "$SIM" | grep -Ev '(Remv|Purg) (openjdk-17-jre|openjdk-17-jre-headless|ca-certificates-java|java-common|default-jre|default-jre-headless)\b' | grep -q .; then
  echo "WARNING: the purge would remove other packages; keeping the JRE"
else
  apt-get -y purge openjdk-17-jre openjdk-17-jre-headless >/dev/null 2>&1 || true
  apt-get -y autoremove --purge >/dev/null 2>&1 || true
fi
ldconfig; echo "strip-autopsy OK"
