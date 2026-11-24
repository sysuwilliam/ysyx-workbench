#include "VSimTop.h"
#include "verilated.h"

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iterator>
#include <vector>

static constexpr size_t FLASH_SIZE = 16 * 1024 * 1024;
static std::vector<uint8_t> g_flash(FLASH_SIZE, 0);
static size_t g_flash_used = 0;
static bool g_assert_flash = false;
static bool g_halt = false;

extern "C" void npc_halt() {
    g_halt = true;
}

extern "C" void flash_read(int32_t addr, int32_t *data) {
    if (g_assert_flash) {
        std::fprintf(stderr, "[flash] read 0x%08x -> assert(0)\n",
                     static_cast<unsigned>(addr));
        std::fflush(stderr);
        assert(0);
    }
    uint32_t a = static_cast<uint32_t>(addr);
    uint32_t v = 0;
    for (int i = 0; i < 4; i++) {
        size_t idx = static_cast<size_t>(a) + static_cast<size_t>(i);
        if (idx < g_flash.size())
            v |= static_cast<uint32_t>(g_flash[idx]) << (8 * i);
    }
    *data = static_cast<int32_t>(v);
}

int main(int argc, char **argv) {
    std::setvbuf(stdout, nullptr, _IONBF, 0);
    std::setvbuf(stderr, nullptr, _IONBF, 0);

    const char *image = "/home/william/YSYX/ysyx-workbench/ysyxSoC/ready-to-run/minirv/hello-minirv-ysyxsoc.bin";
    long max_cycles = 20000000;
    long cpu_soc_ratio = 1;
    for (int i = 1; i < argc; i++) {
        if (std::strcmp(argv[i], "+FLASH_ASSERT") == 0 || std::strcmp(argv[i], "--assert-flash") == 0) {
            g_assert_flash = true;
        } else if (std::strncmp(argv[i], "+MAX_CYCLES=", 12) == 0) {
            max_cycles = std::strtol(argv[i] + 12, nullptr, 0);
        } else if (std::strncmp(argv[i], "+K=", 3) == 0) {
            cpu_soc_ratio = std::strtol(argv[i] + 3, nullptr, 0);
            if (cpu_soc_ratio < 1) cpu_soc_ratio = 1;
        } else if (argv[i][0] != '+' && argv[i][0] != '-') {
            image = argv[i];
        }
    }

    std::ifstream f(image, std::ios::binary);
    if (!f) {
        std::fprintf(stderr, "[SoC] cannot open flash image: %s\n", image);
        return 1;
    }
    g_flash.assign(FLASH_SIZE, 0);
    f.read(reinterpret_cast<char *>(g_flash.data()), static_cast<std::streamsize>(FLASH_SIZE));
    g_flash_used = static_cast<size_t>(f.gcount());

    std::fprintf(stderr, "=== SoC simulation ===\n");
    std::fprintf(stderr, "image      : %s\n", image);
    std::fprintf(stderr, "image size : %zu bytes (flash model 16 MiB)\n", g_flash_used);
    std::fprintf(stderr, "mode       : %s\n",
                 g_assert_flash ? "flash_read assert (milestone)" : "boot");
    std::fprintf(stderr, "max cycles : %ld\n", max_cycles);
    std::fprintf(stderr, "cpu/soc    : %ldx\n", cpu_soc_ratio);
    std::fprintf(stderr, "note       : bootloader copies Flash -> PSRAM; Hello may take ~200M cycles\n");
    std::fprintf(stderr, "----------------------\n");
    std::fflush(stderr);

    VerilatedContext ctx;
    ctx.commandArgs(argc, argv);

    VSimTop top{&ctx};
    top.clock = 0;
    top.cpuClock = 0;
    top.reset = 1;
    top.coreSel = 0;
    top.externalPins_mygpio_in = 0;
    top.externalPins_uart0_rx = 1;

    long soc_phase = 0;
    auto tick = [&]() {
        top.cpuClock = 0;
        if (soc_phase == 0) top.clock = 0;
        top.eval();
        top.cpuClock = 1;
        if (soc_phase == 0) top.clock = 1;
        top.eval();
        if (++soc_phase >= cpu_soc_ratio) soc_phase = 0;
    };

    for (long i = 0; i < 200 * cpu_soc_ratio; i++)
        tick();

    top.reset = 0;
    std::fprintf(stderr, "[SoC] reset released, running...\n");
    std::fflush(stderr);

    long cycles = 0;
    while (cycles < max_cycles && !g_halt && !ctx.gotFinish()) {
        tick();
        cycles++;
        if (cycles % 10000000 == 0) {
            std::fprintf(stderr, "[SoC] %ldM cycles\n", cycles / 1000000);
            std::fflush(stderr);
        }
    }

    if (g_halt)
        std::fprintf(stderr, "[SoC] halted by ebreak/trap at %ld cycles\n", cycles);
    else
        std::fprintf(stderr, "[SoC] finished after %ld cycles (max cycles)\n", cycles);
    return 0;
}
