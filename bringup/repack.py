import struct, sys, hashlib
orig, rd_path, out = sys.argv[1:4]
f = open(orig, 'rb').read()
assert f[:8] == b'ANDROID!'
ksize, kaddr, rsize, raddr, ssize, saddr, taddr, page, hv, osv = struct.unpack('<10I', f[8:48])
up = lambda n: (n + page - 1) // page * page
koff = page; roff = koff + up(ksize); soff = roff + up(rsize)
kernel = f[koff:koff+ksize]
second = f[soff:soff+ssize]
rd = open(rd_path, 'rb').read()
hdr = bytearray(f[:page])
struct.pack_into('<I', hdr, 16, len(rd))
if len(sys.argv) > 4: struct.pack_into('<I', hdr, 20, int(sys.argv[4], 0))
h = hashlib.sha1()
for b in (kernel, rd, second):
    h.update(b); h.update(struct.pack('<I', len(b)))
hdr[576:608] = h.digest().ljust(32, b'\0')
pad = lambda b: b + b'\0' * (up(len(b)) - len(b))
open(out, 'wb').write(bytes(hdr) + pad(kernel) + pad(rd) + pad(second))
print("wrote", out)
