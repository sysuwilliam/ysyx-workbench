
#include <nvboard.h>
#include "VALU.h"

static VALU dut;

void nvboard_bind_all_pins(VALU* top);

int main() {
    nvboard_bind_all_pins(&dut);
    nvboard_init();

    while (1) {
        nvboard_update();   // 读拨码开关与按钮、刷新 LED
        dut.eval();         // 组合逻辑求值一次
    }
}
