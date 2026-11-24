#include "VSimTop.h"
#include "verilated.h"
#include "nvboard.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <vector>

static constexpr size_t FLASH_SIZE = 16 * 1024 * 1024;
static std::vector<uint8_t> g_flash(FLASH_SIZE, 0);
static size_t g_flash_used = 0;
static bool g_halt = false;

extern "C" void npc_halt() {
    g_halt = true;
}

extern "C" void flash_read(int32_t addr, int32_t *data) {
    uint32_t a = static_cast<uint32_t>(addr);
    uint32_t v = 0;
    for (int i = 0; i < 4; i++) {
        size_t idx = static_cast<size_t>(a) + static_cast<size_t>(i);
        if (idx < g_flash.size())
            v |= static_cast<uint32_t>(g_flash[idx]) << (8 * i);
    }
    *data = static_cast<int32_t>(v);
}

void nvboard_bind_all_pins(VSimTop *top);

int main(int argc, char **argv) {
    std::setvbuf(stdout, nullptr, _IONBF, 0);
    std::setvbuf(stderr, nullptr, _IONBF, 0);

    const char *image = "/home/william/YSYX/ysyx-workbench/ysyxSoC/ready-to-run/minirv/hello-minirv-ysyxsoc.bin";
    long max_cycles = 500000000;
    for (int i = 1; i < argc; i++) {
        if (std::strncmp(argv[i], "+MAX_CYCLES=", 12) == 0) {
            max_cycles = std::strtol(argv[i] + 12, nullptr, 0);
        } else if (argv[i][0] != '+' && argv[i][0] != '-') {
            image = argv[i];
        }
    }

    std::ifstream f(image, std::ios::binary);
    if (!f) {
        std::fprintf(stderr, "[NVBoard] cannot open flash image: %s\n", image);
        return 1;
    }
    g_flash.assign(FLASH_SIZE, 0);
    f.read(reinterpret_cast<char *>(g_flash.data()), static_cast<std::streamsize>(FLASH_SIZE));
    g_flash_used = static_cast<size_t>(f.gcount());

    std::fprintf(stderr, "=== SoC + NVBoard ===\n");
    std::fprintf(stderr, "image      : %s\n", image);
    std::fprintf(stderr, "image size : %zu bytes\n", g_flash_used);
    std::fprintf(stderr, "max cycles : %ld\n", max_cycles);
    std::fprintf(stderr, "--------------------\n");

    VerilatedContext ctx;
    ctx.commandArgs(argc, argv);

    VSimTop top{&ctx};
    top.clock = 0;
    top.cpuClock = 0;
    top.reset = 1;
    top.coreSel = 0;
    top.externalPins_mygpio_in = 0;
    top.externalPins_uart0_rx = 1;

    nvboard_bind_all_pins(&top);
    nvboard_init();

    auto tick = [&]() {
        top.clock = 0;
        top.cpuClock = 0;
        top.eval();
        top.clock = 1;
        top.cpuClock = 1;
        top.eval();
        nvboard_update();
    };

    for (int i = 0; i < 200; i++)
        tick();

    top.reset = 0;
    std::fprintf(stderr, "[NVBoard] reset released, running...\n");

    long cycles = 0;
    while (cycles < max_cycles && !g_halt && !ctx.gotFinish()) {
        tick();
        cycles++;
        if (cycles % 10000000 == 0) {
            std::fprintf(stderr, "[NVBoard] %ldM cycles\n", cycles / 1000000);
            std::fflush(stderr);
        }
    }

    if (g_halt)
        std::fprintf(stderr, "[NVBoard] halted by ebreak/trap at %ld cycles\n", cycles);
    else
        std::fprintf(stderr, "[NVBoard] finished after %ld cycles (max cycles)\n", cycles);

    nvboard_quit();
    return 0;
}
