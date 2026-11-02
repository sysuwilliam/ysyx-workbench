// 模板 testbench：穷举输入 + 参考模型比较
#include "Vtemplate.h"
#include "verilated.h"

#include <cstdio>

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    Vtemplate* top = new Vtemplate{contextp};

    int errors = 0;
    for (int a = 0; a < 2; a++) {
        for (int b = 0; b < 2; b++) {
            top->a = a;
            top->b = b;
            top->eval();

            const int expected = a & b;
            if (top->y != expected) {
                std::printf("a=%d b=%d y=%d expected=%d\n", a, b, (int)top->y, expected);
                errors++;
            }
        }
    }

    std::printf("tested 4 patterns, %d errors\n", errors);

    top->final();
    delete top;
    delete contextp;
    return errors ? 1 : 0;
}
