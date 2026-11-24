#include <am.h>
#include <klib-macros.h>

#define VGA_BASE 0x21000000u
#define VIDEO_FLASH_BASE 0x30100000u

#ifndef FPS
#define FPS 30
#endif
#ifndef FRAMES
#define FRAMES 6500
#endif

typedef struct {
  uint32_t word[600];
} frame_t;

static inline uint32_t read_mcycle(void) {
  uint32_t v;
  asm volatile("csrr %0, mcycle" : "=r"(v));
  return v;
}

static inline uint32_t read_mcycleh(void) {
  uint32_t v;
  asm volatile("csrr %0, mcycleh" : "=r"(v));
  return v;
}

static inline uint64_t read_mcycle64(void) {
  uint32_t hi, lo, hi2;
  do {
    hi = read_mcycleh();
    lo = read_mcycle();
    hi2 = read_mcycleh();
  } while (hi != hi2);
  return ((uint64_t)hi << 32) | lo;
}

static void put_dec(uint32_t v) {
  char buf[11];
  int n = 0;
  if (v == 0) {
    putch('0');
    return;
  }
  while (v != 0) {
    buf[n++] = '0' + (v % 10);
    v /= 10;
  }
  while (n != 0)
    putch(buf[--n]);
}

int main(const char *args) {
  (void)args;
  volatile uint32_t *vga = (volatile uint32_t *)VGA_BASE;
  const volatile frame_t *f = (const volatile frame_t *)VIDEO_FLASH_BASE;
  uint32_t frame_cycles = 25000000u / FPS;
  uint64_t next = read_mcycle64() + frame_cycles;

  putstr("bad apple 160x120 start\n");

  for (int n = 0; n < FRAMES; n++, f++) {
    for (int i = 0; i < 600; i++)
      vga[i] = f->word[i];

    if ((n % 300) == 0) {
      putstr("frame ");
      put_dec((uint32_t)n);
      putch('\n');
    }

    while (read_mcycle64() < next) {
    }
    next += frame_cycles;
  }

  putstr("bad apple 160x120 done, frames=");
  put_dec(FRAMES);
  putch('\n');
  return 0;
}
