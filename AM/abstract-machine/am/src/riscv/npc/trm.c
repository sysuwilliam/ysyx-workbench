#include <am.h>
#include <klib-macros.h>

extern char _heap_start;
int main(const char *args);

extern char _pmem_start;
#define PMEM_SIZE (128 * 1024 * 1024)
#define PMEM_END  ((uintptr_t)&_pmem_start + PMEM_SIZE)

Area heap = RANGE(&_heap_start, PMEM_END);
static const char mainargs[MAINARGS_MAX_LEN] = TOSTRING(MAINARGS_PLACEHOLDER); // defined in CFLAGS

#if defined(__PLATFORM_YSYXSOC)
static void uart_init(void) {
  volatile unsigned char *base = (volatile unsigned char *)0x10000000ul;
  base[3] = 0x83;
  base[0] = 13;
  base[1] = 0;
  base[3] = 0x03;
  base[2] = 0x07;
}
#endif

void putch(char ch) {
#if defined(__PLATFORM_YSYXSOC)
  volatile unsigned char *base = (volatile unsigned char *)0x10000000ul;
  while ((base[5] & 0x20) == 0) {
  }
  base[0] = ch;
#else
  volatile unsigned int *status = (volatile unsigned int *)0x10000004ul;
  volatile char *data = (volatile char *)0x10000000ul;
  while ((*status & 1) == 0) {
  }
  *data = ch;
#endif
}

void halt(int code) {
  asm volatile("mv a0, %0; ebreak" : : "r"(code));
  while (1);
}

void _trm_init() {
#if defined(__PLATFORM_YSYXSOC)
  uart_init();
#endif
  int ret = main(mainargs);
  halt(ret);
}
