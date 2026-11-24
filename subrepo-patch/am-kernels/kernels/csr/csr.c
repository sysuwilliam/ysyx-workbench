#include <am.h>
#include <klib-macros.h>

static inline uint32_t csr_mvendorid(void) {
  uint32_t v;
  asm volatile("csrr %0, mvendorid" : "=r"(v));
  return v;
}

static inline uint32_t csr_marchid(void) {
  uint32_t v;
  asm volatile("csrr %0, marchid" : "=r"(v));
  return v;
}

static inline uint64_t csr_mcycle64(void) {
  uint32_t hi, lo, hi2;
  do {
    asm volatile("csrr %0, mcycleh" : "=r"(hi));
    asm volatile("csrr %0, mcycle" : "=r"(lo));
    asm volatile("csrr %0, mcycleh" : "=r"(hi2));
  } while (hi != hi2);
  return ((uint64_t)hi << 32) | lo;
}

static void put_hex(uint32_t v) {
  putstr("0x");
  for (int i = 28; i >= 0; i -= 4)
    putch("0123456789abcdef"[(v >> i) & 15]);
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
  uint32_t vendor = csr_mvendorid();
  uint32_t arch = csr_marchid();
  uint64_t t0 = csr_mcycle64();

  volatile int acc = 0;
  for (int i = 0; i < 10000; i++) {
    acc += i;
  }

  uint64_t t1 = csr_mcycle64();
  uint32_t delta = (uint32_t)(t1 - t0);

  putstr("mvendorid = ");
  put_hex(vendor);
  putch('\n');
  putstr("marchid   = ");
  put_dec(arch);
  putstr(" (");
  put_hex(arch);
  putstr(")\n");
  putstr("mcycle    = ");
  put_dec((uint32_t)t0);
  putstr(" -> ");
  put_dec((uint32_t)t1);
  putstr(", delta = ");
  put_dec(delta);
  putch('\n');
  putstr("acc       = ");
  put_dec((uint32_t)acc);
  putch('\n');

  if (vendor != 0x79737978u)
    return 1;
  if (arch != 22040000u)
    return 2;
  if (delta == 0)
    return 3;
  return 0;
}
