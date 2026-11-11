# npc/minirv/Makefile —— minirvEMU 的构建与调试
#
# 用法：
#   make                                    构建 build/minirvEMU
#   make images                             由 tests/*.txt 生成 tests/*.bin
#   make run IMG=<镜像> [STEPS=<步数>]      运行
#   make debug                              构建带调试信息的版本
#   make gdb IMG=<镜像> [STEPS=<步数>]      用 gdb 打开，断在译码函数
#   make asan IMG=<镜像> [STEPS=<步数>]     用 ASan/UBSan 构建并运行
#   make syntax                             只查语法与警告，不产出文件
#   make clean                              删除 build/
#
# 参数：
#   IMG     镜像路径，run/gdb/asan 必填
#   STEPS   步数上限，缺省 100000，与程序内默认值一致

CXX       ?= g++
CXXFLAGS  ?= -std=c++17 -Wall -Wextra -Wpedantic -O2
DBGFLAGS  := -g -O0
SANFLAGS  := -g -O1 -fsanitize=address,undefined
CPPFLAGS  := -Icsrc

BUILD_DIR := build
SRCS      := $(wildcard csrc/*.cpp)
OBJS      := $(patsubst csrc/%.cpp,$(BUILD_DIR)/%.o,$(SRCS))
DEPS      := $(OBJS:.o=.d)
TARGET    := $(BUILD_DIR)/minirvEMU

DBG_TARGET := $(BUILD_DIR)/debug/minirvEMU
SAN_TARGET := $(BUILD_DIR)/asan/minirvEMU

MKIMG     := tools/mkbin.py
IMG_SRCS  := $(wildcard tests/*.txt)
IMG_BINS  := $(IMG_SRCS:.txt=.bin)

STEPS     ?= 100000

.DEFAULT_GOAL := all
.PHONY: all images run debug gdb asan syntax clean help

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

clean:
	rm -rf $(BUILD_DIR)

help:
	@sed -n '2,16p' Makefile
