#!/bin/bash
# Run inside an ubuntu:12.04 container as root, with the ASUS source mounted at /ksrc.
# Setup (once): sed -i 's|archive.ubuntu.com|old-releases.ubuntu.com|g; s|security.ubuntu.com|old-releases.ubuntu.com|g' /etc/apt/sources.list
#               apt-get update && apt-get install -y build-essential perl bc openssl
set -e
SRC=/ksrc/Z300CG_V4.6.5-update/linux-3.10
OUT=/ksrc/koutP
CONFIG=${1:-/ksrc/stock-embedded.config}
gcc --version | head -1                      # expect 4.6.3
export TARGET_BUILD_VARIANT=user
cd "$SRC"
mkdir -p "$OUT" && cp "$CONFIG" "$OUT/.config"
make O="$OUT" ARCH=i386 olddefconfig
scripts/config --file "$OUT/.config" --set-str LOCALVERSION "-00002-ge2a1f04"
scripts/config --file "$OUT/.config" --disable LOCALVERSION_AUTO
make O="$OUT" ARCH=i386 -j4 bzImage
cp "$OUT/arch/x86/boot/bzImage" /ksrc/bzImage-built
echo "done: /ksrc/bzImage-built"
