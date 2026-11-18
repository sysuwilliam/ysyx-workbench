// npc_sim.cpp —— minirv RTL 的独立仿真入口（测试台）
//
// 负责装载镜像、翻转时钟、提供 DPI-C 访存、统计步数与停机原因。
// 一拍：clk=0 eval（组合取指/读） -> clk=1 eval（提交 PC/GPR/store）。
// ebreak 通过 DPI 结束仿真；a0=0 打印 HIT GOOD TRAP，否则 HIT BAD TRAP。
//
// 运行：./Vminirv_top +BIN=<bin> [+STEPS=<n>]

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <unistd.h>

#include "Vminirv_top.h"
#include "verilated.h"

#include "pmem.h"
#include "Vminirv_top__Dpi.h"

static Pmem g_pmem;

static constexpr uint32_t UART_ADDR = 0x10000000u;
static constexpr uint32_t UART_STATUS_ADDR = 0x10000004u;

static bool g_dpi_halt = false;

// DPI 访存错误：发生、地址、读/写
static bool g_mem_error = false;
static uint32_t g_mem_error_addr = 0;
static bool g_mem_error_write = false;

// store 统计与写过的对齐字
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

// ebreak 的 DPI 回调
void npc_ebreak_halt(void)
{
    g_dpi_halt = true;
    Verilated::gotFinish(true);
}

// UART 字符用青色显示；stderr 不是终端时保持纯文本
static bool g_uart_color = false;

static void uart_color_reset(void)
{
    if (g_uart_color) {
        std::fputs("\033[0m", stderr);
        g_uart_color = false;
    }
}

static void uart_putc(int ch)
{
    bool tty = isatty(fileno(stderr)) != 0;
    if (tty && !g_uart_color) {
        std::fputs("\033[1;36m", stderr);
        g_uart_color = true;
    }
    std::fputc(ch, stderr);
    if (tty && ch == '\n')
        uart_color_reset();
}

// DPI-C：RTL 读内存
int pmem_read(int raddr)
{
    uint32_t addr = static_cast<uint32_t>(raddr);
    if (addr == UART_STATUS_ADDR)
        return (std::rand() & 0x7) == 0 ? 1 : 0;
    if (!g_pmem.has_byte(addr)) {
        g_mem_error = true;
        g_mem_error_addr = addr;
        g_mem_error_write = false;
        return 0;
    }
    return static_cast<int>(g_pmem.read32(addr));
}

// DPI-C：RTL 写内存
void pmem_write(int waddr, int wdata, char wmask)
{
    uint32_t addr = static_cast<uint32_t>(waddr);
    if (addr == UART_ADDR) {
        uart_putc(wdata & 0xff);
        return;
    }
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
    uart_color_reset();
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

    // 上电前装载镜像
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
    // 复位期间 pc=0 的假读会置位错误，清除
    g_mem_error = false;

    // 主循环：每拍处理一条指令
    uint64_t steps = 0;
    while (steps < max_steps && !context.gotFinish()) {
        top.clk = 0;
        top.eval();

        if (g_mem_error) {
            report_mem_error();
            return 1;
        }
        if (!g_pmem.has_word(top.pc)) {
            uart_color_reset();
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

    uart_color_reset();
    const char *reason = g_dpi_halt ? "ebreak (DPI)"
                       : top.dbg_trap ? "trap"
                       : "step limit";
    if (top.dbg_halt && !g_dpi_halt)
        std::printf("WARNING: ebreak did not trigger DPI-C finish\n");
    std::printf("minirv-rtl: stopped by %s at pc=0x%08x after %llu steps\n",
                reason, static_cast<unsigned>(top.pc),
                static_cast<unsigned long long>(steps));

    // a0 是程序写下的结束状态
    if (g_dpi_halt)
        std::printf("%s\n", gpr_of(top, 10) == 0 ? "HIT GOOD TRAP" : "HIT BAD TRAP");

    for (int i = 0; i < 16; i++)
        std::printf("  x%-2d = 0x%08x\n", i, gpr_of(top, i));

    std::printf("mem writes = %llu\n",
                static_cast<unsigned long long>(g_mem_writes));
    if (g_written_words.empty())
        std::printf("  (no writes)\n");
    size_t shown = 0;
    for (const auto &kv : g_written_words) {
        if (shown == 64) {
            std::printf("  ... (%zu more)\n", g_written_words.size() - shown);
            break;
        }
        std::printf("  mem[0x%08x] = 0x%08x\n",
                    static_cast<unsigned>(kv.first),
                    static_cast<unsigned>(kv.second));
        shown++;
    }

    // 只有 ebreak 且 a0=0 才算成功
    if (top.dbg_trap)
        return 1;
    if (g_dpi_halt)
        return gpr_of(top, 10) == 0 ? 0 : 1;
    return 1;
}
