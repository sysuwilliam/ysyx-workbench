VERILATOR ?= verilator
V ?= 0
ifeq ($(V),1)
Q :=
else
Q := @
endif
DEBUG     ?= 0
ifeq ($(DEBUG),1)
VERILATOR_DEBUG := -DYSYX_DEBUG
endif
ROOT      := ../../..
NVBOARD_HOME ?= $(ROOT)/nvboard
export NVBOARD_HOME
include $(NVBOARD_HOME)/scripts/nvboard.mk
.DEFAULT_GOAL := all
PERIP     := $(ROOT)/ysyxSoC/perip
SIMTOP    := $(ROOT)/ysyxSoC/ready-to-run/minirv/ElaborateTop.v
PERIP_SRC := $(shell find $(PERIP) -name '*.v' -o -name '*.sv')
RTL       := ../vsrc/top/ysyx_00000000.v $(wildcard ../vsrc/middle/*.v) $(wildcard ../vsrc/base/*.v)
BUILD     := obj_dir
EXE       := $(BUILD)/VSimTop

all: $(EXE)

$(EXE): sim_main.cpp $(SIMTOP) $(PERIP_SRC) $(RTL)
	@printf '%b' '\033[1;36m[VERILATOR]\033[0m building SimTop ...\n'
	$(Q)$(VERILATOR) --cc --exe --build -j 0 --top-module SimTop \
		--timescale "1ns/1ns" --no-timing -Wno-PROCASSWIRE \
		-D__VERILOG__ -DPDK_BEHAV -D__UART_TO_CONSOLE__ $(VERILATOR_DEBUG) \
		-I$(PERIP)/uart16550/rtl -I$(PERIP)/spi/rtl \
		--Mdir $(BUILD) -o VSimTop \
		$(SIMTOP) $(PERIP_SRC) $(RTL) sim_main.cpp
	@printf '%b' '\033[1;32m[BUILD]\033[0m $(EXE)\n'

ARGS ?=
run: $(EXE)
	./run_color.sh $(ARGS)

NXDC      := constr/SimTop.nxdc
AUTO_BIND := obj_dir/auto_bind.cpp
NV_BUILD  := obj_dir_nvboard
NV_EXE    := $(NV_BUILD)/VSimTop_nvboard

$(AUTO_BIND): $(NXDC)
	@mkdir -p $(dir $@)
	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $< $@

$(NV_EXE): nvboard_main.cpp $(SIMTOP) $(PERIP_SRC) $(RTL) $(AUTO_BIND) $(NVBOARD_ARCHIVE)
	@printf '%b' '\033[1;36m[VERILATOR]\033[0m building SimTop + NVBoard ...\n'
	$(Q)$(VERILATOR) --cc --exe --build -j 0 --top-module SimTop \
		--timescale "1ns/1ns" --no-timing -Wno-PROCASSWIRE \
		-D__VERILOG__ -DPDK_BEHAV -D__UART_TO_CONSOLE__ $(VERILATOR_DEBUG) \
		-CFLAGS -I$(NVBOARD_HOME)/usr/include \
		-I$(PERIP)/uart16550/rtl -I$(PERIP)/spi/rtl \
		--Mdir $(NV_BUILD) -o VSimTop_nvboard \
		$(SIMTOP) $(PERIP_SRC) $(RTL) nvboard_main.cpp $(AUTO_BIND) $(NVBOARD_ARCHIVE) \
		-LDFLAGS "$(LDFLAGS)"
	@printf '%b' '\033[1;32m[BUILD]\033[0m $(NV_EXE)\n'

nvboard: $(NV_EXE)

run-nvboard: $(NV_EXE)
	NVBOARD_HOME=$(NVBOARD_HOME) ./$(NV_EXE) $(ARGS)

clean:
	rm -rf $(BUILD) $(NV_BUILD)

.PHONY: all run nvboard run-nvboard clean
