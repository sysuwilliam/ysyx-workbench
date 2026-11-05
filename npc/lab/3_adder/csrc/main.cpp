// ALU 接入 NVBoard 的顶层驱动（组合逻辑，无时钟）
//
// 引脚分配见 constr/ALU.nxdc：
//   SW7..SW4 = A[3:0]      SW3..SW0 = B[3:0]
//   BTNU = op[2]           BTNC = op[1]        BTND = op[0]
//   LD3..LD0 = out[3:0]    LD4 = zero          LD5 = carry    LD6 = overflow
//
// 跑法： make run
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
