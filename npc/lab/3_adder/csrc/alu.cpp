// ALU 的 testbench —— 位宽由编译期宏 WIDTH 决定（默认 4），与 RTL 的 parameter WIDTH 一致
//
//   make            -> 4 位 ALU
//   make W=8        -> 8 位 ALU
//
// 策略：WIDTH <= 8 时穷举 (8 功能 × 2^W × 2^W)，更大的位宽改用定向用例 + 随机。
//
// 参考模型按题意独立写：
//   000 加法 / 001 减法：用 WIDTH+1 位算完，最高位是进位，符号位判溢出
//   010~101 逻辑运算  ：进位与溢出恒 0
//   110 有符号比较     ：两个操作数都按补码解释成 -2^(W-1)..2^(W-1)-1 再比
//   111 相等判断
//   zero 对所有运算统一定义为「out 全 0」
#include <cstdio>
#include <cstdint>
#include "VALU.h"
#include "verilated.h"

#ifndef WIDTH
#define WIDTH 4
#endif
static_assert(WIDTH >= 2 && WIDTH <= 32, "参考模型用 uint32_t，WIDTH 限定在 2..32");

static const uint32_t MASK = (WIDTH >= 32) ? 0xFFFFFFFFu : ((1u << WIDTH) - 1u);
static const uint32_t SIGN = 1u << (WIDTH - 1);
static const int      BITS = WIDTH;

static VALU dut;
static int checks = 0, errors = 0;

// WIDTH 位补码 -> 有符号整数
static int64_t sext(uint32_t v) {
    return (v & SIGN) ? (int64_t)v - ((int64_t)1 << WIDTH) : (int64_t)v;
}

// WIDTH 位二进制打印
static const char* bin(uint32_t v, char* buf) {
    for (int i = 0; i < BITS; i++) buf[i] = ((v >> (BITS - 1 - i)) & 1u) ? '1' : '0';
    buf[BITS] = '\0';
    return buf;
}

struct Ref { uint32_t out; int zero, carry, overflow; };

static Ref ref_model(uint32_t a, uint32_t b, uint32_t op) {
    Ref r;
    r.carry = 0;
    r.overflow = 0;

    switch (op) {
        case 0:   // 加法
        case 1: { // 减法：A + ~B + 1
            uint32_t b1  = (op == 1) ? ((~b) & MASK) : b;
            uint64_t sum = (uint64_t)a + (uint64_t)b1 + (uint64_t)(op & 1u);
            r.out   = (uint32_t)(sum & MASK);
            r.carry = (int)((sum >> WIDTH) & 1u);
            int sa  = (int)((a  & SIGN) != 0);
            int sb1 = (int)((b1 & SIGN) != 0);
            int sr  = (int)((r.out & SIGN) != 0);
            r.overflow = (sa == sb1) && (sr != sa);
            break;
        }
        case 2: r.out = (~a) & MASK; break;
        case 3: r.out = a & b;       break;
        case 4: r.out = a | b;       break;
        case 5: r.out = a ^ b;       break;
        case 6: r.out = (sext(a) < sext(b)) ? 1u : 0u; break;
        case 7: r.out = (a == b) ? 1u : 0u;            break;
        default: r.out = 0;
    }
    r.zero = (r.out == 0);
    return r;
}

static const char* op_name(uint32_t op) {
    static const char* n[8] = {"加法", "减法", "取反", "与", "或", "异或", "比较", "相等"};
    return n[op & 7u];
}

static void check(uint32_t a, uint32_t b, uint32_t op) {
    a &= MASK;
    b &= MASK;

    dut.A  = a;
    dut.B  = b;
    dut.op = op;
    dut.eval();

    Ref e = ref_model(a, b, op);
    uint32_t got_out = (uint32_t)dut.out & MASK;
    int got_z = dut.zero, got_c = dut.carry, got_o = dut.overflow;

    checks++;
    if (got_out == e.out && got_z == e.zero && got_c == e.carry && got_o == e.overflow)
        return;

    errors++;
    if (errors <= 20) {
        static char ba[40], bb[40], be[40], bg[40];
        printf("[FAIL] op=%03b %-4s  A=%s B=%s\n", op, op_name(op),
               bin(a, ba), bin(b, bb));
        printf("       期望 out=%s zero=%d carry=%d overflow=%d\n",
               bin(e.out, be), e.zero, e.carry, e.overflow);
        printf("       实际 out=%s zero=%d carry=%d overflow=%d\n",
               bin(got_out, bg), got_z, got_c, got_o);
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    printf("ALU testbench：WIDTH=%d  MASK=0x%x\n\n", WIDTH, MASK);

    // ---- 定向用例：几个性质明确的点，任何位宽都有意义 ----
    for (uint32_t op = 0; op < 8; op++) {
        check(0, 0, op);
        check(1, 0, op);
        check(0, 1, op);
        check(MASK, 1, op);
        check(SIGN, SIGN - 1u, op);   // 最小值 vs 最大值，专门测有符号比较
        check(SIGN - 1u, SIGN, op);   // 最大值 vs 最小值
        check(MASK, MASK, op);
        check(SIGN, 1u, op);
        check(SIGN - 1u, 1u, op);
    }

    // ---- WIDTH 小的时候直接穷举 ----
#if WIDTH <= 8
    for (uint32_t op = 0; op < 8; op++)
        for (uint32_t a = 0; a <= MASK; a++)
            for (uint32_t b = 0; b <= MASK; b++)
                check(a, b, op);
    printf("穷举：8 功能 × %u × %u\n", MASK + 1u, MASK + 1u);
#else
    // ---- 位宽较大时随机 ----
    uint32_t seed = 20261105u;
    for (int i = 0; i < 200000; i++) {
        seed = seed * 1664525u + 1013904223u; uint32_t a = seed;
        seed = seed * 1664525u + 1013904223u; uint32_t b = seed;
        check(a, b, (uint32_t)(i & 7));
    }
    printf("随机：200000 组\n");
#endif

    printf("\nWIDTH=%d：共 %d 组，错 %d 组\n", WIDTH, checks, errors);
    return errors ? 1 : 0;
}
