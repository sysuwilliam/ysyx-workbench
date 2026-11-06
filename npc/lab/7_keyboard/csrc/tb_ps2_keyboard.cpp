// 用法（在 7_keyboard 目录下）：
//   make TOP=ps2_keyboard TB=tb_ps2_keyboard VFLAGS="-cc --exe -j 0 -Wall --trace-fst" run
// 波形：tb_ps2_keyboard.fst，用 gtkwave 打开

#include <cstdint>
#include <cstdio>
#include "Vps2_keyboard.h"
#include "verilated.h"
#ifdef VM_TRACE_FST
#include "verilated_fst_c.h"
#endif

static Vps2_keyboard dut;
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

static void reset() {
    dut.clrn = 0;
    dut.nextdata_n = 1;
    dut.ps2_clk = 1;
    dut.ps2_data = 1;
    run(4);
    dut.clrn = 1;
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

static void read_one() {
    dut.nextdata_n = 0;
    tick();
    dut.nextdata_n = 1;
    tick();
}

static void expect_byte(const char* tag, uint8_t exp) {
    expect(tag, dut.data, exp);
    char buf[64];
    std::snprintf(buf, sizeof(buf), "%s ready", tag);
    expect(buf, dut.ready, 1);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
#ifdef VM_TRACE_FST
    Verilated::traceEverOn(true);
    tfp = new VerilatedFstC;
    dut.trace(tfp, 99);
    tfp->open(argc > 1 ? argv[1] : "tb_ps2_keyboard.fst");
#endif

    reset();
    expect("复位后 ready", dut.ready, 0);

    send_frame(0x1C);
    expect_byte("收到 1C", 0x1C);
    read_one();
    expect("读走后 ready", dut.ready, 0);
    expect("读走后 data", dut.data, 0x00);

    send_frame(0x1C);
    send_frame(0x1D);
    send_frame(0xF0);
    expect_byte("队头 1C", 0x1C);
    read_one();
    expect_byte("第二个 1D", 0x1D);
    read_one();
    expect_byte("第三个 F0", 0xF0);
    read_one();
    expect("清空后 ready", dut.ready, 0);

    send_frame(0x55, true, false, false);
    expect("奇偶错后 ready", dut.ready, 0);

    send_frame(0x55, false, true, false);
    expect("停止位错后 ready", dut.ready, 0);

    send_frame(0x55, false, false, true);
    expect("起始位错后 ready", dut.ready, 0);

    send_frame(0x1F);
    expect_byte("错帧之后仍能收", 0x1F);
    read_one();

    for (int i = 0; i < 9; i++) send_frame((uint8_t)(0x10 + i));
    expect("写满后 overflow", dut.overflow, 1);
    expect("写满后 ready", dut.ready, 1);

    reset();
    expect("复位后 overflow", dut.overflow, 0);
    expect("复位后 ready", dut.ready, 0);

    std::printf("errors=%d\n", errors);
#ifdef VM_TRACE_FST
    tfp->close();
    std::printf("wave=%s\n", argc > 1 ? argv[1] : "tb_ps2_keyboard.fst");
#endif
    return errors ? 1 : 0;
}
