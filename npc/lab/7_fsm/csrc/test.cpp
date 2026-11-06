#include <cstdio>
#include <cstring>
#include "Vrandom.h"
#include "verilated.h"

static Vrandom dut;
static int errors = 0;

static void press() {
    dut.clk_btn = 0; dut.eval();
    dut.clk_btn = 1; dut.eval();
    dut.clk_btn = 0; dut.eval();
}

static void reset_to(unsigned seed) {
    dut.seed    = seed;
    dut.rst_btn = 1;
    press();
    dut.rst_btn = 0;
    dut.eval();
}

static unsigned expect_seg(unsigned v) {
    static const unsigned code[16] = {
        0b1000000, 0b1111001, 0b0100100, 0b0110000,
        0b0011001, 0b0010010, 0b0000010, 0b1111000,
        0b0000000, 0b0010000, 0b0001000, 0b0000011,
        0b1000110, 0b0100001, 0b0000110, 0b0001110 };
    unsigned c = code[v & 15u], out = 1u;
    for (int i = 0; i < 7; i++)
        out |= ((c >> i) & 1u) << (7 - i);
    return out;
}

static void fail(const char* what, int step, unsigned got, unsigned exp) {
    if (++errors <= 10)
        printf("[FAIL] 第 %d 拍 %s：实际 0x%02x，期望 0x%02x\n", step, what, got, exp);
}

static int walk(unsigned start, const char* tag) {
    int seen[256];
    memset(seen, 0, sizeof(seen));
    seen[start] = 1;

    for (int step = 1; step <= 300; step++) {
        press();
        unsigned s = dut.led;

        if (s == start) {
            printf("%-6s 初值 0x%02x → 周期 %d\n", tag, start, step);
            return step;
        }
        if (s == 0)        { fail("出现全零状态", step, s, 1); return -1; }
        if (seen[s])       { fail("状态重复", step, s, 0); return -1; }
        seen[s] = 1;

        if (dut.seg0 != expect_seg(s & 15))
            fail("数码管0 译码", step, dut.seg0, expect_seg(s & 15));
        if (dut.seg1 != expect_seg(s >> 4))
            fail("数码管1 译码", step, dut.seg1, expect_seg(s >> 4));
    }
    fail("300 拍没回到初值", 300, dut.led, start);
    return -1;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    reset_to(0xA5);
    printf("seed=0xA5 复位后 = 0x%02x（期望 0xa5）\n", (unsigned)dut.led);
    if (dut.led != 0xA5) fail("复位值", 0, dut.led, 0xA5);

    reset_to(0x00);
    printf("seed=0x00 复位后 = 0x%02x（期望 0x01）\n", (unsigned)dut.led);
    if (dut.led != 0x01) fail("全零 seed 的退化", 0, dut.led, 0x01);

    reset_to(0x01);
    if (walk(0x01, "从 01") != 255) { printf("周期不是 255\n"); errors++; }
    reset_to(0xA5);
    if (walk(0xA5, "从 A5") != 255) { printf("周期不是 255\n"); errors++; }

    for (int i = 0; i < 7; i++) press();
    unsigned before = dut.led;
    reset_to(0x3C);
    printf("\n中途（0x%02x）重新复位到 0x3C → 0x%02x\n", before, (unsigned)dut.led);
    if (dut.led != 0x3C) fail("中途复位", -1, dut.led, 0x3C);

    printf("\n错 %d 项\n", errors);
    return errors ? 1 : 0;
}
