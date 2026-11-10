TB        ?= main

ifneq (,$(filter test difftest,$(TB)))
  TOP     := sCPU
  NVBOARD := 0
else
  TOP     := sCPU_board
endif

VSRC      := $(abspath $(wildcard vsrc/*.v vsrc/*/*.v))
CSRC      := $(abspath $(wildcard csrc/$(TB).cpp))

ifeq ($(TB),difftest)
  CSRC += $(abspath csrc/sEMU.cpp)
endif

BUILD_DIR := build/$(TB)

include ../lab/common.mk
