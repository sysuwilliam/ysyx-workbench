TB        ?= main

ifeq ($(TB),test)
  NVBOARD := 0
endif

TOP       := keyboard
VSRC      := $(abspath $(wildcard vsrc/*.v))
CSRC      := $(abspath csrc/$(TB).cpp)
BUILD_DIR := build/$(TB)

include ../common.mk
