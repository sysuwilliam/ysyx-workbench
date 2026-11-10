# sCPU

E4 主线：用 RTL 重写 F6.4 的 sISA 单周期处理器。

## 目录

```
vsrc/
├── sCPU.v        核心：例化、连线、启动按钮
├── sCPU_board.v  NVBoard 顶层：sCPU + 指令跟踪 + UART
├── base/         原语：Reg、mux、adder、cmp、dec_onehot、ext、seg7、bin2bcd
├── mid/          PC、ROM、Instruction_Decoder、GPR、exec、io_dev
└── debug/        trace（指令跟踪）、uart_tx（8N1 发送）
csrc/
├── main.cpp      NVBoard 主程序
├── test.cpp      纯 RTL 回归（46 拍检查 GPR/LED/Hex）
├── difftest.cpp  sCPU 与 sEMU 逐条比较 PC 和 GPR
├── sEMU.cpp      sISA 参考模型（无 main）
└── sEMU.h        参考模型接口
constr/
└── sCPU_board.nxdc  NVBoard 引脚约束
build/<TB>/       每个 testbench 独立的构建目录，已被忽略
```

## 程序

ROM 里装的是改进后的求和程序：从拨码读入 N，计算 1+2+…+N。
循环里每累加一次就执行一次 `io r1, LED`，这条写操作会同时更新 LED 和数码管，
所以两个显示始终是同一个值，不会出现一个先更新、另一个落后一拍的偏差。
`sw=10` 时 46 拍后 `r1=55`，LED 显示二进制 `0011_0111`，数码管显示十进制 `55`。

## 命令

```
make                  # 构建 NVBoard 版 sCPU_board，不运行
make run              # 构建并运行 NVBoard 版
make TB=test run      # 纯 RTL 回归，不链接 NVBoard、不带 trace
make TB=difftest run  # sCPU 与 sEMU 逐条 DiffTest
make TB=test sim      # 回归并提交 tracer
make lint             # verilator --lint-only -Wall
make clean
```

## NVBoard

- `BTNC`：启动/重算。复位后 CPU 停住；每按一次都会把 PC、GPR、输出
  复位到初值，从地址 0 重新算一轮。一轮结束后改拨码再按，就是新的一轮。
- `BTNL`：复位。按住时 CPU 和输出回到初始状态。
- `SW7..SW0`：拨码输入，决定求和末项 N。
- `LD7..LD0`：LED 显示当前累加和，二进制，每次累加后更新；
  和 `SEG` 数码管在同一拍更新。
- `SEG2/SEG1/SEG0`：三位十进制数码管，依次是百位、十位、个位；
  百位和十位的前导零熄灭，例如 55 显示 `55`、120 显示 `120`。
  复位或新一轮开始时全灭，写出结果后才点亮。
- `SEG7..SEG3`：不使用，统一绑到 `seg_off=8'hFF`，保持全灭。
- `UART_TX`：指令跟踪输出。右上角 UART 终端每行显示一条刚执行的指令，
  已反汇编成明文，例如：
  ```
  add r1, r1, r2
  io r1, LED/DEC
  add r2, r2, r3
  bner0 r2, -3
  ```
  `sCPU_board` 的 `GAP` 参数控制每行之后的空拍数，默认 20000。
  GAP 越小跑得越快；设成 0 时基本按串口发送速度连续输出。
  如果终端上滚得太快看不清，把 GAP 调大即可。

## DiffTest

- `csrc/sEMU.cpp` 是 sISA 的参考模型，`csrc/difftest.cpp` 是测试台。
- 每个时钟周期：sCPU 执行一条指令，sEMU 也执行一条，然后比较 `PC` 和 `r0~r3`。
- 第一次不一致时打印第几条指令、PC 的 DUT/REF 值、以及每个不同的寄存器，然后停止。
- 参考模型的 `io` 输入固定读 `sw`，输出不影响 GPR；程序字节在 `difftest.cpp` 里，
  和 `vsrc/mid/ROM.v` 保持一致。
- 注入过两类错误验证：`bner0` 分支条件取反时报 `PC mismatch`；`li` 写回值改错时报 `r1 mismatch`。

## 约定

- 模块名全工程唯一，文件名与模块名一致；层次用例化表达，不要 `include` 源文件。
- 每个文件写同一行 `` `timescale 1ns/1ns ``。
- `VSRC` 用两级 wildcard：`vsrc/*.v` 与 `vsrc/*/*.v`。
- `.nxdc` 不在 `npc/.gitignore` 白名单内，入库时要 `git add -f`。
