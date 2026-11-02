// 双控开关的随机激励 testbench：随机驱动 a、b，eval 后与 C++ 参考模型比较。
// 有错返回非零，便于脚本/CI 判断。

#include "Vtop.h"
#include "verilated.h"

#include <cstdio>
#include <cstdlib>

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    Vtop* top = new Vtop{contextp};

    std::srand(12345);          // 固定种子：失败可复现
    const int N = 1000;
    int errors = 0;

    for (int i = 0; i < N; i++) {
        const int a = std::rand() & 1;
        const int b = std::rand() & 1;

        top->a = a;
        top->b = b;
        top->eval();            // 组合逻辑：改完输入必须 eval 再读输出

        const int expected = a ^ b;   // C++ 参考模型
        if (top->f != expected) {
            if (errors < 5) {
                std::printf("[%4d] a=%d b=%d f=%d expected=%d\n",
                            i, a, b, (int)top->f, expected);
            }
            errors++;
        }
    }

    std::printf("tested %d patterns, %d errors\n", N, errors);

    top->final();
    delete top;
    delete contextp;

    return errors ? 1 : 0;
}
