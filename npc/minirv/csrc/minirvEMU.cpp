#include "minirvEMU.h"

#include <stdio.h>
#include <string.h>

/*
 * minirvEMU.cpp —— 最小 RISC-V 处理器的指令集模型
 *
 * 外围已实现：状态管理、镜像加载、取指、执行循环与打印。
 * ISA 核心在 minirv_decode_exec：minirv 八条指令与 ebreak 停机约定已全部实现。
 * 其余指令按同样结构补 case。
 */

#define OP_LOAD    0b0000011
#define OP_STORE   0b0100011
#define OP_IMM     0b0010011
#define OP_REG     0b0110011
#define OP_LUI     0b0110111
#define OP_JALR    0b1100111
#define OP_SYSTEM  0b1110011

#define F3_LW      0b010
#define F3_LBU     0b100
#define F3_SW      0b010
#define F3_SB      0b000
#define F3_ADDI    0b000
#define F3_ADD     0b000
#define F3_JALR    0b000

#define F7_ADD     0b0000000

#define MASK_IMM12       0b00000000000000000000111111111111u
#define MASK_IMM12_SIGN  0b00000000000000000000100000000000u
#define MASK_UPPER20     0b11111111111111111111000000000000u

#define INSN_EBREAK      0b00000000000100000000000001110011u

// 全局处理器状态，头文件里以 extern 声明
struct minirv_state cpu;

static word_t g_uart_status = 0;

void minirv_set_uart_status(word_t status)
{
    g_uart_status = status;
}

// 复位：清空内存与寄存器，pc 回到 MINIRV_RESET_PC
void minirv_reset(void)
{
    memset(&cpu, 0, sizeof(cpu));
    cpu.pc = MINIRV_RESET_PC;
    g_uart_status = 0;
}

/*
 * 加载镜像
 *
 * 读入的是裸二进制，不做 ELF 解析，也不区分代码段与数据段，
 * 内容从内存偏移 0 开始放置，对应基址 0x80000000，与 minirv 的 pc 初值一致。
 * 先定位到文件末尾取得长度，超过内存容量直接报错，
 * 这样「文件恰好装满内存」和「文件略大」能被区分开。
 * 读取失败、超容量、短读时返回 -1；成功时返回读入的字节数。
 */
int minirv_load(const char *path)
{
    FILE *fp = fopen(path, "rb");
    if (fp == NULL) {
        fprintf(stderr, "minirv: cannot open %s\n", path);
        return -1;
    }

    if (fseek(fp, 0, SEEK_END) != 0) {
        fprintf(stderr, "minirv: cannot seek %s\n", path);
        fclose(fp);
        return -1;
    }

    long len = ftell(fp);
    if (len < 0) {
        fprintf(stderr, "minirv: cannot tell size of %s\n", path);
        fclose(fp);
        return -1;
    }

    if ((unsigned long)len > sizeof(cpu.mem)) {
        fprintf(stderr, "minirv: image larger than memory\n");
        fclose(fp);
        return -1;
    }

    if (fseek(fp, 0, SEEK_SET) != 0) {
        fprintf(stderr, "minirv: cannot seek %s\n", path);
        fclose(fp);
        return -1;
    }

    // 按字节读，返回值即字节数；读到的长度应与 ftell 的结果一致
    size_t n = fread(cpu.mem, 1, sizeof(cpu.mem), fp);
    if (ferror(fp)) {
        fprintf(stderr, "minirv: read error on %s\n", path);
        fclose(fp);
        return -1;
    }
    if (n != (size_t)len) {
        fprintf(stderr, "minirv: short read on %s\n", path);
        fclose(fp);
        return -1;
    }

    fclose(fp);
    printf("minirv: loaded %zu bytes from %s\n", n, path);
    return (int)n;
}

/*
 * 从内存读 32 位（小端）
 *
 * mem[addr] 是最低字节，mem[addr + 3] 是最高字节。
 * 越界返回 -1，成功返回 0；取指与 lw 共用这一处拼装逻辑。
 */
static int mem_read32(word_t addr, word_t *val)
{
    if (addr == MINIRV_UART_STATUS_ADDR) {
        *val = g_uart_status;
        return 0;
    }
    if (addr < MINIRV_MEM_BASE || addr - MINIRV_MEM_BASE > MINIRV_MEM_SIZE - 4) {
        return -1;
    }

    word_t off = addr - MINIRV_MEM_BASE;
    word_t v = 0;
    for (int i = 3; i >= 0; i--) {
        v = (v << 8) | cpu.mem[off + (word_t)i];
    }
    *val = v;
    return 0;
}

/*
 * 取指
 *
 * 越界时不返回部分数据，而是置 halted 并返回 0，
 * 保证执行循环能停下来。
 */
word_t minirv_fetch(word_t addr)
{
    word_t inst = 0;
    if (mem_read32(addr, &inst) < 0) {
        fprintf(stderr, "minirv: fetch out of range at %08x\n", addr);
        cpu.halted = 1;
        cpu.exit_code = 1;
        return 0;
    }
    return inst;
}

/*
 * 向内存写 32 位（小端）
 *
 * 越界返回 -1，成功返回 0；与 mem_read32 的边界条件一致。
 */
static int mem_write32(word_t addr, word_t val)
{
    if (addr == MINIRV_UART_ADDR) {
        return 0;
    }
    if (addr < MINIRV_MEM_BASE || addr - MINIRV_MEM_BASE > MINIRV_MEM_SIZE - 4) {
        return -1;
    }

    word_t off = addr - MINIRV_MEM_BASE;
    for (int i = 0; i < 4; i++) {
        cpu.mem[off + (word_t)i] = (uint8_t)(val >> (8 * i));
    }
    return 0;
}

/*
 * 向内存写 8 位
 *
 * 只保留 val 的低 8 位，不做符号扩展；单字节没有对齐要求。
 */
static int mem_write8(word_t addr, word_t val)
{
    if (addr == MINIRV_UART_ADDR) {
        return 0;
    }
    if (addr < MINIRV_MEM_BASE || addr - MINIRV_MEM_BASE >= MINIRV_MEM_SIZE) {
        return -1;
    }
    cpu.mem[addr - MINIRV_MEM_BASE] = (uint8_t)(val & 0xffu);
    return 0;
}

/*
 * 从内存读 8 位（零扩展）
 *
 * 单字节没有对齐要求，只需检查地址是否在内存范围内。
 * uint8_t 赋给 word_t 时自动零扩展。
 */
static int mem_read8(word_t addr, word_t *val)
{
    if (addr == MINIRV_UART_STATUS_ADDR) {
        *val = g_uart_status & 0xffu;
        return 0;
    }
    if (addr < MINIRV_MEM_BASE || addr - MINIRV_MEM_BASE >= MINIRV_MEM_SIZE) {
        return -1;
    }
    *val = cpu.mem[addr - MINIRV_MEM_BASE];
    return 0;
}

/*
 * 通用寄存器读写
 *
 * x0 是常量零：读它永远得到 0，写它直接丢弃。
 * 其余索引由调用方用 reg_ok 检查是否落在 x0..x15 范围内。
 */
static word_t gpr_read(word_t idx)
{
    return idx == 0 ? 0u : cpu.gpr[idx];
}

static void gpr_write(word_t idx, word_t val)
{
    if (idx != 0) {
        cpu.gpr[idx] = val;
    }
}

static int reg_ok(word_t idx)
{
    return idx < MINIRV_NR_REGS;
}

/*
 * 出错停机
 *
 * 非法指令、未对齐访问、越界访问都走这里：置停机并记错误退出码，
 * 调用方负责先打印具体的现场信息。
 */
static void minirv_fail(void)
{
    cpu.halted = 1;
    cpu.exit_code = 1;
}

/*
 * 非法指令
 *
 * 打印现场后停机：pc 指向出问题的指令，inst 是它的编码。
 */
static void minirv_illegal(word_t inst)
{
    fprintf(stderr, "minirv: illegal instruction pc=%08x inst=%08x\n",
            cpu.pc, inst);
    minirv_fail();
}

/*
 * 译码与执行
 *
 * 流程：先切出在基本格式中位置固定的公共字段，
 * 再按 opcode 分派，需要区分的指令族在 case 内看 funct3。
 * 下一条 pc 先默认加 4，跳转类指令在 case 内改写 next_pc。
 * 未实现的 opcode、funct3 不匹配、寄存器字段越界，都按非法指令停机。
 *
 * 目前实现 addi、add、lui、lw、jalr 与 ebreak；其余按同样结构补 case。
 * ebreak 在本模拟器中被约定为「程序正常结束」，执行后打印提示并停机。
 */
static void minirv_decode_exec(word_t inst)
{
    // opcode 与寄存器字段在 RISC-V 各格式中位置固定，先统一切出
    word_t opcode = inst & 0x7f;
    word_t rd     = (inst >> 7) & 0x1f;
    word_t funct3 = (inst >> 12) & 0x7;
    word_t rs1    = (inst >> 15) & 0x1f;
    word_t rs2    = (inst >> 20) & 0x1f;
    word_t funct7 = (inst >> 25) & 0x7f;

    // I 型立即数：12 位补码，符号位在 bit11，扩展到 32 位后才能参与运算
    word_t imm_i = inst >> 20;
    if (imm_i & MASK_IMM12_SIGN) {
        imm_i |= MASK_UPPER20;
    }

    // S 型立即数：imm[11:5] 在 bit31:25，imm[4:0] 在 bit11:7，拼接后符号扩展
    word_t imm_s = ((inst >> 25) << 5) | ((inst >> 7) & 0x1f);
    if (imm_s & MASK_IMM12_SIGN) {
        imm_s |= MASK_UPPER20;
    }

    // 顺序执行的下一条地址；jalr 等指令在 case 内覆盖它
    word_t next_pc = cpu.pc + 4;

    switch (opcode) {

    case OP_LOAD: {
        // 目前实现 lw 与 lbu，其余 load 编码按非法处理
        if (funct3 != F3_LW && funct3 != F3_LBU) {
            minirv_illegal(inst);
            return;
        }
        if (!reg_ok(rd) || !reg_ok(rs1)) {
            minirv_illegal(inst);
            return;
        }

        word_t addr = gpr_read(rs1) + imm_i;
        word_t val = 0;
        int rc;

        if (funct3 == F3_LW) {
            if ((addr & 3u) != 0) {
                fprintf(stderr,
                        "minirv: misaligned load address pc=%08x addr=%08x inst=%08x\n",
                        cpu.pc, addr, inst);
                minirv_fail();
                return;
            }
            rc = mem_read32(addr, &val);
        } else if (funct3 == F3_LBU) {
            rc = mem_read8(addr, &val);
        }

        if (rc < 0) {
            fprintf(stderr,
                    "minirv: load out of range pc=%08x addr=%08x inst=%08x\n",
                    cpu.pc, addr, inst);
            minirv_fail();
            return;
        }

        gpr_write(rd, val);
        break;
    }

    case OP_STORE: {
        // 目前实现 sw 与 sb，其余 store 编码按非法处理
        if (funct3 != F3_SW && funct3 != F3_SB) {
            minirv_illegal(inst);
            return;
        }
        if (!reg_ok(rs1) || !reg_ok(rs2)) {
            minirv_illegal(inst);
            return;
        }

        word_t addr = gpr_read(rs1) + imm_s;
        word_t data = gpr_read(rs2);
        int rc;

        if (funct3 == F3_SW) {
            if ((addr & 3u) != 0) {
                fprintf(stderr,
                        "minirv: misaligned store address pc=%08x addr=%08x inst=%08x\n",
                        cpu.pc, addr, inst);
                minirv_fail();
                return;
            }
            rc = mem_write32(addr, data);
        } else {
            rc = mem_write8(addr, data);
        }

        if (rc < 0) {
            fprintf(stderr,
                    "minirv: store out of range pc=%08x addr=%08x inst=%08x\n",
                    cpu.pc, addr, inst);
            minirv_fail();
            return;
        }
        break;
    }

    case OP_IMM: {
        // OP-IMM 族：addi、slti、xori、slli 等共用该 opcode，靠 funct3 区分
        if (funct3 != F3_ADDI) {
            minirv_illegal(inst);
            return;
        }
        if (!reg_ok(rd) || !reg_ok(rs1)) {
            minirv_illegal(inst);
            return;
        }
        gpr_write(rd, gpr_read(rs1) + imm_i);
        break;
    }

    case OP_REG: {
        // OP 族：add、sub、sll 等共用该 opcode，靠 funct3 与 funct7 共同区分
        if (funct3 != F3_ADD || funct7 != F7_ADD) {
            minirv_illegal(inst);
            return;
        }
        if (!reg_ok(rd) || !reg_ok(rs1) || !reg_ok(rs2)) {
            minirv_illegal(inst);
            return;
        }
        gpr_write(rd, gpr_read(rs1) + gpr_read(rs2));
        break;
    }

    case OP_LUI: {
        // U 型没有 funct3，bits 14:12 属于立即数
        if (!reg_ok(rd)) {
            minirv_illegal(inst);
            return;
        }
        gpr_write(rd, inst & MASK_UPPER20);
        break;
    }

    case OP_JALR: {
        // JALR：I 型，funct3 必须为 0；目标最低位清零，rd 存 pc+4
        if (funct3 != F3_JALR) {
            minirv_illegal(inst);
            return;
        }
        if (!reg_ok(rd) || !reg_ok(rs1)) {
            minirv_illegal(inst);
            return;
        }

        // 先读旧的 rs1 再写 rd，保证 jalr ra, 0(ra) 这类指令正确
        word_t base = gpr_read(rs1);
        word_t target = (base + imm_i) & ~1u;

        // 基础 ISA 要求目标按 4 字节对齐；未对齐时不退休，rd 保持原值
        if ((target & 3u) != 0) {
            fprintf(stderr,
                    "minirv: misaligned jump target pc=%08x target=%08x inst=%08x\n",
                    cpu.pc, target, inst);
            minirv_fail();
            return;
        }

        gpr_write(rd, cpu.pc + 4);
        next_pc = target;
        break;
    }

    case OP_SYSTEM: {
        // SYSTEM：本模拟器只约定 ebreak 表示程序结束，其余 SYSTEM 编码按非法处理
        if (inst == INSN_EBREAK) {
            printf("minirv: program halted by ebreak at pc=0x%08x\n", cpu.pc);
            cpu.halted = 1;
            return;
        }
        minirv_illegal(inst);
        return;
    }

    default:
        minirv_illegal(inst);
        return;
    }

    cpu.pc = next_pc;
}

/*
 * 执行一条指令
 *
 * 顺序是：先按当前 pc 取指，再交给译码函数，最后把步数加一。
 * 取指失败（地址越界）时 fetch 已经把 halted 置位，这里直接返回 -1。
 * 译码函数可能在执行后置 halted，因此返回 1 表示「刚执行完并停机」。
 */
int minirv_exec_once(void)
{
    word_t inst = minirv_fetch(cpu.pc);
    if (cpu.halted) {
        return -1;
    }

    minirv_decode_exec(inst);
    cpu.steps++;
    return cpu.halted ? 1 : 0;
}

/*
 * 主执行循环
 *
 * max_steps 是保险丝：程序若因死循环没有停机，也能在有限步内退出。
 * 撞到步数上限视为正常停止，返回 0；只有非法指令、未对齐访问、
 * 越界访问这类错误才通过 exit_code 返回非零。
 */
int minirv_run(uint64_t max_steps)
{
    while (!cpu.halted && cpu.steps < max_steps) {
        minirv_exec_once();
    }

    if (!cpu.halted) {
        printf("minirv: stopped after %llu steps, pc=%08x\n",
               (unsigned long long)cpu.steps, cpu.pc);
    }
    return cpu.exit_code;
}

// 打印 pc、步数与全部通用寄存器，便于人工核对执行结果
void minirv_dump(void)
{
    printf("pc  = 0x%08x\n", cpu.pc);
    printf("steps = %llu\n", (unsigned long long)cpu.steps);
    for (int i = 0; i < MINIRV_NR_REGS; i++) {
        printf("x%-2d = 0x%08x\n", i, cpu.gpr[i]);
    }
}
