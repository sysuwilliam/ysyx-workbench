// 用法（在 7_keyboard 目录下）：
//   make TOP=keyboard TB=tb_keyboard NVBOARD=0 VFLAGS="-cc --exe -j 0 -Wall --trace-fst" run
// 波形：tb_keyboard.fst，用 gtkwave 打开

#include <cstdint>
#include <cstdio>
#include "Vkeyboard.h"
#include "verilated.h"
#ifdef VM_TRACE_FST
#include "verilated_fst_c.h"
#endif

static Vkeyboard dut;
static uint64_t mtime = 0;
static int errors = 0;
static const int HALF = 5;

#ifdef VM_TRACE_FST
static VerilatedFstC* tfp = nullptr;
#endif

static void tick() {
    dut.clk = 0; dut.eval(); mtime += 5;
    dut.clk = 1; dut.eval(); mtime += 5;
#ifdef VM_TRACE_FST
    tfp->dump(mtime);
#endif
}

static void run(int n) { while (n-- > 0) tick(); }

static void expect(const char* tag, unsigned got, unsigned exp) {
    if (got != exp) {
        std::printf("[FAIL] %-24s got 0x%02x exp 0x%02x\n", tag, got, exp);
        errors++;
    }
    else {
        std::printf("[ ok ] %-24s 0x%02x\n", tag, got);
    }
}

static unsigned seg_pat(unsigned v) {
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

static void reset() {
    dut.rst = 1;
    dut.ps2_clk = 1;
    dut.ps2_data = 1;
    run(8);
    dut.rst = 0;
    run(4);
}

static void send_frame(uint8_t code, bool bad_parity = false,
                       bool bad_stop = false, bool bad_start = false) {
    unsigned ones = 0;
    for (int i = 0; i < 8; i++) ones += (code >> i) & 1u;

    unsigned bits[11];
    bits[0] = bad_start ? 1u : 0u;
    for (int i = 0; i < 8; i++) bits[1 + i] = (code >> i) & 1u;
    bits[9] = (ones & 1u) ? 0u : 1u;
    if (bad_parity) bits[9] ^= 1u;
    bits[10] = bad_stop ? 0u : 1u;

    for (int i = 0; i < 11; i++) {
        dut.ps2_data = bits[i];
        run(HALF);
        dut.ps2_clk = 0;
        run(HALF);
        dut.ps2_clk = 1;
    }
    dut.ps2_data = 1;
    run(HALF);
    run(8);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
#ifdef VM_TRACE_FST
    Verilated::traceEverOn(true);
    tfp = new VerilatedFstC;
    dut.trace(tfp, 99);
    tfp->open(argc > 1 ? argv[1] : "tb_keyboard.fst");
#endif

    reset();
    expect("复位 seg0", dut.seg0, 0xFF);
    expect("复位 seg1", dut.seg1, 0xFF);
    expect("复位 seg2", dut.seg2, 0xFF);
    expect("复位 seg3", dut.seg3, 0xFF);
    expect("复位 seg4", dut.seg4, seg_pat(0));
    expect("复位 seg5", dut.seg5, seg_pat(0));

    send_frame(0x1C);
    expect("按 A seg1 键码高", dut.seg1, seg_pat(0x1));
    expect("按 A seg0 键码低", dut.seg0, seg_pat(0xC));
    expect("按 A seg3 ASCII 高", dut.seg3, seg_pat(0x6));
    expect("按 A seg2 ASCII 低", dut.seg2, seg_pat(0x1));
    expect("按 A seg4 次数个位", dut.seg4, seg_pat(1));
    expect("按 A seg5 次数十位", dut.seg5, seg_pat(0));

    send_frame(0x1C);
    expect("重复帧 seg4", dut.seg4, seg_pat(1));

    send_frame(0xF0);
    send_frame(0x1C);
    expect("松开 seg0", dut.seg0, 0xFF);
    expect("松开 seg1", dut.seg1, 0xFF);
    expect("松开 seg2", dut.seg2, 0xFF);
    expect("松开 seg3", dut.seg3, 0xFF);
    expect("松开 seg4", dut.seg4, seg_pat(1));

    send_frame(0x16);
    expect("按 1 seg0", dut.seg0, seg_pat(0x6));
    expect("按 1 seg1", dut.seg1, seg_pat(0x1));
    expect("按 1 seg2", dut.seg2, seg_pat(0x1));
    expect("按 1 seg3", dut.seg3, seg_pat(0x3));
    expect("按 1 seg4", dut.seg4, seg_pat(2));

    send_frame(0xE0);
    send_frame(0x6B);
    expect("扩展键 seg0", dut.seg0, seg_pat(0x6));
    expect("扩展键 seg4", dut.seg4, seg_pat(2));

    send_frame(0xE0);
    send_frame(0xF0);
    send_frame(0x6B);
    expect("扩展松开 seg4", dut.seg4, seg_pat(2));

    send_frame(0xF0);
    send_frame(0x16);
    expect("松开 1 seg0", dut.seg0, 0xFF);

    send_frame(0x12);
    expect("Shift seg1", dut.seg1, seg_pat(0x1));
    expect("Shift seg0", dut.seg0, seg_pat(0x2));
    expect("Shift seg3", dut.seg3, 0xFF);
    expect("Shift seg2", dut.seg2, 0xFF);
    expect("Shift seg4", dut.seg4, seg_pat(3));
    send_frame(0xF0);
    send_frame(0x12);

    for (int i = 0; i < 100; i++) {
        send_frame(0x23);
        send_frame(0xF0);
        send_frame(0x23);
    }
    expect("饱和 seg5", dut.seg5, seg_pat(9));
    expect("饱和 seg4", dut.seg4, seg_pat(9));
    expect("饱和 seg0", dut.seg0, 0xFF);
    expect("饱和 seg3", dut.seg3, 0xFF);

    std::printf("errors=%d\n", errors);
#ifdef VM_TRACE_FST
    tfp->close();
    std::printf("wave=%s\n", argc > 1 ? argv[1] : "tb_keyboard.fst");
#endif
    return errors ? 1 : 0;
}
