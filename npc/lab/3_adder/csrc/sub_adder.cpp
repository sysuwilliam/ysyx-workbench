// sub_adder 的 testbench —— 逐组比对，不依赖 NVBoard
//
// 位宽由编译期宏 WIDTH 决定（默认 32），必须和 RTL 的 parameter WIDTH 一致：
//   32 位： make run
//    8 位： make run W=8    （Makefile 里要把 W 同时传给 -GWIDTH 和 -DWIDTH）
//
// 参考模型：Result = A + (sub_add ? ~B : B) + sub_add   （低 WIDTH 位）
//           Carry    = 上面这个加法的第 WIDTH+1 位
//           Zero     = Result 全 0
//           Overflow = 有符号溢出：两个加数符号相同、结果符号不同
// 其中「加数」在 sub_add=1 时是 ~B，所以符号位取 ~B 的，不能取 B 的。
#include <cstdio>
#include <cstdint>
#include "Vsub_adder.h"
#include "verilated.h"

#ifndef WIDTH
#define WIDTH 32
#endif
static_assert(WIDTH >= 2 && WIDTH <= 32, "参考模型用 uint32_t 累加，WIDTH 限定在 2..32");

static const uint32_t MASK = (WIDTH >= 32) ? 0xFFFFFFFFu : ((1u << WIDTH) - 1u);
static const uint32_t SIGN = 1u << (WIDTH - 1);
static const int      HEXD = (WIDTH + 3) / 4;   // 打印用的十六进制位数

static Vsub_adder dut;

struct Ref { uint32_t result; int carry, zero, overflow; };

static Ref ref_model(uint32_t a, uint32_t b, int sub) {
    uint64_t b1  = sub ? (uint64_t)((~b) & MASK) : (uint64_t)b;
    uint64_t sum = (uint64_t)a + b1 + (uint64_t)sub;

    Ref r;
    r.result = (uint32_t)(sum & MASK);
    r.carry  = (int)((sum >> WIDTH) & 1);
    r.zero   = (r.result == 0);

    int sa  = (int)((a & SIGN) != 0);
    int sb1 = (int)((b1 & SIGN) != 0);
    int sr  = (int)((r.result & SIGN) != 0);
    r.overflow = (sa == sb1) && (sr != sa);
    return r;
}

static int checks = 0, errors = 0;

static void check(const char* tag, uint32_t a, uint32_t b, int sub) {
    a &= MASK;   // 小位宽时把常量截到合法范围，避免端口静默截断带来的困惑
    b &= MASK;

    dut.A = a;
    dut.B = b;
    dut.sub_add = sub;
    dut.eval();

    Ref e = ref_model(a, b, sub);
    uint32_t got_r = (uint32_t)dut.Result & MASK;
    int got_c = dut.Carry, got_z = dut.Zero, got_o = dut.Overflow;

    checks++;
    if (got_r == e.result && got_c == e.carry && got_z == e.zero && got_o == e.overflow)
        return;

    errors++;
    if (errors <= 20) {
        printf("[FAIL] %-22s A=%0*x B=%0*x sub_add=%d\n", tag, HEXD, a, HEXD, b, sub);
        printf("       期望 Result=%0*x Carry=%d Zero=%d Overflow=%d\n",
               HEXD, e.result, e.carry, e.zero, e.overflow);
        printf("       实际 Result=%0*x Carry=%d Zero=%d Overflow=%d\n",
               HEXD, got_r, got_c, got_z, got_o);
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    printf("sub_adder testbench：WIDTH=%d  MASK=0x%0*x\n\n", WIDTH, HEXD, MASK);

    // ---- 定向用例：每个都盯着一条容易写错的性质 ----
    check("0+0",            0u,        0u,        0);
    check("1+1",            1u,        1u,        0);
    check("进位出界",       MASK,      1u,        0);
    check("5+3",            5u,        3u,        0);
    check("5-3 不借位",     5u,        3u,        1);
    check("3-5 借位",       3u,        5u,        1);
    check("x-x 得零",      MASK,      MASK,       1);
    check("正溢出",        SIGN - 1u,  1u,        0);
    check("负溢出",        SIGN,      MASK,       0);
    check("减出正溢出",    SIGN - 1u, MASK,       1);
    check("减出负溢出",    SIGN,      1u,        1);
    check("最大+最大",     MASK,      MASK,       0);
    check("min-max",       SIGN,      SIGN - 1u,  0);

    // ---- 随机用例：固定种子，复现得出来 ----
    uint32_t seed = 20261105u;
    for (int i = 0; i < 20000; i++) {
        seed = seed * 1664525u + 1013904223u;
        uint32_t a = seed;
        seed = seed * 1664525u + 1013904223u;
        uint32_t b = seed;
        check("随机", a, b, (int)((seed >> 31) & 1));
    }

    // ---- 边界扫描：A/B 各自取几个极值两两组合 ----
    const uint32_t edge[] = {0u, 1u, SIGN - 1u, SIGN, MASK, MASK - 1u, (uint32_t)(SIGN | 1u)};
    const int n = (int)(sizeof(edge) / sizeof(edge[0]));
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
            for (int s = 0; s <= 1; s++)
                check("边界", edge[i], edge[j], s);

    printf("\nWIDTH=%d：共 %d 组，错 %d 组\n", WIDTH, checks, errors);
    return errors ? 1 : 0;
}
