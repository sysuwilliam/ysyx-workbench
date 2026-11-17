# npc/minirv/Makefile —— minirvEMU 与 RTL minirv NPC 的构建与调试
#
# EMU（csrc/*.cpp）
#   make                                    构建 build/minirvEMU
#   make images                             由 tests/*.txt 生成 tests/*.bin
#   make run IMG=<镜像> [STEPS=<步数>]      运行 EMU
#   make debug                              构建带调试信息的 EMU
#   make gdb IMG=<镜像> [STEPS=<步数>]      用 gdb 打开 EMU
#   make asan IMG=<镜像> [STEPS=<步数>]     用 ASan/UBSan 构建并运行
#   make syntax                             只查 EMU 的语法与警告
#
# RTL（vsrc/）
#   make rtl                                只构建 RTL 仿真器
#   make sim IMG=<镜像> [STEPS=<步数>]      构建并运行 RTL NPC
#   make difftest IMG=<镜像> [STEPS=<步数>] [TRACE=1] 构建并与 minirvEMU 逐条对拍
#   make lint                               只做 Verilog lint
#
#   make clean                              删除 build/
#
# RTL 顶层约定
#   模块名 minirv_top，可用 RTL_TOP=... 覆盖
#   端口与存储器约定见 csrc/npc_sim.cpp 顶部注释
#   存储器在 C++ 里（csrc/pmem.h），镜像由 +BIN= 直接读入
#
# 参数
#   IMG     镜像路径，run/sim/difftest 必填
#   STEPS   步数上限，缺省 100000

CXX       ?= g++
CXXFLAGS  ?= -std=c++17 -Wall -Wextra -Wpedantic -O2
DBGFLAGS  := -g -O0
SANFLAGS  := -g -O1 -fsanitize=address,undefined
CPPFLAGS  := -Icsrc

BUILD_DIR := build
SRCS      := $(wildcard csrc/*.cpp)
SRCS      := $(filter-out csrc/npc_sim.cpp csrc/npc_difftest.cpp,$(SRCS))
OBJS      := $(patsubst csrc/%.cpp,$(BUILD_DIR)/%.o,$(SRCS))
DEPS      := $(OBJS:.o=.d)
TARGET    := $(BUILD_DIR)/minirvEMU

DBG_TARGET := $(BUILD_DIR)/debug/minirvEMU
SAN_TARGET := $(BUILD_DIR)/asan/minirvEMU

MKIMG     := tools/mkbin.py
IMG_SRCS  := $(wildcard tests/*.txt)
IMG_BINS  := $(IMG_SRCS:.txt=.bin)

STEPS     ?= 100000
TRACE     ?= 0

VERILATOR ?= verilator
RTL_TOP   ?= minirv_top
RTL_FLAGS ?= -cc --exe -j 0 -Wall
LINTFLAGS ?= --lint-only -Wall
RTL_BUILD := $(BUILD_DIR)/rtl
RTL_VSRC  := $(abspath $(wildcard vsrc/*.v vsrc/*/*.v))
SIM_MAIN  := $(abspath csrc/npc_sim.cpp)
DIFF_MAIN := $(abspath csrc/npc_difftest.cpp)
EMU_LIB   := $(abspath csrc/minirvEMU.cpp)
CSRC_H    := $(wildcard csrc/*.h)

SIM_STAMP := $(RTL_BUILD)/sim/.verilated
SIM_EXE   := $(RTL_BUILD)/sim/V$(RTL_TOP)
DIFF_STAMP := $(RTL_BUILD)/difftest/.verilated
DIFF_EXE   := $(RTL_BUILD)/difftest/V$(RTL_TOP)

.DEFAULT_GOAL := all
.PHONY: all images run debug gdb asan syntax clean help rtl sim difftest lint

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) $^ -o $@

$(BUILD_DIR)/%.o: csrc/%.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR):
	mkdir -p $@

-include $(DEPS)

images: $(IMG_BINS)

tests/%.bin: tests/%.txt $(MKIMG)
	python3 $(MKIMG) $< $@

run: $(TARGET) images
	@test -n "$(IMG)" || { echo "usage: make run IMG=<image> [STEPS=<n>]"; exit 1; }
	./$(TARGET) $(IMG) $(STEPS)

debug: $(DBG_TARGET)

$(DBG_TARGET): $(SRCS) $(wildcard csrc/*.h)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(DBGFLAGS) $(CPPFLAGS) $(SRCS) -o $@

gdb: $(DBG_TARGET)
	@test -n "$(IMG)" || { echo "usage: make gdb IMG=<image> [STEPS=<n>]"; exit 1; }
	gdb -q -ex 'break minirv_decode_exec' -ex 'run $(IMG) $(STEPS)' $(DBG_TARGET)

asan: $(SAN_TARGET)
	@test -n "$(IMG)" || { echo "usage: make asan IMG=<image> [STEPS=<n>]"; exit 1; }
	./$(SAN_TARGET) $(IMG) $(STEPS)

$(SAN_TARGET): $(SRCS) $(wildcard csrc/*.h)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(SANFLAGS) $(CPPFLAGS) $(SRCS) -o $@

syntax:
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -fsyntax-only $(SRCS)

rtl: $(SIM_EXE)

$(SIM_STAMP): $(RTL_VSRC) $(SIM_MAIN) $(CSRC_H) Makefile
	@mkdir -p $(dir $@)
	$(VERILATOR) $(RTL_FLAGS) --top-module $(RTL_TOP) --Mdir $(dir $@) \
		$(SIM_MAIN) $(RTL_VSRC) -CFLAGS -I$(abspath csrc)
	@touch $@

$(SIM_EXE): $(SIM_STAMP) $(SIM_MAIN)
	$(MAKE) -C $(dir $(SIM_STAMP)) -f V$(RTL_TOP).mk

$(DIFF_STAMP): $(RTL_VSRC) $(DIFF_MAIN) $(EMU_LIB) $(CSRC_H) Makefile
	@mkdir -p $(dir $@)
	$(VERILATOR) $(RTL_FLAGS) --top-module $(RTL_TOP) --Mdir $(dir $@) \
		$(DIFF_MAIN) $(EMU_LIB) $(RTL_VSRC) -CFLAGS -I$(abspath csrc)
	@touch $@

$(DIFF_EXE): $(DIFF_STAMP) $(DIFF_MAIN) $(EMU_LIB)
	$(MAKE) -C $(dir $(DIFF_STAMP)) -f V$(RTL_TOP).mk

sim: $(SIM_EXE)
	@test -n "$(IMG)" || { echo "usage: make sim IMG=<image> [STEPS=<n>]"; exit 1; }
	./$(SIM_EXE) +BIN=$(IMG) +STEPS=$(STEPS)

difftest: $(DIFF_EXE)
	@test -n "$(IMG)" || { echo "usage: make difftest IMG=<image> [STEPS=<n>]"; exit 1; }
	./$(DIFF_EXE) +BIN=$(IMG) +STEPS=$(STEPS) $(if $(filter-out 0,$(TRACE)),+TRACE,)

lint:
	$(VERILATOR) $(LINTFLAGS) --top-module $(RTL_TOP) $(RTL_VSRC)

clean:
	rm -rf $(BUILD_DIR)

help:
	@sed -n '2,27p' Makefile
