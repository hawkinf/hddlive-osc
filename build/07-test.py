#!/usr/bin/env python3
"""Boot test of the ISO under QEMU/KVM (BIOS or UEFI), with screenshots and commands typed into the live session via QMP.
usage: 07-test.py <bios|uefi> <iso> <outdir> [--cmds file]"""
import json, os, socket, subprocess, sys, time, zlib, struct, shutil

mode, iso, out = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(out, exist_ok=True)
sock = f"/tmp/hddlive-qmp-{mode}.sock"
if os.path.exists(sock): os.unlink(sock)

args = ["qemu-system-x86_64", "-enable-kvm", "-cpu", "host", "-m", "4096", "-smp", "4",
        "-vga", "std", "-display", "none", "-nic", "user",
        "-qmp", f"unix:{sock},server=on,wait=off", "-name", f"hddlive-test-{mode}"]
if os.environ.get("USBMODE"):   # the hybrid ISO as a USB flash drive (as it will really be used)
    args += ["-drive", f"if=none,id=u0,format=raw,file={iso},readonly=on", "-device", "qemu-xhci", "-device", "usb-storage,drive=u0,bootindex=0"]
else:
    args += ["-cdrom", iso, "-boot", "d"]
# bonus "faulty" virtual disk, so the live system has something to list
disk = f"{out}/testdisk.img"
subprocess.run(["qemu-img", "create", "-f", "raw", disk, "512M"], check=True, stdout=subprocess.DEVNULL)
args += ["-drive", f"file={disk},format=raw,if=none,id=d0", "-device", "ide-hd,drive=d0,serial=HDDLIVE-TEST,model=TESTDISK"]
if mode == "uefi":
    vars_copy = f"{out}/OVMF_VARS.fd"
    shutil.copy("/usr/share/OVMF/OVMF_VARS_4M.fd", vars_copy)
    args += ["-drive", "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd",
             "-drive", f"if=pflash,format=raw,file={vars_copy}"]
proc = subprocess.Popen(args, stdout=open(f"{out}/qemu.log", "w"), stderr=subprocess.STDOUT)

for _ in range(50):
    if os.path.exists(sock): break
    time.sleep(0.2)
s = socket.socket(socket.AF_UNIX); s.connect(sock); f = s.makefile("rw")
f.readline(); f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n"); f.flush(); f.readline()

def qmp(cmd, **a):
    f.write(json.dumps({"execute": cmd, "arguments": a}) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r: return r

def hmp(c): return qmp("human-monitor-command", **{"command-line": c})

def ppm2png(src, dst):
    d = open(src, "rb").read()
    parts = d.split(b"\n", 3)               # P6 \n W H \n 255 \n data
    w, h = map(int, parts[1].split()); px = parts[3]
    raw = b"".join(b"\x00" + px[y * w * 3:(y + 1) * w * 3] for y in range(h))
    def chunk(t, c): return struct.pack(">I", len(c)) + t + c + struct.pack(">I", zlib.crc32(t + c) & 0xffffffff)
    open(dst, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) +
                          chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
    os.unlink(src)

def shot(name):
    p = f"/tmp/hddlive-{mode}-{name}.ppm"
    hmp(f"screendump {p}"); time.sleep(1)
    if os.path.exists(p): ppm2png(p, f"{out}/{mode}-{name}.png"); print("screenshot", name, flush=True)

KEYS = {" ": "spc", "-": "minus", ".": "dot", "/": "slash", ";": "semicolon", ",": "comma", "=": "equal", "\\": "backslash",
        "|": "shift-backslash", ">": "shift-dot", "<": "shift-comma", "_": "shift-minus", "&": "shift-7", ":": "shift-semicolon",
        "'": "apostrophe", '"': "shift-apostrophe", "*": "shift-8", "(": "shift-9", ")": "shift-0", "$": "shift-4", "~": "shift-grave_accent",
        "+": "shift-equal", "!": "shift-1", "@": "shift-2", "#": "shift-3", "%": "shift-5", "?": "shift-slash", "[": "bracket_left", "]": "bracket_right"}
def typ(text, delay=0.05):
    for ch in text:
        if ch == "\n": k = "ret"
        elif ch in KEYS: k = KEYS[ch]
        elif ch.isupper(): k = "shift-" + ch.lower()
        else: k = ch
        hmp(f"sendkey {k}"); time.sleep(delay)

t0 = time.time()
def wait_until(t):
    while time.time() - t0 < t: time.sleep(1)

wait_until(4);  shot("01-boot-menu")
for _ in range(int(os.environ.get("ENTRY_DOWN", "0"))):   # pick another menu entry (BIOS and UEFI)
    hmp("sendkey down"); time.sleep(0.4)
if os.environ.get("ENTRY_DOWN"): hmp("sendkey ret"); time.sleep(1)
wait_until(35); shot("02-booting")
wait_until(125); shot("03-desktop")
# open a terminal (Ctrl+Alt+T; twice because the 1st may be lost while the desktop finishes loading) and run checks
hmp("sendkey ctrl-alt-t"); time.sleep(7); hmp("sendkey ctrl-alt-t"); time.sleep(5); shot("04-terminal")
cmds = open(sys.argv[5]).read().strip().split("\n") if len(sys.argv) > 5 and sys.argv[4] == "--cmds" else []
for i, c in enumerate(cmds):
    if c.startswith("@sleep "):            # explicit pause between commands (e.g. wait for a GUI to open)
        time.sleep(float(c.split()[1])); continue
    if c.startswith("@key "):              # single key press (e.g. @key ret)
        hmp("sendkey " + c.split()[1]); time.sleep(2); continue
    if c.startswith("@shot "):             # extra screenshot in the middle of the list
        shot(c.split()[1]); continue
    typ(c + "\n"); time.sleep(6 if "modprobe" in c or "lsmod" in c else 3)
    if i % 3 == 2 or i == len(cmds) - 1: shot(f"05-cmds-{i:02d}")
time.sleep(2); shot("06-final")
typ("exit\n"); time.sleep(3); shot("07-desktop-clean")
hmp("quit")
try: proc.wait(timeout=15)
except Exception: proc.kill()
print("test finished", mode, flush=True)
