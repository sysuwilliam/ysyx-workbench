# 3_adder —— 实验三：任意位宽的 ALU（NVBoard 版）
#
#   make run     # 编译并启动 NVBoard
#   make W=8     # 改位宽（接板子时保持 4，开发板只有 8 个拨码开关）
#
# 引脚分配在 constr/ALU.nxdc，顶层模块名必须和 TOP 一致。
# W 同时进 BUILD_DIR：改位宽会换目录重新做 elaboration。

TOP       := ALU
W         ?= 4

VSRC      := $(abspath $(wildcard vsrc/*.v))
CSRC      := $(abspath csrc/main.cpp)
BUILD_DIR := build/w$(W)

include ../common.mk

# -G 决定 Verilog 侧顶层参数的宽度，-D 决定 C++ 侧的宽度
VFLAGS += -GWIDTH=$(W) -CFLAGS "-DWIDTH=$(W)"
