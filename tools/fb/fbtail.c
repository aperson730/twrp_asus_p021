/*
 * fbtail: show text sent from the PC on the tablet screen (scrolling, like a terminal).
 * Reads a FIFO and draws the most recent lines on /dev/graphics/fb0.
 *
 * Build (PC, needs 32-bit glibc):  gcc -m32 -static -O2 fbtail.c -o fbtail
 * Run (tablet, TWRP stopped):      /data/local/tmp/fbtail FONT.psfu [scale] [fifo]
 * Default FIFO: /data/local/tmp/term   (created if missing)
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
#include <sys/stat.h>
#include <linux/fb.h>

#define RING 4096
#define MAXC 256

static unsigned char *font, *fbp, *back;
static int fw, fh, cs, hdr, stride, W, H, scale = 2, cols, rows;
static char (*lines)[MAXC];
static int *len;
static long total = 0;   /* index of the current (last) line */
static int fd;
static struct fb_var_screeninfo v;

static int load_font(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); return -1; }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    rewind(f);
    font = malloc(n);
    if (!font || fread(font, 1, n, f) != (size_t)n) { fclose(f); fprintf(stderr, "cannot read font\n"); return -1; }
    fclose(f);
    if (n > 32 && font[0] == 0x72 && font[1] == 0xb5 && font[2] == 0x4a && font[3] == 0x86) {
        hdr = *(uint32_t *)(font + 8);
        cs = *(uint32_t *)(font + 20);
        fh = *(uint32_t *)(font + 24);
        fw = *(uint32_t *)(font + 28);
    } else if (n > 4 && font[0] == 0x36 && font[1] == 0x04) {
        hdr = 4; cs = font[3]; fh = cs; fw = 8;
    } else {
        fprintf(stderr, "not a PSF font\n");
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
            uint32_t col = (g[y * rb + x / 8] & (0x80 >> (x % 8))) ? 0x0000FF00 : 0; /* green on black */
            for (int sy = 0; sy < scale; sy++)
                for (int sx = 0; sx < scale; sx++)
                    put(gx + x * scale + sx, gy + y * scale + sy, col);
        }
}

static void redraw(void) {
    memset(back, 0, (size_t)stride * H);
    long first = total - rows + 1;
    if (first < 0) first = 0;
    for (int r = 0; r < rows; r++) {
        long n = first + r;
        if (n > total) break;
        int idx = n % RING;
        for (int c = 0; c < len[idx]; c++) glyph(c * fw * scale, r * fh * scale, (unsigned char)lines[idx][c]);
    }
    for (int pass = 0; pass < 2; pass++) {   /* twice: covers drivers that alternate buffers */
        for (int y = 0; y < H; y++) memcpy(fbp + (size_t)y * stride, back + (size_t)y * stride, W * 4);
        v.yoffset = 0;
        ioctl(fd, FBIOPAN_DISPLAY, &v);
    }
}

static void newline(void) {
    total++;
    len[total % RING] = 0;
}

static void feed(const char *buf, int n) {
    static int esc = 0;
    for (int i = 0; i < n; i++) {
        unsigned char ch = buf[i];
        if (esc) { if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')) esc = 0; continue; }
        if (ch == 27) { esc = 1; continue; }          /* skip ANSI escape sequences */
        if (ch == '\r') continue;
        if (ch == '\n') { newline(); continue; }
        if (ch == '\t') ch = ' ';
        if (ch < 32 && ch != 0) continue;
        int idx = total % RING;
        if (len[idx] >= cols || len[idx] >= MAXC - 1) { newline(); idx = total % RING; }
        lines[idx][len[idx]++] = ch;
    }
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: fbtail font.psf [scale] [fifo]\n"); return 1; }
    if (argc > 2) scale = atoi(argv[2]);
    if (scale < 1) scale = 1;
    const char *fifo = argc > 3 ? argv[3] : "/data/local/tmp/term";
    if (load_font(argv[1])) return 1;

    fd = open("/dev/graphics/fb0", O_RDWR);
    if (fd < 0) { perror("/dev/graphics/fb0"); return 1; }
    struct fb_fix_screeninfo f;
    if (ioctl(fd, FBIOGET_VSCREENINFO, &v) || ioctl(fd, FBIOGET_FSCREENINFO, &f)) { perror("fb ioctl"); return 1; }
    W = v.xres; H = v.yres; stride = f.line_length;
    fbp = mmap(0, f.smem_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (fbp == MAP_FAILED) { perror("mmap"); return 1; }
    back = calloc(1, (size_t)stride * H);
    lines = calloc(RING, MAXC);
    len = calloc(RING, sizeof(int));
    cols = W / (fw * scale);
    rows = H / (fh * scale);
    if (cols > MAXC - 1) cols = MAXC - 1;
    if (!back || !lines || !len || cols < 1 || rows < 1) { fprintf(stderr, "setup failed\n"); return 1; }

    mkfifo(fifo, 0666);
    redraw();
    for (;;) {
        int in = open(fifo, O_RDONLY);          /* blocks until a writer connects */
        if (in < 0) { perror(fifo); sleep(1); continue; }
        char buf[1024];
        int n;
        while ((n = read(in, buf, sizeof buf)) > 0) {
            feed(buf, n);
            redraw();
        }
        close(in);                              /* writer finished, wait for the next one */
    }
}
