// ============================================================
//  snapshot.h — save / restore the whole Verilated model
//
//  The variables come from liveFields() (gen_state.py): every signal,
//  memory, ROM array and Verilator temporary, as raw bytes. What raw
//  bytes can't hold is the --timing scheduler: each process waiting on
//  a #delay is a C++ coroutine. A restore starts from a fresh process,
//  so its coroutines already exist; they only need the wake-up times
//  the saved process had. This file reads and rewrites those times.
//
//  That works when every waiting coroutine is at a point the fresh
//  process also reaches: the clock generators and other `always #N`
//  loops, and the `#SIM_TIME` waits. A coroutine stopped part way
//  through a block (the KLR core's `#10 display_read_status(...)`, a
//  pending `x <= #d y`) has state only inside its frame, so a save
//  waits for a moment with none of those ("quiescent"). The set of
//  always-present coroutines is learned at the start of each run
//  (Census below). Coroutines are told apart by their resume function
//  (the first word of the frame, for both GCC and Clang), stored as an
//  offset from liveFields() so it is the same in every run of a build.
// ============================================================
#pragma once

#include "live_fields.h"
#include "verilated.h"
#include "verilated_timing.h"

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <map>
#include <string>
#include <utility>
#include <vector>

// ── Private members of the timing scheduler ─────────────────
// (explicit instantiation may name private members; this is the
// standard way to reach them without editing Verilator's headers)
template <typename Tag, typename Tag::type M>
struct LiveRob {
    friend typename Tag::type liveGet(Tag) { return M; }
};
struct LiveDlyQueueTag {
    using type = std::multimap<uint64_t, VlCoroutineHandle> VlDelayScheduler::*;
    friend type liveGet(LiveDlyQueueTag);
};
template struct LiveRob<LiveDlyQueueTag, &VlDelayScheduler::m_queue>;
struct LiveCoroTag {
    using type = std::coroutine_handle<> VlCoroutineHandle::*;
    friend type liveGet(LiveCoroTag);
};
template struct LiveRob<LiveCoroTag, &VlCoroutineHandle::m_coro>;

// One waiting coroutine: wake-up time (model ticks) and which code it is
struct LiveDelay {
    uint64_t key;
    int64_t fn;
};

inline int64_t liveCoroFn(const VlCoroutineHandle& h) {
    void* frame = (h.*liveGet(LiveCoroTag{})).address();
    if (!frame) return 0;
    auto resume = reinterpret_cast<uintptr_t>(*static_cast<void**>(frame));
    return static_cast<int64_t>(resume - reinterpret_cast<uintptr_t>(&liveFields));
}

inline std::vector<LiveDelay> liveDelays(VlDelayScheduler& s) {
    std::vector<LiveDelay> out;
    for (auto& [key, h] : s.*liveGet(LiveDlyQueueTag{})) out.push_back({key, liveCoroFn(h)});
    return out;
}

// Count of waiting coroutines per resume function
using LiveCensus = std::map<int64_t, int>;
inline LiveCensus liveCensus(const std::vector<LiveDelay>& d) {
    LiveCensus c;
    for (auto& e : d) ++c[e.fn];
    return c;
}

// Give the fresh process's coroutines the saved wake-up times. Each
// resume function's entries are paired in time order with the saved
// ones. If the saved coroutines aren't the same functions (another build
// of the simulator), every entry is shifted by the same amount instead,
// which keeps each clock's period but not its phase. Returns true when
// the times were matched exactly.
inline bool liveRemapDelays(VlDelayScheduler& s, const std::vector<LiveDelay>& saved,
                            uint64_t savedNow, uint64_t now) {
    auto& q = s.*liveGet(LiveDlyQueueTag{});
    std::vector<LiveDelay> mine = liveDelays(s);
    bool exact = liveCensus(mine) == liveCensus(saved);
    std::map<int64_t, std::vector<uint64_t>> want;
    for (auto& e : saved) want[e.fn].push_back(e.key);
    for (auto& [fn, keys] : want) std::sort(keys.begin(), keys.end());
    std::map<int64_t, size_t> used;
    std::vector<std::pair<uint64_t, std::multimap<uint64_t, VlCoroutineHandle>::node_type>> moved;
    while (!q.empty()) {
        auto node = q.extract(q.begin());   // ascending key, so pairing is in time order
        int64_t fn = liveCoroFn(node.mapped());
        uint64_t key = node.key() - now + savedNow;
        if (exact) key = want[fn][used[fn]++];
        moved.emplace_back(key, std::move(node));
    }
    for (auto& [key, node] : moved) {
        node.key() = key;
        q.insert(std::move(node));
    }
    return exact;
}

// The coroutines that are always waiting on a delay in this build,
// learned from the first `kSamples` time slots after `kStartNs`: the
// smallest count of each resume function seen in any of them.
struct LiveReference {
    static constexpr uint64_t kStartNs = 20000;   // past the reset-time initial blocks
    static constexpr int kSamples = 4096;
    LiveCensus ref;
    int samples = 0;
    bool ready() const { return samples >= kSamples; }
    void sample(const std::vector<LiveDelay>& d) {
        LiveCensus c = liveCensus(d);
        if (samples == 0) {
            ref = c;
        } else {
            for (auto& [fn, n] : ref) {
                auto it = c.find(fn);
                n = std::min(n, it == c.end() ? 0 : it->second);
            }
        }
        if (++samples == kSamples)
            for (auto it = ref.begin(); it != ref.end();) it = it->second ? std::next(it) : ref.erase(it);
    }
};

// FNV-1a over field names and sizes: a snapshot only loads into a build
// with the same variables
inline uint64_t liveLayoutHash(const LiveFieldList& f) {
    uint64_t h = 1469598103934665603ULL;
    auto mix = [&](const std::string& s) {
        for (unsigned char ch : s) { h ^= ch; h *= 1099511628211ULL; }
    };
    for (auto& x : f) mix(x.name + ":" + std::to_string(x.size) + ";");
    return h;
}

inline uint32_t liveCrc32(const uint8_t* p, size_t n) {
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < n; ++i) {
        c ^= p[i];
        for (int k = 0; k < 8; ++k) c = (c >> 1) ^ (0xEDB88320u & (0u - (c & 1u)));
    }
    return ~c;
}

inline std::string liveJson(const std::string& s) {
    std::string o = "\"";
    for (unsigned char ch : s) {
        if (ch == '"' || ch == '\\') { o += '\\'; o += static_cast<char>(ch); }
        else if (ch == '\n') o += "\\n";
        else if (ch == '\t') o += "\\t";
        else if (ch < 0x20) { char b[8]; snprintf(b, sizeof b, "\\u%04x", ch); o += b; }
        else o += static_cast<char>(ch);
    }
    return o + "\"";
}

inline std::string liveHexBytes(const void* p, size_t n) {
    static const char* d = "0123456789abcdef";
    std::string s;
    s.reserve(n * 2);
    for (size_t i = 0; i < n; ++i) {
        uint8_t b = static_cast<const uint8_t*>(p)[i];
        s += d[b >> 4];
        s += d[b & 15];
    }
    return s;
}
