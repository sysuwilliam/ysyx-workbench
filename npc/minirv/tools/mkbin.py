#!/usr/bin/env python3
# mkbin.py —— 把 tests/*.txt 形式的迷你汇编翻译成裸二进制
#
# 支持的语法：
#   - 一行一条指令，空行忽略
#   - "#" 或 ";" 之后是注释
#   - 标签 "name:"，可单独一行，也可与指令同行
#   - 指令：addi、add、lui、lw、lbu、sw、sb、jalr、ebreak
#   - .org 地址      把当前位置推进到指定字节地址，中间补零
#   - .word 表达式   在当前位置放一个 32 位数据字
#   - 直接写机器字，例如 0x01400513
#
# 地址从 0 开始，每条指令与 .word 占 4 字节；标签在汇编期解析，不产生字节。
# 产物是扁平二进制，小端存放，不经过链接与重定位。

import re
import struct
import sys

OP_LOAD = 0b0000011
OP_STORE = 0b0100011
OP_IMM = 0b0010011
OP_REG = 0b0110011
OP_LUI = 0b0110111
OP_JALR = 0b1100111

F3_LW = 0b010
F3_LBU = 0b100
F3_SW = 0b010
F3_SB = 0b000
F3_ADDI = 0b000
F3_ADD = 0b000
F3_JALR = 0b000

F7_ADD = 0b0000000

INSN_EBREAK = 0b00000000000100000000000001110011

ABI = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7, "s0": 8, "fp": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14, "a5": 15,
    "a6": 16, "a7": 17, "s2": 18, "s3": 19, "s4": 20, "s5": 21,
    "s6": 22, "s7": 23, "s8": 24, "s9": 25, "s10": 26, "s11": 27,
    "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}


def reg(tok):
    # 先查 ABI 名，再接受 x0 到 x31；minirv 只有 x0..x15
    tok = tok.strip()
    if tok in ABI:
        num = ABI[tok]
    else:
        m = re.fullmatch(r"[xX](\d+)", tok)
        if not (m and 0 <= int(m.group(1)) < 32):
            raise ValueError("bad register: " + tok)
        num = int(m.group(1))
    if num >= 16:
        raise ValueError("register %s is outside RV32E x0..x15" % tok)
    return num


def imm(tok):
    # int(tok, 0) 自动识别十进制、0x 十六进制与负号
    return int(tok.strip(), 0)


def clean(line):
    # 去掉注释与首尾空白，注释符出现在任何位置都截断
    for sep in ("#", ";"):
        if sep in line:
            line = line.split(sep, 1)[0]
    return line.strip()


def enc_i(opcode, funct3, rd, rs1, value):
    # I 型编码：imm[11:0] | rs1 | funct3 | rd | opcode
    if not -2048 <= value <= 2047:
        raise ValueError("immediate out of range: %d" % value)
    return ((value & 0xfff) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def enc_r(opcode, funct3, funct7, rd, rs1, rs2):
    # R 型编码：funct7 | rs2 | rs1 | funct3 | rd | opcode
    return ((funct7 & 0x7f) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | (rd << 7) | opcode


def enc_u(opcode, rd, value):
    # U 型编码：imm[31:12] | rd | opcode
    if not 0 <= value <= 0xfffff:
        raise ValueError("u-immediate out of range: %d" % value)
    return (value << 12) | (rd << 7) | opcode


def enc_s(opcode, funct3, rs1, rs2, value):
    # S 型编码：imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode
    if not -2048 <= value <= 2047:
        raise ValueError("immediate out of range: %d" % value)
    imm = value & 0xfff
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | ((imm & 0x1f) << 7) | opcode


def mem_operand(text, labels):
    # 允许 imm(rs1) 或单独的标签（等价于以 x0 为基址的绝对地址）
    m = re.fullmatch(r"(.+)\((.+)\)", text.strip())
    if m:
        return reg(m.group(2)), imm(m.group(1))
    name = text.strip()
    if name not in labels:
        raise ValueError("unknown label: " + name)
    return 0, labels[name]


def assemble(text, labels):
    # 一行文本翻译成一个 32 位机器字，标签值在第二遍时已经就绪
    if re.fullmatch(r"(0x[0-9a-fA-F]+|\d+)", text):
        return int(text, 0)

    m = re.fullmatch(r"addi\s+([^,]+),\s*([^,]+),\s*(.+)", text)
    if m:
        return enc_i(OP_IMM, F3_ADDI, reg(m.group(1)), reg(m.group(2)), imm(m.group(3)))

    m = re.fullmatch(r"add\s+([^,]+),\s*([^,]+),\s*([^,]+)", text)
    if m:
        return enc_r(OP_REG, F3_ADD, F7_ADD,
                     reg(m.group(1)), reg(m.group(2)), reg(m.group(3)))

    m = re.fullmatch(r"lui\s+([^,]+),\s*(.+)", text)
    if m:
        return enc_u(OP_LUI, reg(m.group(1)), imm(m.group(2)))

    m = re.fullmatch(r"lw\s+([^,]+),\s*(.+)", text)
    if m:
        rs1, value = mem_operand(m.group(2), labels)
        return enc_i(OP_LOAD, F3_LW, reg(m.group(1)), rs1, value)

    m = re.fullmatch(r"lbu\s+([^,]+),\s*(.+)", text)
    if m:
        rs1, value = mem_operand(m.group(2), labels)
        return enc_i(OP_LOAD, F3_LBU, reg(m.group(1)), rs1, value)

    m = re.fullmatch(r"sw\s+([^,]+),\s*(.+)", text)
    if m:
        rs1, value = mem_operand(m.group(2), labels)
        return enc_s(OP_STORE, F3_SW, rs1, reg(m.group(1)), value)

    m = re.fullmatch(r"sb\s+([^,]+),\s*(.+)", text)
    if m:
        rs1, value = mem_operand(m.group(2), labels)
        return enc_s(OP_STORE, F3_SB, rs1, reg(m.group(1)), value)

    m = re.fullmatch(r"jalr\s+([^,]+),\s*(.+)", text)
    if m:
        rs1, value = mem_operand(m.group(2), labels)
        return enc_i(OP_JALR, F3_JALR, reg(m.group(1)), rs1, value)

    if text == "ebreak":
        return INSN_EBREAK

    raise ValueError("bad instruction: " + text)


def main(argv):
    if len(argv) != 3:
        print("usage: %s <input.txt> <output.bin>" % argv[0])
        return 1
    src, dst = argv[1], argv[2]

    # 第一遍：按出现顺序给每条指令与数据分配地址，记下标签
    labels = {}
    items = []
    addr = 0
    with open(src, encoding="utf-8") as f:
        for lineno, raw in enumerate(f, 1):
            line = clean(raw)
            if not line:
                continue
            m = re.fullmatch(r"([A-Za-z_.][\w.]*):(.*)", line)
            if m:
                name = m.group(1)
                if name in labels:
                    print("%s:%d: duplicate label %s" % (src, lineno, name), file=sys.stderr)
                    return 1
                labels[name] = addr
                line = m.group(2).strip()
                if not line:
                    continue
            low = line.lower()
            if low.startswith(".org"):
                try:
                    value = imm(line[4:].strip())
                except ValueError:
                    print("%s:%d: bad .org operand" % (src, lineno), file=sys.stderr)
                    return 1
                if value % 4 != 0:
                    print("%s:%d: .org address must be 4-byte aligned" % (src, lineno), file=sys.stderr)
                    return 1
                if value < addr:
                    print("%s:%d: .org cannot move backwards" % (src, lineno), file=sys.stderr)
                    return 1
                addr = value
                continue
            items.append((lineno, addr, line))
            addr += 4

    # 第二遍：标签地址已知，逐条编码并放入对应偏移
    words = {}
    end = 0
    for lineno, addr, line in items:
        try:
            if line.lower().startswith(".word"):
                word = imm(line[5:].strip())
            else:
                word = assemble(line, labels)
        except ValueError as e:
            print("%s:%d: %s" % (src, lineno, e), file=sys.stderr)
            return 1
        if not -0x80000000 <= word <= 0xffffffff:
            print("%s:%d: word out of range" % (src, lineno), file=sys.stderr)
            return 1
        words[addr] = word & 0xffffffff
        end = max(end, addr + 4)

    buf = bytearray(end)
    for addr, word in words.items():
        struct.pack_into("<I", buf, addr, word)

    with open(dst, "wb") as f:
        f.write(buf)

    print("wrote %d bytes from %d items" % (len(buf), len(items)))
    for name, value in labels.items():
        print("  %-10s 0x%08x" % (name, value))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
