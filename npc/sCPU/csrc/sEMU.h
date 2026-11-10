#ifndef __SEMU_H__
#define __SEMU_H__

#include <stdint.h>

void ref_reset(void);

void ref_load(const uint8_t *prog, int len);

void ref_set_sw(uint8_t v);

void ref_inst_cycle(void);

uint8_t ref_get_pc(void);

const uint8_t *ref_get_regs(void);

#endif
