// ============================================================
//  live_printf.h — route the model's $display / $write through the
//  driver. build_live.sh compiles Verilator's runtime (verilated.cpp,
//  where $display ends up) with -include of this file, so its VL_PRINTF
//  (verilated.h: "redefine if desired") is live_printf, defined in
//  sim_main.cpp. It prints the text to stdout unchanged and lets the
//  driver see each line, which is how it spots warnings the moment the
//  testbench prints them. (Only the runtime: force-including it into the
//  model's own files would stop their precompiled header being used.)
// ============================================================
#pragma once

int live_printf(const char* fmt, ...) __attribute__((format(printf, 1, 2)));
#define VL_PRINTF live_printf
