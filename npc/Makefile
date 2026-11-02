# npc/Makefile —— E4 主线仿真框架
#
# 主线内容（双控开关 → 流水灯 → sCPU → NPC）放在 vsrc/ 与 csrc/。
# 数电实验等旁支练习放在 lab/<name>/，各自 include ../common.mk。
#
# 注意：sim 规则（含受保护的 $(call git_commit, "sim RTL") 行）定义在
# lab/common.mk 中，本文件通过 include 复用；该行保持原样，未做修改。

TOP       := top
VSRC      := $(abspath $(wildcard vsrc/*.v))
CSRC      := $(abspath $(wildcard csrc/*.cpp))
BUILD_DIR := build

include lab/common.mk
