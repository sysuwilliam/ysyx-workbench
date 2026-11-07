// 用法（在 8_vga 目录下）：
//   make TOP=vga_top TB=tb_vga_top NVBOARD=0 VFLAGS="-cc --exe -j 0 -Wall --trace-fst" run
// 波形：tb_vga_top.fst，用 gtkwave 打开

#include <cstdint>
#include <cstdio>
#include <vector>
#include "Vvga_top.h"
#include "verilated.h"
#ifdef VM_TRACE_FST
#include "verilated_fst_c.h"
#endif

static Vvga_top dut;
static uint64_t mtime = 0;
static int errors = 0;
static std::vector<unsigned> mem;
static int x = 1, y = 1;
static long n = 0, hsync_low = 0, vsync_low = 0;

#ifdef VM_TRACE_FST
static VerilatedFstC* tfp = nullptr;
#endif

static bool load_hex(const char* path) {
    FILE* f = std::fopen(path, "r");
    if (!f) return false;
    char buf[64];
    while (std::fgets(buf, sizeof(buf), f)) {
        if (buf[0] == '@') continue;
        unsigned v;
        if (std::sscanf(buf, "%x", &v) == 1) mem.push_back(v);
    }
    std::fclose(f);
    return mem.size() == 640u * 512u;
}

static void tick() {
    dut.clk = 0; dut.eval(); mtime += 5;
    dut.clk = 1; dut.eval(); mtime += 5;
#ifdef VM_TRACE_FST
    tfp->dump(mtime);
#endif
}

static void fail(const char* what, long idx, unsigned got, unsigned exp) {
    if (++errors <= 10)
        std::printf("[FAIL] 像素 %ld %s：实际 0x%06x，期望 0x%06x\n", idx, what, got, exp);
}

static void check() {
    if (!dut.VGA_HSYNC) hsync_low++;
    if (!dut.VGA_VSYNC) vsync_low++;

    if (dut.VGA_BLANK_N) {
        long h = n % 640;
        long v = (n / 640) % 480;
        unsigned exp = mem[h * 512 + v];
        unsigned got = (dut.VGA_R << 16) | (dut.VGA_G << 8) | dut.VGA_B;
        if (got != exp) fail("颜色", n, got, exp);
        n++;
    }
    else if (dut.VGA_R || dut.VGA_G || dut.VGA_B) {
        fail("消隐期颜色非零", n, 0, 0);
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
#ifdef VM_TRACE_FST
    Verilated::traceEverOn(true);
    tfp = new VerilatedFstC;
    dut.trace(tfp, 99);
    tfp->open(argc > 1 ? argv[1] : "tb_vga_top.fst");
#endif

    if (!load_hex("resource/picture.hex")) {
        std::printf("[FAIL] 读不到 resource/picture.hex 或长度不对\n");
        return 1;
    }

    dut.rst = 1; dut.clk = 0;
    for (int i = 0; i < 8; i++) tick();
    dut.rst = 0;

    const long frame = 800L * 525L;
    for (long i = 0; i < 2 * frame; i++) {
        tick();
        tick();
        if (x == 800) { x = 1; y = (y == 525) ? 1 : y + 1; }
        else x++;
        check();
    }

    std::printf("有效像素 %ld，行同步低 %ld，场同步低 %ld\n", n, hsync_low, vsync_low);
    if (n != 2L * 640 * 480) { std::printf("[FAIL] 有效像素数不对\n"); errors++; }
    if (hsync_low != 2L * 96 * 525) { std::printf("[FAIL] 行同步宽度不对\n"); errors++; }
    if (vsync_low != 2L * 800 * 2) { std::printf("[FAIL] 场同步宽度不对\n"); errors++; }

    std::printf("errors=%d\n", errors);
#ifdef VM_TRACE_FST
    tfp->close();
    std::printf("wave=%s\n", argc > 1 ? argv[1] : "tb_vga_top.fst");
#endif
    return errors ? 1 : 0;
}
