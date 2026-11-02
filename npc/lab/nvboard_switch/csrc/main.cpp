#include <nvboard.h>
#include "Vsw.h"

static Vsw dut;

void nvboard_bind_all_pins(Vsw* top);

int main() {
    nvboard_bind_all_pins(&dut);
    nvboard_init();

    while (1) {
        nvboard_update();   // 读拨码开关、刷新 LED
        dut.eval();         // 组合逻辑求值
    }
}
