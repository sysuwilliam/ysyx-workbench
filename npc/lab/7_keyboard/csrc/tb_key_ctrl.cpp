// 用法（在 7_keyboard 目录下）：
//   make TOP=key_ctrl TB=tb_key_ctrl VFLAGS="-cc --exe -j 0 -Wall --trace-fst" run
// 波形：tb_key_ctrl.fst，用 gtkwave 打开

#include <cstdint>
#include <cstdio>
#include <deque>
#include <initializer_list>
#include "Vkey_ctrl.h"
#include "verilated.h"
#ifdef VM_TRACE_FST
#include "verilated_fst_c.h"
#endif

static Vkey_ctrl dut;
static std::deque<unsigned char> q;
static uint64_t mtime = 0;
static int errors = 0;

#ifdef VM_TRACE_FST
static VerilatedFstC* tfp = nullptr;
#endif

static void tick() {
    if (!q.empty() && dut.nextdata_n == 0) q.pop_front();
    dut.ready = q.empty() ? 0 : 1;
    dut.data  = q.empty() ? 0 : q.front();
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
    q.clear();
    dut.clrn = 0;
    dut.ready = 0;
    dut.data = 0;
    run(4);
    dut.clrn = 1;
    run(2);
}

static void send(std::initializer_list<unsigned char> bytes) {
    for (auto b : bytes) q.push_back(b);
    run(12 * (int)bytes.size() + 8);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
#ifdef VM_TRACE_FST
    Verilated::traceEverOn(true);
    tfp = new VerilatedFstC;
    dut.trace(tfp, 99);
    tfp->open(argc > 1 ? argv[1] : "tb_key_ctrl.fst");
#endif

    reset();
    expect("复位后 code", dut.code, 0);
    expect("复位后 count", dut.count, 0);
    expect("复位后 show", dut.show, 0);

    send({0xF0, 0x1C});
    expect("空手收到松手 code", dut.code, 0);
    expect("空手收到松手 show", dut.show, 0);

    send({0x1C});
    expect("按 A code", dut.code, 0x1C);
    expect("按 A count", dut.count, 1);
    expect("按 A show", dut.show, 1);

    send({0x1C});
    expect("重复帧 count", dut.count, 1);

    send({0xF0, 0x1C});
    expect("松 A show", dut.show, 0);
    expect("松 A count", dut.count, 1);
    expect("松 A code", dut.code, 0x1C);

    send({0x23});
    expect("按 D code", dut.code, 0x23);
    expect("按 D count", dut.count, 2);
    expect("按 D show", dut.show, 1);

    send({0xF0, 0x1C});
    expect("松别的键 show", dut.show, 1);

    send({0xE0, 0x6B});
    expect("扩展键 code", dut.code, 0x23);
    expect("扩展键 count", dut.count, 2);
    expect("扩展键 show", dut.show, 1);

    send({0xE0, 0xF0, 0x6B});
    expect("扩展松开 code", dut.code, 0x23);
    expect("扩展松开 count", dut.count, 2);
    expect("扩展松开 show", dut.show, 1);

    send({0xF0, 0x23});
    expect("松 D show", dut.show, 0);

    send({0x1C, 0xF0, 0x1C, 0x23, 0xF0, 0x23});
    expect("连发后的 code", dut.code, 0x23);
    expect("连发后的 count", dut.count, 4);
    expect("连发后的 show", dut.show, 0);

    for (int i = 0; i < 120; i++) send({0x1C, 0xF0, 0x1C});
    expect("饱和 count", dut.count, 99);

    std::printf("errors=%d\n", errors);
#ifdef VM_TRACE_FST
    tfp->close();
    std::printf("wave=%s\n", argc > 1 ? argv[1] : "tb_key_ctrl.fst");
#endif
    return errors ? 1 : 0;
}
