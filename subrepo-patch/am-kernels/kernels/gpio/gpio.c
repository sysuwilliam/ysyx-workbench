#include <am.h>
#include <klib-macros.h>

int main(const char *args) {
  volatile unsigned int *led = (volatile unsigned int *)0x20001000ul;
  volatile unsigned int *sw  = (volatile unsigned int *)0x20001004ul;
  volatile unsigned int *seg = (volatile unsigned int *)0x20001008ul;

  if (args != 0 && args[0] == 's') {
    *seg = 0x075BCD15u;
    putstr("seg\n");
    return 0;
  }

  if (args != 0 && args[0] == 't') {
    *led = 0x1234u;
    *seg = 0x075BCD15u;
    unsigned int l = *led;
    unsigned int g = *seg;
    unsigned int w = *sw;
    if ((l & 0xffffu) == 0x1234u && g == 0x075BCD15u)
      putstr("gpio ok\n");
    else
      putstr("gpio bad\n");
    return (w & 0xffffu) == 0xffffu;
  }

  if (args != 0 && args[0] == 'l') {
    while ((*sw & 0xffffu) != 0x1234u) {
    }
    *led = 0xffffu;
    putstr("unlocked\n");
    return 0;
  }

  for (int i = 0;; i = (i + 1) & 15) {
    *led = 1u << i;
    for (volatile int j = 0; j < 200000; j++) {
    }
  }
}
