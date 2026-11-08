TB        ?= main

ifeq ($(TB),test)
  TOP     := sCPU
  NVBOARD := 0
else
  TOP     := sCPU_board
endif

VSRC      := $(abspath $(wildcard vsrc/*.v vsrc/*/*.v))
CSRC      := $(abspath $(wildcard csrc/$(TB).cpp))
BUILD_DIR := build/$(TB)

include ../lab/common.mk
