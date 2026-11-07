import struct, sys

f = open(sys.argv[1], 'rb').read()
if f[:8] != b'ANDROID!':
    sys.exit("not a boot image")

(ksize, kaddr, rsize, raddr, ssize, saddr, taddr,
 page, hdrver, osver) = struct.unpack('<10I', f[8:48])
name = f[48:64].split(b'\0')[0].decode(errors='replace')
cmdline = f[64:576].split(b'\0')[0].decode(errors='replace')
extra = f[608:1632].split(b'\0')[0].decode(errors='replace')

print("page size   :", page)
print("kernel      : size", ksize, "addr", hex(kaddr))
print("ramdisk     : size", rsize, "addr", hex(raddr))
print("second      : size", ssize, "addr", hex(saddr))
print("tags addr   :", hex(taddr))
print("header ver  :", hdrver)
print("name        :", name)
print("cmdline     :", cmdline)
print("extra cmdl. :", extra)

def up(n): return (n + page - 1) // page * page
koff = page
roff = koff + up(ksize)
soff = roff + up(rsize)
print("offsets     : kernel", koff, "ramdisk", roff, "second", soff)

if len(sys.argv) > 2:
    p = sys.argv[2]
    open(p + "-kernel", 'wb').write(f[koff:koff+ksize])
    open(p + "-ramdisk.gz", 'wb').write(f[roff:roff+rsize])
    print("wrote", p + "-kernel and", p + "-ramdisk.gz")
