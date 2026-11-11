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
| `prog-lw.txt` | 数据放在 0x20 的 lw 测试 | a1 = 0x12345678 |
| `prog-lbu.txt` | 从 0x20 起逐字节读取 | a1 = 0x78，a2 = 0x56，a3 = 0x34，a4 = 0x12 |
| `prog-sw.txt` | 写入 0x12345678 后用 lw、lbu 读回 | a2 = 0x12345678，a3 = 0x78，a4 = 0x12 |
| `prog-sb.txt` | 逐字节拼出 0x90abcdef 后读回 | a2 = 0x90abcdef，a3 = 0xef，a4 = 0x90 |

## 命令

```
make images
make run IMG=tests/prog-lw.bin
python3 tools/mkbin.py tests/prog-lw.txt tests/prog-lw.bin
```
