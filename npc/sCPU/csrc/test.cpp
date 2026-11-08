#include "VsCPU.h"
#include "verilated.h"

#include <cstdio>

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    VsCPU* top = new VsCPU{contextp};

    int errors = 0;

    auto tick = [&]() {
        top->clk = 1;
        top->eval();
        top->clk = 0;
        top->eval();
    };

    auto check = [&](bool cond, const char* name, unsigned got, unsigned exp) {
        if (!cond) {
            std::printf("[FAIL] %s: got 0x%02x, expected 0x%02x\n", name, got, exp);
            errors++;
        }
    };

    top->clk = 0;
    top->rst = 1;
    top->btn = 0;
    top->hold = 0;
    top->sw = 10;
    top->eval();

    tick();
    tick();

    check(top->dbg_pc == 0, "reset pc", top->dbg_pc, 0);
    check(top->dbg_instr == 0x40, "reset instr", top->dbg_instr, 0x40);
    check(top->dbg_r0 == 0 && top->dbg_r1 == 0 && top->dbg_r2 == 0 && top->dbg_r3 == 0,
          "reset gpr", top->dbg_r1, 0);
    check(top->led == 0 && top->hex == 0, "reset io", top->led, 0);
    check(top->seg0 == 0xff && top->seg1 == 0xff && top->seg2 == 0xff, "reset seg off", top->seg0, 0xff);

    top->rst = 0;
    top->eval();

    for (int i = 0; i < 5; i++)
        tick();

    check(top->dbg_pc == 0, "frozen pc", top->dbg_pc, 0);
    check(top->dbg_r0 == 0 && top->dbg_r1 == 0, "frozen gpr", top->dbg_r1, 0);
    check(top->led == 0 && top->hex == 0, "frozen io", top->led, 0);
    check(top->seg0 == 0xff && top->seg1 == 0xff && top->seg2 == 0xff, "frozen seg off", top->seg0, 0xff);

    top->btn = 1;
    tick();
    top->btn = 0;

    for (int i = 0; i < 46; i++)
        tick();

    check(top->dbg_pc == 10, "round1 pc", top->dbg_pc, 10);
    check(top->dbg_r0 == 11, "round1 r0", top->dbg_r0, 11);
    check(top->dbg_r1 == 55, "round1 r1", top->dbg_r1, 55);
    check(top->dbg_r2 == 11, "round1 r2", top->dbg_r2, 11);
    check(top->dbg_r3 == 1, "round1 r3", top->dbg_r3, 1);
    check(top->led == 0x37, "round1 led", top->led, 0x37);
    check(top->hex == 0x37, "round1 hex", top->hex, 0x37);
    check(top->seg0 == 0x49, "round1 seg0", top->seg0, 0x49);
    check(top->seg1 == 0x49, "round1 seg1", top->seg1, 0x49);
    check(top->seg2 == 0xff, "round1 seg2", top->seg2, 0xff);

    for (int i = 0; i < 3; i++)
        tick();

    check(top->dbg_pc == 10 && top->dbg_r1 == 55, "round1 halt", top->dbg_pc, 10);
    check(top->led == 0x37 && top->hex == 0x37, "round1 halt io", top->led, 0x37);

    top->sw = 15;
    top->btn = 1;
    tick();
    top->btn = 0;

    check(top->dbg_pc == 0, "round2 restart pc", top->dbg_pc, 0);
    check(top->dbg_r0 == 0 && top->dbg_r1 == 0 && top->dbg_r2 == 0 && top->dbg_r3 == 0,
          "round2 restart gpr", top->dbg_r1, 0);
    check(top->led == 0 && top->hex == 0, "round2 restart io", top->led, 0);
    check(top->seg0 == 0xff && top->seg1 == 0xff && top->seg2 == 0xff, "round2 restart seg off", top->seg0, 0xff);

    for (int i = 0; i < 66; i++)
        tick();

    check(top->dbg_pc == 10, "round2 pc", top->dbg_pc, 10);
    check(top->dbg_r0 == 16, "round2 r0", top->dbg_r0, 16);
    check(top->dbg_r1 == 120, "round2 r1", top->dbg_r1, 120);
    check(top->dbg_r2 == 16, "round2 r2", top->dbg_r2, 16);
    check(top->dbg_r3 == 1, "round2 r3", top->dbg_r3, 1);
    check(top->led == 0x78, "round2 led", top->led, 0x78);
    check(top->hex == 0x78, "round2 hex", top->hex, 0x78);
    check(top->seg0 == 0x03, "round2 seg0", top->seg0, 0x03);
    check(top->seg1 == 0x25, "round2 seg1", top->seg1, 0x25);
    check(top->seg2 == 0x9f, "round2 seg2", top->seg2, 0x9f);

    top->rst = 1;
    tick();
    tick();

    check(top->dbg_pc == 0, "reset2 pc", top->dbg_pc, 0);
    check(top->led == 0 && top->hex == 0, "reset2 io", top->led, 0);
    check(top->seg0 == 0xff && top->seg1 == 0xff && top->seg2 == 0xff, "reset2 seg off", top->seg0, 0xff);

    top->rst = 0;
    top->eval();

    for (int i = 0; i < 3; i++)
        tick();

    check(top->dbg_pc == 0, "frozen after reset", top->dbg_pc, 0);

    std::printf("sCPU: 2 rounds, %d errors\n", errors);

    top->final();
    delete top;
    delete contextp;

    return errors ? 1 : 0;
}
