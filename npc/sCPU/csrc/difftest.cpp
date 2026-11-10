#include "VsCPU.h"
#include "verilated.h"
#include "sEMU.h"

#include <cstdint>
#include <cstdio>

static const uint8_t PROG[] = {
    0x40, 0x90, 0xa1, 0xb1, 0x03, 0xb1,
    0x16, 0x58, 0x2b, 0xf6, 0xc3,
};

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    VsCPU* top = new VsCPU{contextp};

    auto tick = [&]() {
        top->clk = 1;
        top->eval();
        top->clk = 0;
        top->eval();
    };

    top->clk = 0;
    top->rst = 1;
    top->hold = 0;
    top->btn = 0;
    top->sw = 10;
    top->eval();

    ref_reset();
    ref_set_sw(10);
    ref_load(PROG, (int)sizeof(PROG));

    tick();
    tick();

    top->rst = 0;
    top->eval();

    top->btn = 1;
    tick();
    top->btn = 0;

    int errors = 0;

    for (int step = 1; step <= 50; step++) {
        tick();
        ref_inst_cycle();

        uint8_t dut_r[4] = {top->dbg_r0, top->dbg_r1, top->dbg_r2, top->dbg_r3};
        const uint8_t* ref_r = ref_get_regs();
        bool diff = false;

        if (top->dbg_pc != ref_get_pc()) {
            std::printf("[DiffTest] step %d PC mismatch: dut=0x%02x ref=0x%02x\n",
                        step, (unsigned)top->dbg_pc, (unsigned)ref_get_pc());
            diff = true;
        }

        for (int i = 0; i < 4; i++) {
            if (dut_r[i] != ref_r[i]) {
                std::printf("[DiffTest] step %d r%d mismatch: dut=0x%02x ref=0x%02x\n",
                            step, i, dut_r[i], ref_r[i]);
                diff = true;
            }
        }

        if (diff) {
            errors++;
            break;
        }
    }

    if (errors == 0)
        std::printf("[DiffTest] PASS after 50 instructions\n");
    else
        std::printf("[DiffTest] FAIL\n");

    top->final();
    delete top;
    delete contextp;

    return errors ? 1 : 0;
}
