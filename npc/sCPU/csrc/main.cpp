#include <nvboard.h>
#include "VsCPU_board.h"

static VsCPU_board dut;

void nvboard_bind_all_pins(VsCPU_board* top);

static void single_cycle() {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
}

int main() {
    nvboard_bind_all_pins(&dut);
    nvboard_init();

    dut.rst = 1;
    for (int i = 0; i < 16; i++)
        single_cycle();
    dut.rst = 0;

    while (1) {
        nvboard_update();
        single_cycle();
    }
}
