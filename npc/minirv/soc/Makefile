VERILATOR ?= verilator
ROOT      := ../../..
PERIP     := $(ROOT)/ysyxSoC/perip
SIMTOP    := $(ROOT)/ysyxSoC/ready-to-run/minirv/ElaborateTop.v
PERIP_SRC := $(shell find $(PERIP) -name '*.v' -o -name '*.sv')
RTL       := ../vsrc/top/ysyx_00000000.v $(wildcard ../vsrc/middle/*.v) $(wildcard ../vsrc/base/*.v)
BUILD     := obj_dir
EXE       := $(BUILD)/VSimTop

all: $(EXE)

$(EXE): sim_main.cpp $(SIMTOP) $(PERIP_SRC) $(RTL)
	$(VERILATOR) --cc --exe --build -j 0 --top-module SimTop \
		--timescale "1ns/1ns" --no-timing -Wno-PROCASSWIRE \
		-D__VERILOG__ -DPDK_BEHAV -D__UART_TO_CONSOLE__ \
		-I$(PERIP)/uart16550/rtl -I$(PERIP)/spi/rtl \
		--Mdir $(BUILD) -o VSimTop \
		$(SIMTOP) $(PERIP_SRC) $(RTL) sim_main.cpp

run: $(EXE)
	./$(EXE)

clean:
	rm -rf $(BUILD)

.PHONY: all run clean
