# tests

`tests/*.txt` 是程序源，`tests/*.bin` 由 `tools/mkbin.py` 生成，用 `make images` 一次转换全部。

## txt 格式

- 一行一条指令或一条伪指令，空行忽略。
- `#` 或 `;` 之后是注释。
- 行首可写标签 `name:`，单独一行或与内容同行。
- 指令：`addi rd, rs1, imm`、`add rd, rs1, rs2`、`lui rd, imm20`、`lw rd, imm(rs1)`、`lbu rd, imm(rs1)`、`sw rs2, imm(rs1)`、`sb rs2, imm(rs1)`、`jalr rd, imm(rs1)`、`ebreak`。
- `lw rd, label` 与 `jalr rd, label` 表示以标签绝对地址为准，等价于以 x0 为基址。
- `.org 地址` 把当前位置推进到指定字节地址，中间补零，地址须 4 字节对齐且不能回退。
- `.word 表达式` 在当前位置放一个 32 位数据字。
- 也可以直接写机器字，例如 `0x01400513`。
- 寄存器可写 x0 到 x31 或 ABI 名，但超出 x15 会报错，因为 minirv 是 RV32E。

## 测试

| 文件 | 内容 | 期望 |
|---|---|---|
| `prog-two-insn.txt` | 讲义 addi 与 jalr 程序，halt 处用 ebreak | a0 = 30，ra = 12，pc = 0xc |
| `prog-add.txt` | 两个寄存器相加 | a2 = 12 |
| `prog-lui.txt` | 6 条 lui 与 ebreak，覆盖高低位、零立即数与 x0 | pc=0x18，a0=0x12345000，a1=0xfffff000，a2=0x1000，a3=0x80000000，a4=0，x0=0 |
| `prog-lw.txt` | 数据放在 0x20 的 lw 测试 | a1 = 0x12345678 |
| `prog-lbu.txt` | 从 0x20 起逐字节读取 | a1 = 0x78，a2 = 0x56，a3 = 0x34，a4 = 0x12 |
| `prog-sw.txt` | 写入 0x12345678 后用 lw、lbu 读回 | a2 = 0x12345678，a3 = 0x78，a4 = 0x12 |
| `prog-sb.txt` | 逐字节拼出 0x90abcdef 后读回 | a2 = 0x90abcdef，a3 = 0xef，a4 = 0x90 |
| `prog-all.txt` | 九条指令全覆盖，代码在 0x00-0x47，数据在 0x80 | 18 步，pc=0x3c；x1=0x38，x5=0x9a，x6=0x55，x8=0x2a，x9=0x9a，x10=0x80，x11=0x12345678，x12=0xc，x13=0x12345678，x14=0x56，x15=7 |

## 命令

```
make images
make run IMG=tests/prog-lw.bin
python3 tools/mkbin.py tests/prog-lw.txt tests/prog-lw.bin
```


## 全指令镜像

`prog-all.txt` 覆盖 addi、add、lui、lw、lbu、sw、sb、jalr、ebreak。构造方法是：

1. 先列出全部指令，保证每条至少出现一次。
2. 规划寄存器和数据区。数据区放在代码之后较远的位置（这里是 0x80），避免自覆盖。
3. 用 `lui` + `addi` 拼出一个可识别的 32 位数，再 `sw` 写、`lw` / `lbu` 读回，同时覆盖字和字节通道。
4. 用 `sb` 写单字节，再用 `lbu` 读回，验证字节使能与零扩展。
5. 用 `addi` + `add` 做一次算术，结果放进可检查的寄存器。
6. 用 `jalr` 调用一段带标签的函数，函数里再 `jalr x0, 0(ra)` 返回，检查 ra 与函数副作用。
7. 最后用 `ebreak` 结束，让 DPI-C 收尾。
8. 先在 EMU 上跑一遍得到参考值，再跑 NPC 的 sim 与 difftest，最后把期望值写进本表。

`prog-all` 的最终状态：pc=0x3c，x1=0x38，x5=0x9a，x6=0x55，x8=0x2a，x9=0x9a，x10=0x80，x11=0x12345678，x12=0xc，x13=0x12345678，x14=0x56，x15=7，其余为 0；difftest 报告 `mem writes: 2`（一次 sw、一次 sb）。
