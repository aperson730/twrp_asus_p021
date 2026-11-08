# Framebuffer tools (ASUS P021, TWRP stopped)

- fbview.c: draws a text file with a PSF font on /dev/graphics/fb0, taps page through it.
- fbtail.c: scrolling screen fed by a FIFO (/data/local/tmp/term), for showing PC-side output.
- Lat2-Terminus16.psfu: console font (Terminus, 8x16, uncompressed PSF2). Check its licence
  before redistributing; it comes from the kbd/console-fonts packages.

Build (PC, needs 32-bit glibc):  gcc -m32 -static -O2 fbview.c -o fbview
Use (tablet): setprop ctl.stop recovery, then run with the full path.
Note: the real framebuffer node is /dev/graphics/fb0. /dev/fb0 does not exist, and writing
to it creates a stray RAM file instead.
Framebuffer: 800x1280, 32 bpp, byte order R,G,B,X, stride 3200.
Binaries are not committed.
