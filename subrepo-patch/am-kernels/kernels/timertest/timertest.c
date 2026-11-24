#include <am.h>
#include <klib-macros.h>

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
  uint32_t t0 = (uint32_t)io_read(AM_TIMER_UPTIME).us;
  putstr("start uptime = ");
  put_dec(t0);
  putstr(" us\n");

  for (int i = 1; i <= 3; i++) {
    uint32_t target = t0 + (uint32_t)i * 1000000u;
    while ((uint32_t)io_read(AM_TIMER_UPTIME).us < target) {
    }
    uint32_t t = (uint32_t)io_read(AM_TIMER_UPTIME).us;
    putstr("uptime = ");
    put_dec(t);
    putstr(" us\n");
  }
  putstr("timer ok\n");
  return 0;
}
