# npc/lab/common.mk —— 两段式 Verilator 仿真模板（所有子项目共用）
#
# 用法（子项目 Makefile 里只写参数）：
#   TOP  := shifter
#   VSRC := $(abspath $(wildcard vsrc/*.v))
#   CSRC := $(abspath $(wildcard csrc/*.cpp))
#   include ../common.mk
#
# 可选参数：VFLAGS（追加）、BUILD_DIR、SIM_MSG
# 产出：$(BUILD_DIR)/obj_dir/V$(TOP)；sim 规则内含课程追踪的 git_commit。

COMMON_MK      := $(lastword $(MAKEFILE_LIST))
WORKBENCH_ROOT := $(abspath $(dir $(COMMON_MK))/../..)

# tracer 的 git_commit 用 $(NEMU_HOME)/.. 定位仓库根。
# E 阶段 nemu 尚未初始化；路径中出现不存在的目录会让 flock 失败，
# 而错误被 -@ 静默吞掉（表现为"追踪成功"其实没有）。这里指向已存在的 npc/。
NEMU_HOME ?= $(abspath $(WORKBENCH_ROOT)/npc)
export NEMU_HOME

VERILATOR ?= verilator
VFLAGS    ?= -cc --exe -j 0 -Wall
BUILD_DIR ?= build
SIM_MSG   ?= sim RTL

OBJ_DIR := $(BUILD_DIR)/obj_dir
STAMP   := $(BUILD_DIR)/.verilated
EXE     := $(OBJ_DIR)/V$(TOP)

.PHONY: all sim run clean

all: $(EXE)

# 第一段：Verilog 或本 Makefile 变了才重新翻译
$(STAMP): $(VSRC) Makefile
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS) --top-module $(TOP) --Mdir $(OBJ_DIR) $(CSRC) $(VSRC)
	@touch $@

# 第二段：交给生成的 makefile 编译、链接（CSRC 用绝对路径）
$(EXE): $(STAMP) $(CSRC)
	$(MAKE) -C $(OBJ_DIR) -f V$(TOP).mk
	@touch $@

sim: $(EXE)
	$(call git_commit, "$(SIM_MSG)") # DO NOT REMOVE THIS LINE!!!
	./$(EXE)

run: $(EXE)
	./$(EXE)

clean:
	rm -rf $(BUILD_DIR)

include $(WORKBENCH_ROOT)/Makefile
