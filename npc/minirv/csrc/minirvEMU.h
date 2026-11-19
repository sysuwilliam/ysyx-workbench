#ifndef MINIRVEMU_H
#define MINIRVEMU_H

#include <stdint.h>

/*
 * minirvEMU —— minirv 指令集参考模型的框架
 *
 * 本文件只声明体系结构状态与对外接口，不含任何指令语义。
 * 指令的译码与执行集中在 minirvEMU.cpp 的 minirv_decode_exec 中。
 */

#define MINIRV_XLEN      32          // 机器字宽度（位），minirv 固定为 RV32
#define MINIRV_NR_REGS   16          // GPR 数量，取 RV32E 的 x0..x15
#define MINIRV_UART_ADDR 0x10000000u // UART 数据寄存器
#define MINIRV_UART_STATUS_ADDR (MINIRV_UART_ADDR + 4u) // UART 状态寄存器
#define MINIRV_TIMER_LO_ADDR 0x20000000u // 时钟低 32 位
#define MINIRV_TIMER_HI_ADDR 0x20000004u // 时钟高 32 位
#define MINIRV_MEM_BASE  0x80000000u // 内存基址
#define MINIRV_MEM_SIZE  (128u * 1024 * 1024) // 内存容量（字节），128 MiB
#define MINIRV_RESET_PC  MINIRV_MEM_BASE // 复位后的 PC

// 无符号机器字：地址、寄存器值、取出的指令
typedef uint32_t word_t;

// 有符号机器字：符号扩展、有符号比较、算术右移等场合
typedef int32_t  sword_t;

static_assert(MINIRV_XLEN == 32, "minirv requires RV32");
static_assert(sizeof(word_t) * 8 == MINIRV_XLEN, "word_t must match MINIRV_XLEN");
static_assert(sizeof(sword_t) * 8 == MINIRV_XLEN, "sword_t must match MINIRV_XLEN");

/*
 * 体系结构状态
 *
 *   pc      当前指令地址，按字节寻址，复位值见 MINIRV_RESET_PC
 *   gpr     通用寄存器 x0..x15；x0 的读恒零、写丢弃属于译码阶段要实现
 *   mem     按字节寻址的内存，指令与数据共用同一空间；
 *           下标是 addr - MINIRV_MEM_BASE
 *   halted  非零表示已停机，由译码函数在满足停机条件时置位
 *   exit_code 结束码：0 表示正常停止，非零表示非法指令或访存越界等错误
 *   steps   已执行指令条数，用于步数上限与运行日志
 */
struct minirv_state {
    word_t   pc;
    word_t   gpr[MINIRV_NR_REGS];
    uint8_t  mem[MINIRV_MEM_SIZE];
    int      halted;
    int      exit_code;
    uint64_t steps;
};

// 全局唯一的处理器状态，定义在 minirvEMU.cpp
extern struct minirv_state cpu;

// 把全部状态清零，并把 pc 置为 MINIRV_RESET_PC
void minirv_reset(void);

// 由 DiffTest 注入 UART 状态，保证同一条 load 两边读到相同的值
void minirv_set_uart_status(word_t status);

// 由 DiffTest 注入时钟值，保证同一条 load 两边读到相同的值
void minirv_set_clock(uint64_t us);

// 把裸二进制镜像读入内存偏移 0（对应基址 0x80000000），成功返回字节数，失败返回 -1
int minirv_load(const char *path);

// 从内存 addr 处取出 32 位指令（小端），越界时置 halted 并返回 0
word_t minirv_fetch(word_t addr);

// 执行一条指令：取指、调用译码执行、步数加一
// 返回 0 表示继续，1 表示执行后已停机，-1 表示取指失败
int minirv_exec_once(void);

// 循环执行直到停机或达到 max_steps
// 返回 exit_code：正常停止（含撞步数上限）为 0，非法指令等错误为非零
int minirv_run(uint64_t max_steps);

// 打印 pc、步数与 16 个通用寄存器
void minirv_dump(void);

#endif
