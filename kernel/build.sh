#!/bin/bash
# Run inside an ubuntu:12.04 container as root, with the ASUS source mounted at /ksrc.
# Setup (once): sed -i 's|archive.ubuntu.com|old-releases.ubuntu.com|g; s|security.ubuntu.com|old-releases.ubuntu.com|g' /etc/apt/sources.list
#               apt-get update && apt-get install -y build-essential perl bc openssl
# Usage: build.sh [CONFIG]. Default: /ksrc/kernel-running.config (the config the working build
# used), or /ksrc/stock-embedded.config. Both are copies of kernel/stock-embedded.config in this repo.
set -e
SRC=/ksrc/Z300CG_V4.6.5-update/linux-3.10
OUT=/ksrc/koutP
if [ -n "${1:-}" ]; then
  CONFIG=$1
elif [ -f /ksrc/kernel-running.config ]; then
  CONFIG=/ksrc/kernel-running.config
else
  CONFIG=/ksrc/stock-embedded.config
fi
[ -f "$CONFIG" ] || { echo "ERROR: config $CONFIG not found (copy kernel/stock-embedded.config into /ksrc)" >&2; exit 1; }
echo "config: $CONFIG"
gcc --version | head -1
# gcc 5.4 and 4.8 builds reset instantly at boot; only 4.6.3 is known to work
gcc --version | head -1 | grep -q ' 4\.6\.3' || { echo "ERROR: need gcc 4.6.3 (ubuntu:12.04 container)" >&2; exit 1; }
export TARGET_BUILD_VARIANT=user
cd "$SRC"
mkdir -p "$OUT" && cp "$CONFIG" "$OUT/.config"
make O="$OUT" ARCH=i386 olddefconfig
scripts/config --file "$OUT/.config" --set-str LOCALVERSION "-00002-ge2a1f04"
scripts/config --file "$OUT/.config" --disable LOCALVERSION_AUTO
make O="$OUT" ARCH=i386 -j4 bzImage
cp "$OUT/arch/x86/boot/bzImage" /ksrc/bzImage-built
echo "done: /ksrc/bzImage-built"
