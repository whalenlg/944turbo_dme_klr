// ============================================================
//  live_fields.h — the model's variables as a list of byte ranges
//
//  liveFields() (obj/live_fields.cpp, written by gen_state.py at build
//  time) calls liveAdd() for every member of every module instance.
//  Plain data (CData..QData, VlWide, VlUnpacked, double, Verilator's
//  trigger vectors) is kept; pointers and the timing schedulers, which
//  hold coroutine handles, are skipped: snapshot.h deals with those.
// ============================================================
#pragma once

#include <cstddef>
#include <string>
#include <type_traits>
#include <vector>

struct LiveField {
    std::string name;   // "<instance>.<member>", as in the generated headers
    void* ptr;
    size_t size;
};
using LiveFieldList = std::vector<LiveField>;

template <typename T>
inline void liveAdd(LiveFieldList& v, const char* name, T& x) {
    using U = std::remove_cv_t<T>;
    if constexpr (std::is_trivially_copyable_v<U> && !std::is_pointer_v<U> && !std::is_const_v<T>)
        v.push_back({name, const_cast<U*>(&x), sizeof(U)});
}

class Vdme_klr_dashboard_tb__Syms;
void liveFields(Vdme_klr_dashboard_tb__Syms* s, LiveFieldList& v);
