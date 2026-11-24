# subrepo-patch

`ysyxSoC`、`nvboard`、`AM/am-kernels`、`AM/fceux-am` 这些上游仓库在 workbench 的 `.gitignore` 里被忽略，
本目录按原路径保存其中自己写的改动，让它们跟着 workbench 一起推送。

| 仓库 | 文件 | 改动 |
| --- | --- | --- |
| ysyxSoC | `perip/vga/vga_apb.v` | E7 VGA APB 从设备，窗口 `0x2100_0000`，160x120 1bpp 源图 4x4 放大到 640x480 |
| ysyxSoC | `perip/gpio/mygpio_top_apb.v` | GPIO APB 从设备 |
| ysyxSoC | `ready-to-run/minirv/ElaborateTop.v` | 生成文件里手工补的 APBFanout out_4 与 VGA 顶层引脚 |
| nvboard | `src/uart.cpp` | 串口除数 16 → 208，对齐 SoC 25MHz |
| am-kernels | `kernels/{bad-apple-vga,csr,gpio,timertest}` | Bad Apple 播放器与 E6/E7 测试程序 |
| am-kernels | `benchmarks/coremark/include/core_portme.h`、`benchmarks/dhrystone/dry.c` | 仿真时缩小迭代次数 |
| fceux-am | `src/config.h` | 关掉 `HAS_GUI`，便于无 GUI 环境编译 |

恢复到对应子仓：

```bash
rsync -a subrepo-patch/ysyxSoC/    ysyxSoC/
rsync -a subrepo-patch/nvboard/    nvboard/
rsync -a subrepo-patch/am-kernels/ AM/am-kernels/
rsync -a subrepo-patch/fceux-am/   AM/fceux-am/
```
