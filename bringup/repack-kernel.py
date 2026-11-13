#!/usr/bin/env python3
"""Build a test boot image with a rebuilt kernel.

Usage: repack-kernel.py STOCK_RECOVERY_IMG RAMDISK_GZ OUT_IMG BZIMAGE

Like repack.py, but also replaces the kernel. The stock image does not hold a
plain bzImage: its kernel starts directly at the protected-mode entry code
(bytes fc f6 86 11 ...), i.e. the bzImage with the real-mode setup sectors cut
off. So this script strips (setup_sects + 1) * 512 bytes from the front of the
bzImage and updates the kernel size in the header.

Tested with `fastboot boot` (stock kernel and a gcc 4.6.3 rebuild both boot). Never flash.
"""
import hashlib
import struct
import sys

orig, rd_path, out, bz_path = sys.argv[1:5]

f = open(orig, 'rb').read()
assert f[:8] == b'ANDROID!', 'not an Android boot image'
ksize, kaddr, rsize, raddr, ssize, saddr, taddr, page, hv, osv = struct.unpack('<10I', f[8:48])
up = lambda n: (n + page - 1) // page * page
koff = page
roff = koff + up(ksize)
soff = roff + up(rsize)
second = f[soff:soff + ssize]

bz = open(bz_path, 'rb').read()
if bz[0x202:0x206] == b'HdrS':
    setup_sects = bz[0x1f1] or 4
    kernel = bz[(setup_sects + 1) * 512:]
else:
    kernel = bz    # already a raw, setup-stripped kernel (like the stock prebuilt/kernel)
import os
kernel += b'\0' * int(os.environ.get('PAD', '0'))   # control test: change the size only
print('kernel bytes', len(kernel), 'starts with', kernel[:8].hex())
print('stock kernel was', ksize, 'bytes at', hex(kaddr))

rd = open(rd_path, 'rb').read()
hdr = bytearray(f[:page])
struct.pack_into('<I', hdr, 8, len(kernel))    # kernel size
struct.pack_into('<I', hdr, 16, len(rd))       # ramdisk size

h = hashlib.sha1()
for b in (kernel, rd, second):
    h.update(b)
    h.update(struct.pack('<I', len(b)))
hdr[576:608] = h.digest().ljust(32, b'\0')

pad = lambda b: b + b'\0' * (up(len(b)) - len(b))
open(out, 'wb').write(bytes(hdr) + pad(kernel) + pad(rd) + pad(second))
print('wrote', out)
