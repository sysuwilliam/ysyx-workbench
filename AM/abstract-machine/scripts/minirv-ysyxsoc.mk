NPC_CPU_FREQ := 25000000
include $(AM_HOME)/scripts/minirv-npc.mk

image: image-dep
	cd $(AM_HOME)/../../ysyxSoC/ready-to-run/minirv && bash gen.sh $(IMAGE).elf $(IMAGE).bin

run: insert-arg
	$(AM_HOME)/../../npc/minirv/soc/run_color.sh $(IMAGE).bin +MAX_CYCLES=500000000
