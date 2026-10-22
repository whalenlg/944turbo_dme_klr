// ============================================================
//  replay_main.cpp — open-loop log replay driver for
//  dme_klr_dashboard_tb (-DLIVE)
//
//  Drives the combined DME+KLR model's inputs from a stimulus CSV
//  (made by xlsx_to_stim.py from a recorded car log) instead of the
//  closed-loop engine model: RPM, AFM, boost and every ADC channel
//  are pinned through the same live_* registers the live debugger
//  uses, row by row at the row's timestamp.
//
//  Usage:  dme_klr_replay <stim.csv> [+warmup_ms=<ms>] [+fst=/dev/null]
//
//  The CSV's first column is t_ms (log time, ms); every other column
//  names an input from the table below and holds its raw value
//  (decimal or 0x-hex; "auto" leaves it on the model). The first row is
//  applied at t=0 and held for warmup_ms (default 3000) so the
//  firmware can sync and settle; the log then plays from there.
//
//  At each row's time the driver prints
//    SIM: [ROW] idx=<row> log_ms=<t_ms> t_ns=<sim time>
//  and requests a DME:/KLR: [DS] snapshot (emitted on the next DME
//  clock, before any later ROW line), then applies that row's inputs.
//  check_replay.py pairs each snapshot with the log's expected
//  outputs. Everything else the testbench prints (SIM: [IGN], [INJ],
//  DME: [STATUS] ...) passes through unchanged.
// ============================================================

#include "Vdme_klr_dashboard_tb.h"
#include "Vdme_klr_dashboard_tb___024root.h"
#include "Vdme_klr_dashboard_tb_dme_klr_dashboard_tb.h"
#include "verilated.h"

#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#define TB(sig) (root->dme_klr_dashboard_tb->sig)

namespace {

struct Input {
    const char* name;
    void* ptr;
    int bits;          // 8 or 16
    bool can_auto;     // 16'hFFFF = follow the model
};

struct Row {
    double t_ms;
    std::vector<long> vals;   // one per mapped column; -1 = auto
};

class Replay {
public:
    Replay(int argc, char** argv) {
        ctx_ = std::make_unique<VerilatedContext>();
        ctx_->commandArgs(argc, argv);
        top_ = std::make_unique<Vdme_klr_dashboard_tb>(ctx_.get());
        root = top_->rootp;
        ns_per_tick_ = std::pow(10.0, ctx_->timeprecision() + 9);
        inputs_ = {
            {"tps",       &TB(live_tps),        8, false},
            {"rpm",       &TB(live_rpm),       16, true},
            {"afm",       &TB(live_afm),       16, true},
            {"boost",     &TB(live_boost),     16, true},
            {"coolant",   &TB(live_coolant),    8, false},
            {"airtemp",   &TB(live_airtemp),    8, false},
            {"battery",   &TB(live_battery),    8, false},
            {"altitude",  &TB(live_altitude),   8, false},
            {"fuel_qual", &TB(live_fuel_qual),  8, false},
            {"dme_tps",   &TB(live_dme_tps),   16, true},
            {"klr_tps",   &TB(live_klr_tps),   16, true},
            {"o2",        &TB(live_o2),        16, true},
            {"knock",     &TB(live_knock),     16, true},
        };
    }

    bool load(const std::string& path) {
        std::ifstream f(path);
        if (!f) return fail("cannot open " + path);
        std::string line;
        if (!std::getline(f, line)) return fail("empty stimulus file");
        auto hdr = split(line);
        if (hdr.empty() || hdr[0] != "t_ms") return fail("first column must be t_ms");
        for (size_t i = 1; i < hdr.size(); ++i) {
            Input* in = find(hdr[i]);
            if (!in) return fail("unknown input column: " + hdr[i]);
            cols_.push_back(in);
        }
        int lineno = 1;
        while (std::getline(f, line)) {
            ++lineno;
            if (line.empty() || line[0] == '#') continue;
            auto cells = split(line);
            if (cells.size() != hdr.size())
                return fail("line " + std::to_string(lineno) + ": expected " +
                            std::to_string(hdr.size()) + " columns");
            Row r;
            r.t_ms = std::strtod(cells[0].c_str(), nullptr);
            for (size_t i = 1; i < cells.size(); ++i) {
                long v;
                if (!parse(*cols_[i - 1], cells[i], v))
                    return fail("line " + std::to_string(lineno) + ": bad " + hdr[i] + " value " + cells[i]);
                r.vals.push_back(v);
            }
            if (!rows_.empty() && r.t_ms < rows_.back().t_ms)
                return fail("line " + std::to_string(lineno) + ": t_ms goes backwards");
            rows_.push_back(std::move(r));
        }
        if (rows_.empty()) return fail("no stimulus rows");
        return true;
    }

    int run(double warmup_ms) {
        const double offset_ns = warmup_ms * 1e6 - rows_[0].t_ms * 1e6;
        const double end_ns = rows_.back().t_ms * 1e6 + offset_ns;
        printf("SIM: [REPLAY] rows=%zu warmup_ms=%.0f log_ms=%.3f..%.3f\n", rows_.size(), warmup_ms,
               rows_[0].t_ms, rows_.back().t_ms);
        top_->eval();         // initial blocks set the live_* defaults first
        apply(rows_[0]);
        size_t next = 0;
        auto wall0 = std::chrono::steady_clock::now();
        auto last_tick = wall0;
        uint64_t iter = 0;
        while (!ctx_->gotFinish() && top_->eventsPending()) {
            double now = tNs();
            while (next < rows_.size() && now >= rows_[next].t_ms * 1e6 + offset_ns) {
                printf("SIM: [ROW] idx=%zu log_ms=%.3f t_ns=%.0f\n", next, rows_[next].t_ms, now);
                TB(live_snap_req) = TB(live_snap_req) + 1;
                apply(rows_[next]);
                ++next;
            }
            if (next == rows_.size() && now >= end_ns && TB(live_snap_ack) == TB(live_snap_req)) break;
            ctx_->time(top_->nextTimeSlot());
            top_->eval();
            if ((++iter & 0xFFFF) == 0) {
                auto t = std::chrono::steady_clock::now();
                if (std::chrono::duration<double>(t - last_tick).count() >= 10.0) {
                    double wall = std::chrono::duration<double>(t - wall0).count();
                    fprintf(stderr, "replay: sim %.1f / %.1f s, row %zu/%zu, %.1f sim ms per wall s\n",
                            tNs() / 1e9, end_ns / 1e9, next, rows_.size(), tNs() / 1e6 / wall);
                    last_tick = t;
                }
            }
        }
        top_->final();
        printf("SIM: [REPLAY] done t_ns=%.0f rows_played=%zu\n", tNs(), next);
        return next == rows_.size() ? 0 : 1;
    }

private:
    std::unique_ptr<VerilatedContext> ctx_;
    std::unique_ptr<Vdme_klr_dashboard_tb> top_;
    Vdme_klr_dashboard_tb___024root* root;
    double ns_per_tick_;
    std::vector<Input> inputs_;
    std::vector<Input*> cols_;
    std::vector<Row> rows_;

    double tNs() const { return ctx_->time() * ns_per_tick_; }

    Input* find(const std::string& name) {
        for (auto& in : inputs_)
            if (name == in.name) return &in;
        return nullptr;
    }

    static bool parse(const Input& in, const std::string& s, long& v) {
        if (s == "auto") {
            if (!in.can_auto) return false;
            v = 0xFFFF;
            return true;
        }
        char* end = nullptr;
        v = std::strtol(s.c_str(), &end, 0);
        if (s.empty() || *end) return false;
        return v >= 0 && v <= (in.bits == 8 ? 0xFF : 0xFFFF);
    }

    void apply(const Row& r) {
        for (size_t i = 0; i < cols_.size(); ++i) {
            if (cols_[i]->bits == 8) *static_cast<uint8_t*>(cols_[i]->ptr) = static_cast<uint8_t>(r.vals[i]);
            else *static_cast<uint16_t*>(cols_[i]->ptr) = static_cast<uint16_t>(r.vals[i]);
        }
    }

    static std::vector<std::string> split(const std::string& line) {
        std::vector<std::string> out;
        std::stringstream ss(line);
        std::string cell;
        while (std::getline(ss, cell, ',')) {
            while (!cell.empty() && (cell.back() == '\r' || cell.back() == ' ')) cell.pop_back();
            while (!cell.empty() && cell.front() == ' ') cell.erase(0, 1);
            out.push_back(cell);
        }
        return out;
    }

    static bool fail(const std::string& msg) {
        fprintf(stderr, "replay: %s\n", msg.c_str());
        return false;
    }
};

}  // namespace

int main(int argc, char** argv) {
    setvbuf(stdout, nullptr, _IOFBF, 1 << 20);
    std::string stim;
    double warmup_ms = 3000;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        if (a.rfind("+warmup_ms=", 0) == 0) warmup_ms = std::strtod(a.c_str() + 11, nullptr);
        else if (a[0] != '+' && stim.empty()) stim = a;
    }
    if (stim.empty()) {
        fprintf(stderr, "usage: %s <stim.csv> [+warmup_ms=<ms>] [+fst=/dev/null]\n", argv[0]);
        return 2;
    }
    Replay r(argc, argv);
    if (!r.load(stim)) return 2;
    int rc = r.run(warmup_ms);
    fflush(stdout);
    return rc;
}
