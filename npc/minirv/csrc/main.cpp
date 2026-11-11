#include "minirvEMU.h"

#include <stdio.h>
#include <stdlib.h>

/*
 * minirvEMU 命令行入口
 *
 * 用法：minirvEMU <image> [max_steps]
 *   image      裸二进制镜像，读入内存起始地址
 *   max_steps  步数上限，缺省 100000，防止死循环
 *
 * 退出码：0 表示正常停止（含撞步数上限），1 表示参数、加载或执行出错。
 */
int main(int argc, char *argv[])
{
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "usage: %s <image> [max_steps]\n", argv[0]);
        return 1;
    }

    // 第三个参数可选，按 0 进制解析，支持十进制与 0x 十六进制
    uint64_t max_steps = 100000;
    if (argc == 3) {
        max_steps = strtoull(argv[2], NULL, 0);
    }

    // 先复位再加载，保证内存与寄存器都是确定的初值
    minirv_reset();
    if (minirv_load(argv[1]) < 0) {
        return 1;
    }

    int ret = minirv_run(max_steps);
    minirv_dump();
    return ret == 0 ? 0 : 1;
}
