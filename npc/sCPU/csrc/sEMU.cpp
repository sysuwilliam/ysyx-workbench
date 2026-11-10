#include "sEMU.h"

#include <cstring>

static uint8_t PC = 0;
static uint8_t R[4];
static uint8_t M[256];
static uint8_t sw = 0;

void ref_reset(void) {

    PC = 0;
    std::memset(R, 0, sizeof(R));

    sw = 0;
}

void ref_load(const uint8_t *prog, int len) {

    std::memset(M, 0, sizeof(M));

    for (int i = 0; i < len && i < 256; i++)
        M[i] = prog[i];
}

void ref_set_sw(uint8_t v) {

    sw = v;
}

uint8_t ref_get_pc(void) {

    return PC;
}

const uint8_t *ref_get_regs(void) {

    return R;
}

void ref_inst_cycle(void) {

    uint8_t instr = M[PC];

    uint8_t op = (instr >> 6) & 0x3;
    uint8_t rd = (instr >> 4) & 0x3;
    uint8_t rs1 = (instr >> 2) & 0x3;
    uint8_t rs2 = instr & 0x3;
    uint8_t s = (instr >> 2) & 0x3;
    uint8_t imm = instr & 0x3;
    uint8_t off = (instr >> 2) & 0xf;

    switch (op) {
        case 0:

            R[rd] = (uint8_t)(R[rs1] + R[rs2]);
            PC++;
            break;

        case 1: {

            uint8_t dir = (instr >> 3) & 0x1;
            if (dir == 0)
                R[rd] = sw;
            PC++;
            break;
        }

        case 2:

            R[rd] = (uint8_t)(imm << (s * 2));
            PC++;
            break;

        default:

            {
                int delta = (off & 0x8) ? (int)off - 16 : (int)off;
                if (R[rs2] != R[0])
                    PC = (uint8_t)(PC + delta);
                else
                    PC++;
            }
            break;
    }
}
