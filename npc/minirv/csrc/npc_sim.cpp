// npc_sim.cpp —— minirv RTL 的独立仿真入口
//
// 存储器放在 C++ 里（见 pmem.h），RTL 通过 DPI-C 访问：
//   pmem_read(raddr)                返回 raddr & ~3 处的对齐字
//   pmem_write(waddr, wdata, wmask) 把 wdata 按字节掩码写入对齐字
//   取指与数据读都走 pmem_read，store 在时钟沿走 pmem_write。
//
// 顶层端口（模块名 minirv_top，可用 make RTL_TOP=... 覆盖）
//   input  clk              时钟，本文件手动翻转
//   input  rst              同步复位，高有效
//   output [31:0] pc        当前指令地址
//   output [511:0] dbg_gpr  gpr[i] 位于 dbg_gpr[i*32 +: 32]
//   output        dbg_exec  本拍处理了一条指令
//   output        dbg_halt  ebreak 造成的停机，时钟沿后有效
//   output        dbg_trap  非法指令、未对齐造成的停机，时钟沿后有效
//
// 一拍之内的顺序
//   1. clk=0; eval()         组合逻辑求值，取指与数据读在这里发生
//   2. clk=1; eval()         上升沿提交，store 在这里通过 pmem_write 落盘
//   3. 检查 dbg_trap / dbg_halt 与 DPI 的 gotFinish
//
// 运行
//   ./Vminirv_top +BIN=tests/prog-all.bin [+STEPS=n]

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>

#include "Vminirv_top.h"
#include "verilated.h"

#include "pmem.h"
#include "Vminirv_top__Dpi.h"

static Pmem g_pmem;
static bool g_dpi_halt = false;
static bool g_mem_error = false;
static uint32_t g_mem_error_addr = 0;
static bool g_mem_error_write = false;
static uint64_t g_mem_writes = 0;
static std::map<uint32_t, uint32_t> g_written_words;

static void tick(Vminirv_top &top)
{
    top.clk = 0;
    top.eval();
    top.clk = 1;
    top.eval();
}

static uint32_t gpr_of(const Vminirv_top &top, int i)
{
    return static_cast<uint32_t>(top.dbg_gpr[i]);
}

void npc_ebreak_halt(void)
{
    g_dpi_halt = true;
    Verilated::gotFinish(true);
}

int pmem_read(int raddr)
{
    uint32_t addr = static_cast<uint32_t>(raddr);
    if (!g_pmem.has_byte(addr)) {
        g_mem_error = true;
        g_mem_error_addr = addr;
        g_mem_error_write = false;
        return 0;
    }
    return static_cast<int>(g_pmem.read32(addr));
}

void pmem_write(int waddr, int wdata, char wmask)
{
    uint32_t addr = static_cast<uint32_t>(waddr);
    if (!g_pmem.has_byte(addr)) {
        g_mem_error = true;
        g_mem_error_addr = addr;
        g_mem_error_write = true;
        return;
    }

    uint8_t mask = static_cast<uint8_t>(wmask);
    g_pmem.write(addr, static_cast<uint32_t>(wdata), mask);
    g_mem_writes++;
    g_written_words[addr & ~3u] = g_pmem.read32(addr);
}

static void report_mem_error(void)
{
    std::printf("FAIL: %s out of range at addr=0x%08x\n",
                g_mem_error_write ? "write" : "read",
                static_cast<unsigned>(g_mem_error_addr));
}

int main(int argc, char **argv)
{
    VerilatedContext context;
    context.commandArgs(argc, argv);

    const char *bin = nullptr;
    uint64_t max_steps = 100000;
    for (int i = 1; i < argc; i++) {
        if (std::strncmp(argv[i], "+BIN=", 5) == 0)
            bin = argv[i] + 5;
        else if (std::strncmp(argv[i], "+STEPS=", 7) == 0)
            max_steps = std::strtoull(argv[i] + 7, nullptr, 0);
    }
    if (bin == nullptr) {
        std::fprintf(stderr, "usage: %s +BIN=<bin> [+STEPS=<n>]\n", argv[0]);
        return 1;
    }

    g_pmem.reset();
    if (!g_pmem.load(bin))
        return 1;

    Vminirv_top top{&context};

    top.clk = 0;
    top.rst = 1;
    tick(top);
    tick(top);
    top.rst = 0;
    top.clk = 0;
    top.eval();

    uint64_t steps = 0;
    while (steps < max_steps && !context.gotFinish()) {
        top.clk = 0;
        top.eval();

        if (g_mem_error) {
            report_mem_error();
            return 1;
        }
        if (!g_pmem.has_word(top.pc)) {
            std::printf("FAIL: fetch out of range at pc=0x%08x\n",
                        static_cast<unsigned>(top.pc));
            return 1;
        }

        top.clk = 1;
        top.eval();

        if (g_mem_error) {
            report_mem_error();
            return 1;
        }
        if (top.dbg_exec)
            steps++;
        if (top.dbg_trap || (top.dbg_halt && !g_dpi_halt))
            break;
    }

    const char *reason = g_dpi_halt ? "ebreak (DPI)"
                       : top.dbg_trap ? "trap"
                       : "step limit";
    if (top.dbg_halt && !g_dpi_halt)
        std::printf("WARNING: ebreak did not trigger DPI-C finish\n");
    std::printf("minirv-rtl: stopped by %s at pc=0x%08x after %llu steps\n",
                reason, static_cast<unsigned>(top.pc),
                static_cast<unsigned long long>(steps));
    for (int i = 0; i < 16; i++)
        std::printf("  x%-2d = 0x%08x\n", i, gpr_of(top, i));
    std::printf("mem writes = %llu\n",
                static_cast<unsigned long long>(g_mem_writes));
    if (g_written_words.empty())
        std::printf("  (no writes)\n");
    for (const auto &kv : g_written_words)
        std::printf("  mem[0x%08x] = 0x%08x\n",
                    static_cast<unsigned>(kv.first),
                    static_cast<unsigned>(kv.second));

    return top.dbg_trap ? 1 : 0;
}
