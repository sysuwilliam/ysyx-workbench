#include <nvboard.h>
#include "Vpri_top.h"

static Vpri_top dut;

void nvboard_bind_all_pins(Vpri_top* top);

int main() {
    nvboard_bind_all_pins(&dut);
    nvboard_init();

    while (1) {
        nvboard_update();   
        dut.eval();         
    }
}
