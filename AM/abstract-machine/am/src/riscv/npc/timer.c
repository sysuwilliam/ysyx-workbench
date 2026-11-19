#include <am.h>

void __am_timer_init() {
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime) {
  volatile uint32_t *lo = (volatile uint32_t *)0x20000000ul;
  volatile uint32_t *hi = (volatile uint32_t *)0x20000004ul;
  uint32_t l = *lo;
  uint32_t h = *hi;
  uptime->us = ((uint64_t)h << 32) | l;
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc) {
  rtc->second = 0;
  rtc->minute = 0;
  rtc->hour   = 0;
  rtc->day    = 0;
  rtc->month  = 0;
  rtc->year   = 1900;
}
