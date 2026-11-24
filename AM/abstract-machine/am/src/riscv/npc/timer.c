#include <am.h>

#ifndef NPC_CPU_FREQ
#define NPC_CPU_FREQ 25000000u
#endif

#define NPC_CYCLES_PER_US (NPC_CPU_FREQ / 1000000u)

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

void __am_timer_init() {
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime) {
  uint32_t hi, lo, hi2;
  do {
    hi = read_mcycleh();
    lo = read_mcycle();
    hi2 = read_mcycleh();
  } while (hi != hi2);
  uint64_t cycles = ((uint64_t)hi << 32) | lo;
  uptime->us = cycles / NPC_CYCLES_PER_US;
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc) {
  rtc->second = 0;
  rtc->minute = 0;
  rtc->hour   = 0;
  rtc->day    = 0;
  rtc->month  = 0;
  rtc->year   = 1900;
}
