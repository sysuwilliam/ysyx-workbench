#include <nvboard.h>
#include "Vrandom.h"

static Vrandom dut;

void nvboard_bind_all_pins(Vrandom* top);

int main() {
    nvboard_bind_all_pins(&dut);
    nvboard_init();

    while (1) {
        nvboard_update();
        dut.eval();
    }
}
