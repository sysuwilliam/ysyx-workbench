# minirv RTL

E5 的 RTL minirv NPC。单周期执行，指令集为 minirv 的八条指令
add、addi、lui、lw、lbu、sw、sb、jalr，另用 ebreak 作为程序结束约定。
pc 复位值 0x80000000，16 个通用寄存器 x0..x15，机器字 32 位，小端。

存储器不在 RTL 里。128 MiB、基址 0x80000000 的存储与访存语义由 C++ 实现（`../csrc/pmem.h`），
RTL 通过 DPI-C 访问：

- `pmem_read(raddr)` 返回 `raddr & ~3` 处的对齐字；
- `pmem_write(waddr, wdata, wmask)` 按字节掩码写入对齐字。

取指与数据读都调用 `pmem_read`，store 在时钟沿调用 `pmem_write`。
ebreak 通过 `npc_ebreak_halt()` 通知仿真环境结束。

## 目录

```
vsrc/
├── README.md
├── base/      参数化通用件，无 ISA 语义
│   ├── Reg.v        同步复位、带写使能的寄存器
│   ├── mux.v        N 选一，非 2 的幂也支持，越界输出 0
│   ├── adder.v      a + b + cin，同时给出进位
│   ├── ext.v        符号扩展 / 零扩展 / 同宽直连
│   ├── cmp.v        无符号三路比较
│   └── dec_onehot.v 独热译码
├── middle/    带 minirv 语义的功能块
│   ├── IFU.v        取指：pc、pc+4、跳转目标选择
│   ├── IDU.v        译码：字段、立即数、控制、非法检测
│   ├── RegisterFile.v 16 个 32 位寄存器，两个组合读口、一个写口
│   ├── EXU.v        执行：加法、地址、jalr 目标与对齐
│   ├── LSU.v        访存：字节选择、字节使能、对齐检查
│   └── WBU.v        写回：来源选择、GPR 写使能
└── top/       顶层，只做例化与连线
    └── minirv_top.v
```

## 顶层接口

模块名 `minirv_top`，放在 `vsrc/top/`。make 用 `RTL_TOP ?= minirv_top`，
文件名与模块名保持一致。

| 方向 | 信号 | 位宽 | 含义 |
|---|---|---|---|
| input | `clk` | 1 | 时钟，测试台手动翻转 |
| input | `rst` | 1 | 同步复位，高有效 |
| output | `pc` | 32 | 当前指令地址，也是取指地址 |
| output | `dbg_gpr` | 512 | `gpr[i]` 位于 `dbg_gpr[i*32 +: 32]` |
| output | `dbg_exec` | 1 | 本拍处理了一条指令，含 ebreak 与 trap |
| output | `dbg_halt` | 1 | ebreak 造成的停机，时钟沿后有效 |
| output | `dbg_trap` | 1 | 非法指令、跳转未对齐或访存未对齐，沿后有效 |

`dbg_exec` 是时钟沿之前的组合信号，`dbg_halt`、`dbg_trap` 是沿之后的状态。
测试台靠 `dbg_exec` 计步并与 EMU 对齐，靠后两者判断停机原因。
完整说明以 `../csrc/npc_sim.cpp` 顶部注释为准。

## DPI-C 接口

| 方向 | 函数 | 含义 |
|---|---|---|
| import | `npc_ebreak_halt()` | ebreak 停机，C++ 侧置 `gotFinish` |
| import | `pmem_read(raddr)` | 返回 `raddr & ~3` 处的对齐字 |
| import | `pmem_write(waddr, wdata, wmask)` | 按 `wmask` 把 `wdata` 写入对齐字 |

`pmem_read` 总是返回整字，lw/lbu 的字节选择由 LSU 完成；
`pmem_write` 的地址会被对齐，`wmask` 每比特对应 `wdata` 的一个字节。

## 模块职责与连线

```
  pmem_read(pc) ─────────────> inst ──> IDU ── 控制 / 立即数 ──┐
                                                               v
  pc ──> IFU ── pc+4 / jump_target ────────────────────────> EXU ──> alu_result / mem_addr
          ^                                                    │
          │                                                    ├──> LSU ──> load_data ──> WBU
          │                                                    │        ^
          │                                  pmem_read(mem_addr) ──────┘
          │                                                    │
          │                                       pmem_write(mem_addr, mem_wdata, mem_be)
          └────────────────────────────────────────────────── WBU ──> RegisterFile
```

- IFU 保存 pc，产生 pc+4；jalr 时选择跳转目标。pc 永远 4 字节对齐。
- IDU 拆字段、生成 I/S/U 三种立即数与控制信号，识别 ebreak 与非法指令。
- EXU 计算 add/addi、lui、访存地址、jalr 目标，纯组合。
- LSU 接收 EXU 算出的地址，产生写数据、字节使能与对齐错误，并把读回的字按宽度
  选择、扩展成 `load_data`。
- WBU 选择写回来源，产生 GPR 写地址、写数据与写使能。
- RegisterFile 用讲义骨架：内部 `rf` 数组加
  `always @(posedge clk) if (wen) rf[waddr] <= wdata;`。读口与 x0 特性
  在块外补，x0 的写丢弃由 WBU 的 `rf_we` 实现。

## 一拍之内的顺序

```
clk=0; eval();    组合求值：取指 pmem_read(pc)、数据读 pmem_read(mem_addr)
clk=1; eval();    上升沿提交：PC、GPR、调试标志；store 调用 pmem_write
```

load 的数据在时钟沿之前就位，store 在沿上写入，下一拍取指才看得到。
这与 `minirvEMU` 里「先取指、后执行」的顺序一致。ebreak 的 DPI 调用也在
上升沿，C++ 侧置 `gotFinish` 后测试台退出。

## 与 EMU 对齐的语义

- 小端：最低地址的字节是字的 bit7..0。
- `lw`/`sw` 地址低两位必须为 0，否则错误停机；`sb`/`lbu` 无对齐要求。
- `jalr` 目标为 `(rs1 + imm) & ~1`，再要求 4 字节对齐，未对齐则停机且不写 rd。
- `lbu` 读一个字节并零扩展；`lui` 是 `inst[31:12] << 12`。
- rd/rs1/rs2 落在 x16..x31、未知 funct3/funct7、非 ebreak 的 SYSTEM 编码
  都按非法指令处理。
- x0 读恒零、写丢弃；jalr x0 仍然更新 pc。
- 取指越界与访存越界由 DPI-C 的 `pmem_read`/`pmem_write` 检查，因为内存
  容量与基址属于 EEI，处理器不知道 128 MiB 的上界。
- 复位后 pc=0x80000000，全部 GPR 与内存为 0。

## 命令

```
make images                                 由 tests/*.txt 生成 tests/*.bin
make lint                                   只做 Verilog lint
make rtl                                    只构建 RTL 仿真器
make sim      IMG=tests/prog-all.bin        运行 RTL NPC
make difftest IMG=tests/prog-all.bin        与 minirvEMU 逐条对拍
make difftest IMG=tests/prog-all.bin TRACE=1 逐条打印轨迹
```

`make sim` 结束打印 pc、停机原因、16 个 GPR、内存写次数与改写过的字。
`make difftest` 每步比较 pc 与全部 GPR，结束时比较两份 64 KiB 内存（difftest 侧尚未适配 128 MiB），
第一次不一致打印完整现场。

## 约定

- 模块名全工程唯一，文件名与模块名一致；层次靠例化，不用 `include` 拼源文件。
- 每个 `.v` 第一行写 `` `timescale 1ns/1ns ``。
- `base/` 放参数化通用件，`middle/` 放带 minirv 语义的功能块，
  `top/` 只做例化与连线。
- Makefile 的 `VSRC` 只展开两级：`vsrc/*.v` 与 `vsrc/*/*.v`，不要再往下建目录。
- 每个模块头部注释按「职责 / 与 EMU 对齐的语义 / 需要先定 / 可复用 base /
  建议验证」五段写，新增模块沿用这个格式。
- 存储器不写成 RTL；GPR 用讲义的 `RegisterFile` 骨架，不用 16 个 `Reg` 拼。

## 当前进度（2026-11-17）

- 九条指令全部实现并验证：add、addi、lui、lw、lbu、sw、sb、jalr、ebreak。
- DPI-C 的 `pmem_read` / `pmem_write` 已接入，取指与访存都走 DPI；
  `npc_ebreak_halt` 负责正常结束仿真。
- 全指令镜像 `tests/prog-all.txt` 18 步 PASS，`mem writes=2`，内存比对一致。
- 全量回归 10 个镜像全部 PASS。下一步是 E5 收尾与验收。
