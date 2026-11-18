// npc_difftest.cpp —— RTL 与 minirvEMU 逐条对拍
//
// 每个 dbg_exec 拍让 EMU 执行同一条指令；执行前比 pc，执行后比 pc 与
// 16 个 GPR，结束时比 128 MiB 内存和停机原因。首次不一致打印现场并退出 1。
// 两边共享同一镜像、基址 0x80000000 与复位 PC。
// DIFFTEST PASS 只表示两边一致；程序成绩由 ebreak 时的 a0 决定。
//
// 运行：./Vminirv_top +BIN=<bin> [+STEPS=<n>] [+TRACE]

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <unistd.h>

#include "Vminirv_top.h"
#include "verilated.h"

#include "minirvEMU.h"
#include "pmem.h"
#include "Vminirv_top__Dpi.h"

static constexpr uint32_t UART_ADDR = 0x10000000u;
static constexpr uint32_t UART_STATUS_ADDR = 0x10000004u;

static Vminirv_top *top;
static Pmem g_pmem;
static const char *g_image = "";
static bool g_trace = false;

static bool g_dpi_halt = false;

static uint64_t g_mem_writes = 0;
static bool g_mem_error = false;
static uint32_t g_mem_error_addr = 0;
static bool g_mem_error_write = false;
static bool g_write_this_step = false;
static uint32_t g_last_write_addr = 0;
static uint32_t g_last_write_data = 0;
static uint8_t g_last_write_mask = 0;
static std::map<uint32_t, uint32_t> g_written_words;

static uint32_t g_inst = 0;
static uint32_t g_ref_inst = 0;
static bool g_ref_inst_valid = false;
static uint32_t g_pc_before_dut = 0;
static uint32_t g_pc_before_ref = 0;
static uint32_t g_pc_after_dut = 0;
static uint32_t g_pc_after_ref = 0;

static uint32_t dut_pc(void)
{
    return static_cast<uint32_t>(top->pc);
}

static uint32_t dut_gpr(int i)
{
    return static_cast<uint32_t>(top->dbg_gpr[i]);
}

// cpu.mem 是偏移数组，读之前先减基址
static uint32_t ref_read32(uint32_t addr)
{
    uint32_t off = (addr - MINIRV_MEM_BASE) & ~3u;
    uint32_t value = 0;
    for (int i = 3; i >= 0; i--)
        value = (value << 8) | cpu.mem[off + static_cast<uint32_t>(i)];
    return value;
}

// ebreak 的 DPI 回调
void npc_ebreak_halt(void)
{
    g_dpi_halt = true;
    Verilated::gotFinish(true);
}

// DPI-C：RTL 读内存
int pmem_read(int raddr)
{
    uint32_t addr = static_cast<uint32_t>(raddr);
    if (addr == UART_STATUS_ADDR) {
        uint32_t status = (std::rand() & 0x7) == 0 ? 1 : 0;
        minirv_set_uart_status(status);
        return static_cast<int>(status);
    }
    if (!g_pmem.has_byte(addr)) {
        g_mem_error = true;
        g_mem_error_addr = addr;
        g_mem_error_write = false;
        return 0;
    }
    return static_cast<int>(g_pmem.read32(addr));
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
    g_last_write_addr = addr;
    g_last_write_data = static_cast<uint32_t>(wdata);
    g_last_write_mask = mask;
    g_write_this_step = true;

    g_pmem.write(addr, static_cast<uint32_t>(wdata), mask);
    g_mem_writes++;
    g_written_words[addr & ~3u] = g_pmem.read32(addr);
}

static const char *inst_name(uint32_t inst)
{
    uint32_t opcode = inst & 0x7f;
    uint32_t funct3 = (inst >> 12) & 0x7;
    uint32_t funct7 = (inst >> 25) & 0x7f;

    switch (opcode) {
    case 0x33:
        return (funct3 == 0 && funct7 == 0) ? "add" : "illegal";
    case 0x13:
        return (funct3 == 0) ? "addi" : "illegal";
    case 0x37:
        return "lui";
    case 0x03:
        return (funct3 == 0x2) ? "lw" : (funct3 == 0x4) ? "lbu" : "illegal";
    case 0x23:
        return (funct3 == 0x2) ? "sw" : (funct3 == 0x0) ? "sb" : "illegal";
    case 0x67:
        return (funct3 == 0) ? "jalr" : "illegal";
    case 0x73:
        return (inst == 0x00100073u) ? "ebreak" : "illegal";
    default:
        return "illegal";
    }
}

static const char *dut_stop(void)
{
    if (top->dbg_halt)
        return "ebreak";
    if (top->dbg_trap)
        return "trap";
    return "running";
}

static const char *ref_stop(void)
{
    if (!cpu.halted)
        return "running";
    return (cpu.exit_code == 0) ? "ebreak" : "trap";
}

// 结束时整片比较；报错地址加回基址
static bool mem_compare(uint32_t *bad_addr, uint8_t *dut, uint8_t *ref)
{
    for (uint32_t i = 0; i < MINIRV_MEM_SIZE; i++) {
        if (g_pmem.mem[i] != cpu.mem[i]) {
            *bad_addr = MINIRV_MEM_BASE + i;
            *dut = g_pmem.mem[i];
            *ref = cpu.mem[i];
            return false;
        }
    }
    return true;
}

static void print_mem_compare(void)
{
    uint32_t bad = 0;
    uint8_t d = 0;
    uint8_t r = 0;

    if (mem_compare(&bad, &d, &r)) {
        std::printf("mem compare : ok (128 MiB)\n");
    } else {
        std::printf("mem compare : MISMATCH at 0x%08x dut=0x%02x ref=0x%02x\n",
                    static_cast<unsigned>(bad), d, r);
    }
}

static void print_gpr_table(void)
{
    std::printf("---------------- GPR ----------------\n");
    std::printf("reg   DUT          REF          match\n");
    for (int i = 0; i < 16; i++) {
        uint32_t d = dut_gpr(i);
        uint32_t r = static_cast<uint32_t>(cpu.gpr[i]);
        std::printf("x%-2d   0x%08x   0x%08x   %s\n",
                    i, d, r, (d == r) ? "ok" : "MISMATCH");
    }
}

static void print_gpr_compact(void)
{
    std::printf("---------------- GPR (DUT = REF) ----------------\n");
    for (int i = 0; i < 16; i++) {
        std::printf("x%-2d=0x%08x", i, dut_gpr(i));
        if (i % 4 == 3)
            std::printf("\n");
        else
            std::printf("  ");
    }
}

static void print_mem_changed(void)
{
    std::printf("---------------- MEM ----------------\n");
    if (g_written_words.empty()) {
        std::printf("(no writes)\n");
        return;
    }
    size_t shown = 0;
    for (const auto &kv : g_written_words) {
        if (shown == 64) {
            std::printf("... (%zu more)\n", g_written_words.size() - shown);
            break;
        }
        std::printf("mem[0x%08x] = 0x%08x\n",
                    static_cast<unsigned>(kv.first),
                    static_cast<unsigned>(kv.second));
        shown++;
    }
}

// 失败现场：定位、pc 轨迹、停机状态、内存与 GPR
static void report_fail(uint64_t step, const char *check)
{
    uart_color_reset();
    std::printf("\n================ DIFFTEST FAIL ================\n");
    std::printf("image       : %s\n", g_image);
    std::printf("step        : %llu\n", static_cast<unsigned long long>(step));
    std::printf("check       : %s\n", check);
    std::printf("instruction : 0x%08x  %s\n", g_inst, inst_name(g_inst));
    if (!g_ref_inst_valid) {
        std::printf("ref inst    : out of range at pc=0x%08x\n", g_pc_before_ref);
    } else if (g_ref_inst != g_inst) {
        std::printf("ref inst    : 0x%08x  %s  at pc=0x%08x\n",
                    g_ref_inst, inst_name(g_ref_inst), g_pc_before_ref);
    }
    std::printf("pc before   : dut=0x%08x  ref=0x%08x\n",
                g_pc_before_dut, g_pc_before_ref);
    std::printf("pc after    : dut=0x%08x  ref=0x%08x\n",
                g_pc_after_dut, g_pc_after_ref);
    std::printf("dut stop    : %s\n", dut_stop());
    std::printf("ref stop    : %s  exit_code=%d\n", ref_stop(), cpu.exit_code);
    std::printf("steps       : dut=%llu  ref=%llu\n",
                static_cast<unsigned long long>(step),
                static_cast<unsigned long long>(cpu.steps));
    std::printf("mem writes  : %llu\n",
                static_cast<unsigned long long>(g_mem_writes));
    print_mem_compare();
    std::printf("dpi finish  : %s\n", g_dpi_halt ? "yes" : "no");
    print_gpr_table();
    print_mem_changed();
    std::printf("================================================\n");
    std::exit(1);
}

// DPI 越界失败现场
static void report_abort(uint64_t step, const char *check, uint32_t pc,
                         uint32_t addr, bool has_addr)
{
    uart_color_reset();
    std::printf("\n================ DIFFTEST FAIL ================\n");
    std::printf("image       : %s\n", g_image);
    std::printf("step        : %llu\n", static_cast<unsigned long long>(step));
    std::printf("check       : %s\n", check);
    std::printf("pc          : 0x%08x\n", pc);
    if (has_addr)
        std::printf("addr        : 0x%08x\n", addr);
    std::printf("mem writes  : %llu\n",
                static_cast<unsigned long long>(g_mem_writes));
    print_mem_compare();
    print_gpr_table();
    print_mem_changed();
    std::printf("================================================\n");
    std::exit(1);
}

// +TRACE 的每步一行格式
static void print_trace(uint64_t step, const uint32_t before[16],
                        uint32_t pc_before, uint32_t inst)
{
    std::printf("[%4llu] pc=0x%08x -> 0x%08x  %-7s 0x%08x  |",
                static_cast<unsigned long long>(step), pc_before, dut_pc(),
                inst_name(inst), inst);

    bool first = true;

    for (int i = 0; i < 16; i++) {
        uint32_t now = dut_gpr(i);
        if (now != before[i]) {
            std::printf("%s x%02d: 0x%08x -> 0x%08x",
                        first ? "" : ";", i, before[i], now);
            first = false;
        }
    }

    if (g_write_this_step) {
        unsigned mask = static_cast<unsigned>(g_last_write_mask);
        std::printf("%s store[0x%08x] <= 0x%08x  be=%c%c%c%c",
                    first ? "" : ";", g_last_write_addr, g_last_write_data,
                    (mask & 8) ? '1' : '0', (mask & 4) ? '1' : '0',
                    (mask & 2) ? '1' : '0', (mask & 1) ? '1' : '0');
        first = false;
    }

    if (top->dbg_halt) {
        std::printf("%s halt", first ? "" : ";");
        first = false;
    }
    if (top->dbg_trap) {
        std::printf("%s trap", first ? "" : ";");
        first = false;
    }
    if (first)
        std::printf(" -");

    std::printf("\n");
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
        else if (std::strcmp(argv[i], "+TRACE") == 0)
            g_trace = true;
    }
    if (bin == nullptr) {
        std::fprintf(stderr, "usage: %s +BIN=<bin> [+STEPS=<n>] [+TRACE]\n",
                     argv[0]);
        return 1;
    }

    g_image = bin;

    g_pmem.reset();
    if (!g_pmem.load(bin))
        return 1;

    minirv_reset();
    if (minirv_load(bin) < 0)
        return 1;

    std::printf("================ DIFFTEST ================\n");
    std::printf("image       : %s\n", bin);
    std::printf("max steps   : %llu\n",
                static_cast<unsigned long long>(max_steps));
    std::printf("memory      : DPI-C pmem_read/pmem_write, 128 MiB @ 0x80000000\n");
    std::printf("trace       : %s\n", g_trace ? "on" : "off");
    std::printf("==========================================\n");

    Vminirv_top model{&context};
    top = &model;

    top->clk = 0;
    top->rst = 1;
    for (int i = 0; i < 2; i++) {
        top->clk = 0;
        top->eval();
        top->clk = 1;
        top->eval();
    }
    top->rst = 0;
    top->clk = 0;
    top->eval();

    // 复位期间 pc=0 的假读会置位错误，清除
    g_mem_error = false;

    // 逐拍对拍
    uint64_t steps = 0;
    while (steps < max_steps && !context.gotFinish()) {
        g_write_this_step = false;

        top->clk = 0;
        top->eval();

        if (g_mem_error) {
            report_abort(steps, g_mem_error_write ? "write out of range"
                                                  : "read out of range",
                         dut_pc(), g_mem_error_addr, true);
        }
        if (!g_pmem.has_word(top->pc)) {
            report_abort(steps, "fetch out of range", dut_pc(), 0, false);
        }

        g_pc_before_dut = dut_pc();
        g_pc_before_ref = static_cast<uint32_t>(cpu.pc);
        g_pc_after_dut = g_pc_before_dut;
        g_pc_after_ref = g_pc_before_ref;

        g_inst = g_pmem.read32(top->pc);
        g_ref_inst_valid = (cpu.pc >= MINIRV_MEM_BASE &&
                            cpu.pc - MINIRV_MEM_BASE <= MINIRV_MEM_SIZE - 4);
        g_ref_inst = g_ref_inst_valid ? ref_read32(cpu.pc) : 0;

        uint32_t gpr_before[16];
        for (int i = 0; i < 16; i++)
            gpr_before[i] = dut_gpr(i);

        if (top->dbg_exec) {
            if (g_pc_before_dut != g_pc_before_ref)
                report_fail(steps, "pc before exec");
            minirv_exec_once();
        }

        top->clk = 1;
        top->eval();

        g_pc_after_dut = dut_pc();
        g_pc_after_ref = static_cast<uint32_t>(cpu.pc);

        if (g_mem_error) {
            report_abort(steps, g_mem_error_write ? "write out of range"
                                                  : "read out of range",
                         dut_pc(), g_mem_error_addr, true);
        }

        if (top->dbg_exec) {
            steps++;
            if (g_pc_after_dut != g_pc_after_ref)
                report_fail(steps, "pc after exec");
            for (int i = 0; i < 16; i++) {
                if (dut_gpr(i) != cpu.gpr[i]) {
                    char what[32];
                    std::snprintf(what, sizeof(what), "x%d after exec", i);
                    report_fail(steps, what);
                }
            }
            if (g_trace)
                print_trace(steps, gpr_before, g_pc_before_dut, g_inst);
        }

        if (top->dbg_halt && !g_dpi_halt)
            report_fail(steps, "ebreak did not notify DPI-C");

        if (top->dbg_halt || top->dbg_trap) {
            if (!cpu.halted)
                report_fail(steps, "dut stopped, ref still running");
            if (top->dbg_halt && cpu.exit_code != 0)
                report_fail(steps, "dut halted by ebreak, ref exited with error");
            if (top->dbg_trap && cpu.exit_code == 0)
                report_fail(steps, "dut trapped, ref halted normally");
            break;
        }
    }

    uint32_t bad = 0;
    uint8_t dut_byte = 0;
    uint8_t ref_byte = 0;
    if (!mem_compare(&bad, &dut_byte, &ref_byte))
        report_fail(steps, "memory compare");

    const char *reason = top->dbg_halt ? "ebreak"
                       : top->dbg_trap ? "trap"
                       : "step limit";

    std::printf("\n================ DIFFTEST PASS ================\n");
    std::printf("image       : %s\n", g_image);
    std::printf("steps       : dut=%llu  ref=%llu\n",
                static_cast<unsigned long long>(steps),
                static_cast<unsigned long long>(cpu.steps));
    std::printf("stop        : %s\n", reason);
    std::printf("final pc    : dut=0x%08x  ref=0x%08x\n",
                dut_pc(), static_cast<uint32_t>(cpu.pc));
    std::printf("ref exit    : %d\n", cpu.exit_code);
    std::printf("a0          : 0x%08x\n", dut_gpr(10));
    std::printf("mem writes  : %llu\n",
                static_cast<unsigned long long>(g_mem_writes));
    print_mem_compare();
    std::printf("dpi finish  : %s\n", g_dpi_halt ? "yes" : "no");
    print_gpr_compact();
    print_mem_changed();
    // DIFFTEST PASS 只表示一致，成绩看 a0
    if (g_dpi_halt)
        std::printf("%s\n", dut_gpr(10) == 0 ? "HIT GOOD TRAP" : "HIT BAD TRAP");
    std::printf("================================================\n");

    // 只有 ebreak 且 a0=0 才算成功
    if (top->dbg_trap)
        return 1;
    if (g_dpi_halt && dut_gpr(10) == 0)
        return 0;
    return 1;
}
