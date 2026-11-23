#include "VSimTop.h"
#include "verilated.h"

#include <cassert>
#include <cstdint>
#include <cstdio>

extern "C" void flash_read(int32_t addr, int32_t *data) {
    std::fprintf(stderr, "flash_read(0x%08x)\n", static_cast<unsigned>(addr));
    std::fflush(stderr);
    assert(0);
}

int main(int argc, char **argv) {
    VerilatedContext ctx;
    ctx.commandArgs(argc, argv);

    VSimTop top{&ctx};
    top.clock = 0;
    top.cpuClock = 0;
    top.reset = 1;
    top.coreSel = 0;
    top.externalPins_mygpio_in = 0;
    top.externalPins_uart0_rx = 1;

    auto tick = [&]() {
        top.clock = 0;
        top.cpuClock = 0;
        top.eval();
        top.clock = 1;
        top.cpuClock = 1;
        top.eval();
    };

    for (int i = 0; i < 200; i++)
        tick();

    top.reset = 0;
    for (long i = 0; i < 2000000 && !ctx.gotFinish(); i++)
        tick();

    std::printf("finished without flash_read\n");
    return 0;
}
