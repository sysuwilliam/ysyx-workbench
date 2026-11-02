# npc/Makefile —— Verilator 两段式仿真框架
#
#   第一段：verilator 把 vsrc/*.v 翻译成 C++（输出到 build/obj_dir）
#   第二段：make -C build/obj_dir -f V<top>.mk 编译 csrc/*.cpp 并链接
#
# sim 规则里的 $(call git_commit, "sim RTL") 是课程追踪机制，不能删。

# tracer 的 git_commit 用 $(NEMU_HOME)/.. 定位仓库根目录。
# E 阶段 nemu 还没初始化，路径里出现不存在的 nemu/ 会让 flock 直接失败。
# 这里给 NEMU_HOME 一个"存在且父目录是仓库根"的默认值（只用于路径运算）；
# 将来 init.sh nemu 设置环境变量后，会优先使用环境里的值。
NEMU_HOME ?= $(abspath $(CURDIR))
export NEMU_HOME

VERILATOR ?= verilator
VFLAGS    := -cc --exe -j 0 -Wall

TOP       := top
VSRC      := $(abspath $(wildcard vsrc/*.v))
CSRC      := $(abspath $(wildcard csrc/*.cpp))

BUILD_DIR := build
OBJ_DIR   := $(BUILD_DIR)/obj_dir
STAMP     := $(BUILD_DIR)/.verilated
EXE       := $(OBJ_DIR)/V$(TOP)

.PHONY: all sim run clean

all: sim

# 第一段：Verilog 或本 Makefile 变了才重新翻译
$(STAMP): $(VSRC) Makefile
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS) --top-module $(TOP) --Mdir $(OBJ_DIR) $(CSRC) $(VSRC)
	@touch $@

# 第二段：交给生成的 makefile 编译、链接
# 注意：$(CSRC) 是绝对路径，生成的 makefile 里的 VPATH 才能在 obj_dir 下正确解析
$(EXE): $(STAMP) $(CSRC)
	$(MAKE) -C $(OBJ_DIR) -f V$(TOP).mk
	@touch $@

sim: $(EXE)
	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!
	./$(EXE)

run: $(EXE)
	./$(EXE)

clean:
	rm -rf $(BUILD_DIR)

include ../Makefile
