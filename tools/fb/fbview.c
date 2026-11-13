/*
 * fbview: tiny framebuffer text viewer for the ASUS Z300CG (P021).
 * Draws a text file with a PSF font on /dev/graphics/fb0 and pages with taps.
 *
 * Build (on the PC, needs 32-bit glibc):
 *   gcc -m32 -static -O2 fbview.c -o fbview
 *
 * Run (on the tablet, TWRP stopped with `setprop ctl.stop recovery`):
 *   /data/local/tmp/fbview FONT.psf TEXT.txt [scale] [/dev/input/eventN]
 *
 * Tap the left third of the screen: previous page. Anywhere else: next page.
 * Tested on the device.
 */
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/fb.h>
#include <linux/input.h>

static unsigned char *font;
static int fw, fh, cs, hdr;
static unsigned char *fbp;    /* mapped framebuffer */
static unsigned char *back;   /* back buffer in normal RAM */
static int stride, W, H, scale = 2;

static int load_font(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); return -1; }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    rewind(f);
    font = malloc(n);
    if (!font || fread(font, 1, n, f) != (size_t)n) { fclose(f); fprintf(stderr, "cannot read font\n"); return -1; }
    fclose(f);
    if (n > 32 && font[0] == 0x72 && font[1] == 0xb5 && font[2] == 0x4a && font[3] == 0x86) { /* PSF2 */
        hdr = *(uint32_t *)(font + 8);
        cs  = *(uint32_t *)(font + 20);
        fh  = *(uint32_t *)(font + 24);
        fw  = *(uint32_t *)(font + 28);
    } else if (n > 4 && font[0] == 0x36 && font[1] == 0x04) {                                 /* PSF1 */
        hdr = 4;
        cs = font[3];
        fh = cs;
        fw = 8;
    } else {
        fprintf(stderr, "not a PSF font (first bytes %02x %02x %02x %02x, size %ld); needs an uncompressed .psf/.psfu\n",
                font[0], font[1], font[2], font[3], n);
        return -1;
    }
    return 0;
}

static void put(int x, int y, uint32_t c) {
    if (x < 0 || y < 0 || x >= W || y >= H) return;
    *(uint32_t *)(back + (size_t)y * stride + x * 4) = c;
}

static void glyph(int gx, int gy, unsigned char ch) {
    unsigned char *g = font + hdr + (size_t)ch * cs;
    int rb = (fw + 7) / 8;
    for (int y = 0; y < fh; y++)
        for (int x = 0; x < fw; x++) {
            int on = g[y * rb + x / 8] & (0x80 >> (x % 8));
            uint32_t col = on ? 0x00FFFFFF : 0x00000000;
            for (int sy = 0; sy < scale; sy++)
                for (int sx = 0; sx < scale; sx++)
                    put(gx + x * scale + sx, gy + y * scale + sy, col);
        }
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: fbview font.psf text.txt [scale] [/dev/input/eventN]\n");
        return 1;
    }
    if (argc > 3) scale = atoi(argv[3]);
    if (scale < 1) scale = 1;
    const char *evp = argc > 4 ? argv[4] : "/dev/input/event2";
    if (load_font(argv[1])) return 1;

    FILE *tf = fopen(argv[2], "rb");
    if (!tf) { perror(argv[2]); return 1; }
    fseek(tf, 0, SEEK_END);
    long tn = ftell(tf);
    rewind(tf);
    char *txt = malloc(tn + 1);
    if (!txt || fread(txt, 1, tn, tf) != (size_t)tn) { fprintf(stderr, "cannot read text\n"); return 1; }
    txt[tn] = 0;
    fclose(tf);

    int fd = open("/dev/graphics/fb0", O_RDWR);
    if (fd < 0) { perror("/dev/graphics/fb0"); return 1; }
    struct fb_var_screeninfo v;
    struct fb_fix_screeninfo f;
    if (ioctl(fd, FBIOGET_VSCREENINFO, &v) || ioctl(fd, FBIOGET_FSCREENINFO, &f)) { perror("fb ioctl"); return 1; }
    W = v.xres;
    H = v.yres;
    stride = f.line_length;
    fbp = mmap(0, f.smem_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (fbp == MAP_FAILED) { perror("mmap"); return 1; }
    back = calloc(1, (size_t)stride * H);
    if (!back) { fprintf(stderr, "no memory\n"); return 1; }

    int cols = W / (fw * scale), rows = H / (fh * scale);
    if (cols < 1 || rows < 1) { fprintf(stderr, "scale too large\n"); return 1; }

    /* wrap the text into lines of at most `cols` characters */
    long cap = tn + 16;
    char **ln = malloc(sizeof(char *) * cap);
    int *ll = malloc(sizeof(int) * cap);
    long nl = 0;
    char *p = txt;
    while (*p) {
        char *s = p;
        int n = 0;
        while (*p && *p != '\n' && n < cols) { p++; n++; }
        if (n > 0 && s[n - 1] == '\r') n--;
        ln[nl] = s;
        ll[nl++] = n;
        if (*p == '\n') p++;
    }
    int pages = (int)((nl + rows - 1) / rows);
    if (pages < 1) pages = 1;

    int ev = open(evp, O_RDONLY);
    int xmax = 4095;
    struct input_absinfo ai;
    if (ev >= 0 && ioctl(ev, EVIOCGABS(ABS_MT_POSITION_X), &ai) == 0 && ai.maximum > 0) xmax = ai.maximum;

    int page = 0, lastx = 0;
    for (;;) {
        /* draw the whole page in RAM, then copy it out in one pass */
        memset(back, 0, (size_t)stride * H);
        for (int r = 0; r < rows; r++) {
            long i = (long)page * rows + r;
            if (i >= nl) break;
            for (int c = 0; c < ll[i]; c++) {
                unsigned char ch = ln[i][c];
                if (ch == '\t') ch = ' ';
                glyph(c * fw * scale, r * fh * scale, ch);
            }
        }
        /* copy twice: if the driver alternates between two internal buffers,
           both end up with the new page, so no stale lines remain */
        for (int pass = 0; pass < 2; pass++) {
            for (int y = 0; y < H; y++) memcpy(fbp + (size_t)y * stride, back + (size_t)y * stride, W * 4);
            v.yoffset = 0;
            ioctl(fd, FBIOPAN_DISPLAY, &v);
        }

        if (ev < 0) {
            fprintf(stderr, "cannot open %s, showing page 1 only\n", evp);
            return 0;
        }
        struct input_event e;
        for (;;) {
            if (read(ev, &e, sizeof e) != sizeof e) continue;
            if (e.type == EV_ABS && e.code == ABS_MT_POSITION_X) lastx = e.value;
            if (e.type == EV_ABS && e.code == ABS_MT_TRACKING_ID && e.value == -1) { /* finger lifted */
                if (lastx < xmax / 3) page = page > 0 ? page - 1 : 0;
                else page = page < pages - 1 ? page + 1 : page;
                break;
            }
        }
    }
}
