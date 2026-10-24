// ============================================================
//  sim_main.cpp — interactive driver for dme_klr_dashboard_tb (-DLIVE)
//
//  Runs the combined DME+KLR model and takes one command per line on
//  stdin. Everything the testbench prints (DME:/KLR: [DS], [PHASE],
//  [STATUS] ...) still goes to stdout unchanged; this driver adds its
//  own "SIM: [...]" lines. bridge.mjs relays both directions to the
//  web dashboard, but the binary is usable straight from a terminal.
//
//  Commands:
//    run                       free-run until pause / breakpoint / until
//    pause                     stop (emits a fresh DS snapshot first)
//    step dme|klr [N]          run N instructions of that CPU (default 1)
//    until <ms>                run until simulated time <ms>, then pause
//    set <input> <value>       change an input; value is dec, 0x-hex or
//                              "auto" (rpm/afm/boost follow the closed-loop
//                              engine model, which tps drives)
//    bp add|del dme|klr <hex>  set / clear a PC breakpoint
//    bp clear                  clear all breakpoints
//    snap                      emit a DS snapshot now (while paused too)
//    trace dme|klr [N]         print the last N instruction addresses
//    rom dme|klr <path>        while paused, replace that CPU's EPROM with a
//                              $readmemh-format .mem image (no rebuild; the
//                              CPU keeps its PC and RAM — restart for a
//                              clean boot). +dme_rom=<path> / +klr_rom=<path>
//                              on the command line load images at start.
//    status                    print state, time, PCs, inputs, breakpoints
//    quit
//
//  Output lines added by this driver:
//    SIM: [READY]  inputs=name=val,...
//    SIM: [STATE]  running|paused t_ns=<n> dme_pc=<hex> klr_pc=<hex> reason=<why>
//    SIM: [TIME]   t_ns=<n> rate=<sim ms per wall s>     (while running, ~1/s)
//    SIM: [INPUTS] name=val,...
//    SIM: [BP]     dme=<hex,...> klr=<hex,...>
//    SIM: [TRACE]  dme|klr <pc>/<ctx0>/<ctx1>/<ctx2>,...  (oldest first; ctx =
//                  registers as each instruction was fetched, see the tb)
//    SIM: [ROM]    dme|klr <path>                  (image in that EPROM: at start and
//                  after each rom command)
//    SIM: [ERROR]  <message>
//    SIM: [IGN]    dme|klr t_ns=<n> width_ns=<n>   (from the testbench, per spark)
//    SIM: [INJ]    t_ns=<n> width_ns=<n>           (injector low time on DME P1.0)
//    SIM: [TACH]   t_ns=<n> width_ns=<n>           (DME tach A_1 high time: its spark command to the KLR)
//    SIM: [REGS]   dme|klr t_ms=<n> name=hex ...   (CPU registers, with each snapshot)
//    SIM: [REGS]   dmestk t_ms=<n> stk=<tag>.<tag>...  (what wrote DME stack 64h..79h:
//                  c/C call lo/hi, i/I interrupt lo/hi, pXXXX PUSH at XXXX, - unknown)
// ============================================================

#include "Vdme_klr_dashboard_tb.h"
#include "Vdme_klr_dashboard_tb___024root.h"
#include "Vdme_klr_dashboard_tb_dme_klr_dashboard_tb.h"
#include "verilated.h"

#include <poll.h>
#include <unistd.h>

#include <chrono>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <deque>
#include <fstream>
#include <iostream>
#include <map>
#include <memory>
#include <set>
#include <sstream>
#include <string>
#include <vector>

// The public regs declared under `ifdef LIVE in dme_klr_dashboard_tb.v
#define TB(sig) (root->dme_klr_dashboard_tb->sig)

namespace {

struct Input {
    const char* name;
    void* ptr;
    int bits;          // 8 or 16
    bool can_auto;     // 16'hFFFF = follow the model
};

class LiveSim {
public:
    LiveSim(int argc, char** argv) {
        ctx_ = std::make_unique<VerilatedContext>();
        ctx_->commandArgs(argc, argv);
        top_ = std::make_unique<Vdme_klr_dashboard_tb>(ctx_.get());
        root = top_->rootp;
        // ctx time is in units of the model's time precision (10 ps here)
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

    int run() {
        // Evaluate time 0 so initial blocks run and inputs hold their defaults
        top_->eval();
        rom_[0] = widePath(TB(live_dme_rom_path));
        rom_[1] = widePath(TB(live_klr_rom_path));
        // Images from +dme_rom= / +klr_rom= replace the compiled-in ones
        // before the CPUs leave reset (DME res_n rises at 1 us)
        for (int c = 0; c < 2; ++c) {
            std::string arg = ctx_->commandArgsPlusMatch(c ? "klr_rom=" : "dme_rom=");
            if (!arg.empty()) loadRom(c, arg.substr(arg.find('=') + 1));
        }
        romLines();
        printf("SIM: [READY] %s\n", inputsLine().c_str());
        state("paused", "start");
        while (!ctx_->gotFinish() && !quit_) {
            if (paused_) {
                std::string line;
                if (!std::getline(std::cin, line)) break;
                command(line);
                continue;
            }
            if ((++iter_ & 0xFFF) == 0) pollInput();
            if (paused_ || quit_) continue;
            if (!top_->eventsPending()) break;
            ctx_->time(top_->nextTimeSlot());
            top_->eval();
            afterEval();
        }
        top_->final();
        state("paused", ctx_->gotFinish() ? "finish" : "quit");
        return 0;
    }

private:
    std::unique_ptr<VerilatedContext> ctx_;
    std::unique_ptr<Vdme_klr_dashboard_tb> top_;
    Vdme_klr_dashboard_tb___024root* root;
    double ns_per_tick_;
    std::vector<Input> inputs_;

    bool paused_ = true, quit_ = false;
    std::string stop_reason_;    // set when a stop is pending a snapshot
    bool stop_pending_ = false;
    uint64_t iter_ = 0;

    std::set<uint32_t> bp_dme_, bp_klr_;
    long step_dme_ = 0, step_klr_ = 0;
    double until_ns_ = -1;

    uint32_t last_dme_ic_ = 0, last_klr_ic_ = 0;
    // One traced instruction: its address and the register context the
    // testbench captured as it was fetched (see live_*_ctx* in the tb)
    struct Step { uint16_t pc; uint64_t c0, c1, c2; };
    std::deque<Step> trace_dme_, trace_klr_;
    static constexpr size_t kTrace = 512;

    std::chrono::steady_clock::time_point last_tick_ = std::chrono::steady_clock::now();
    double last_tick_ns_ = 0;

    uint64_t tNs() const { return static_cast<uint64_t>(ctx_->time() * ns_per_tick_); }

    // ── per-timeslot checks ─────────────────────────────────
    void afterEval() {
        if (stop_pending_) {
            // Wait for the testbench to emit the requested DS snapshot
            if (TB(live_snap_ack) == TB(live_snap_req)) {
                stop_pending_ = false;
                paused_ = true;
                state("paused", stop_reason_);
            }
            return;
        }
        if (TB(live_dme_icount) != last_dme_ic_) {
            last_dme_ic_ = TB(live_dme_icount);
            uint16_t pc = TB(live_dme_ipc);
            push(trace_dme_, {pc, TB(live_dme_ctx0), TB(live_dme_ctx1), TB(live_dme_ctx2)});
            if (bp_dme_.count(pc)) return stop("bp dme " + hex(pc));
            if (step_dme_ > 0 && --step_dme_ == 0) return stop("step dme");
        }
        if (TB(live_klr_icount) != last_klr_ic_) {
            last_klr_ic_ = TB(live_klr_icount);
            uint16_t pc = TB(live_klr_ipc);
            push(trace_klr_, {pc, TB(live_klr_ctx0), TB(live_klr_ctx1), 0});
            if (bp_klr_.count(pc)) return stop("bp klr " + hex(pc));
            if (step_klr_ > 0 && --step_klr_ == 0) return stop("step klr");
        }
        if (until_ns_ >= 0 && tNs() >= until_ns_) {
            until_ns_ = -1;
            return stop("until");
        }
    }

    void push(std::deque<Step>& q, const Step& st) {
        q.push_back(st);
        if (q.size() > kTrace) q.pop_front();
    }

    // Stop after the testbench has printed a snapshot of this moment
    void stop(const std::string& why) {
        step_dme_ = step_klr_ = 0;
        stop_reason_ = why;
        stop_pending_ = true;
        TB(live_snap_req) = TB(live_snap_req) + 1;
    }

    // ── stdin while running ─────────────────────────────────
    void pollInput() {
        pollfd p{0, POLLIN, 0};
        while (poll(&p, 1, 0) > 0 && (p.revents & (POLLIN | POLLHUP))) {
            std::string line;
            if (!std::getline(std::cin, line)) { quit_ = true; return; }
            command(line);
            if (paused_ || quit_) return;
        }
        auto now = std::chrono::steady_clock::now();
        double wall = std::chrono::duration<double>(now - last_tick_).count();
        if (wall >= 1.0) {
            double ns = static_cast<double>(tNs());
            printf("SIM: [TIME] t_ns=%llu rate=%.2f\n", static_cast<unsigned long long>(ns),
                   (ns - last_tick_ns_) / 1e6 / wall);
            fflush(stdout);
            last_tick_ = now;
            last_tick_ns_ = ns;
        }
    }

    // ── commands ────────────────────────────────────────────
    void command(const std::string& line) {
        std::istringstream in(line);
        std::string cmd;
        if (!(in >> cmd)) return;
        if (cmd == "run") {
            resume("run");
        } else if (cmd == "pause") {
            if (!paused_ && !stop_pending_) stop("pause");
        } else if (cmd == "step") {
            std::string cpu; long n = 1;
            in >> cpu >> n;
            if (n < 1) n = 1;
            if (cpu == "dme") step_dme_ = n;
            else if (cpu == "klr") step_klr_ = n;
            else return error("step needs dme or klr");
            resume("step");
        } else if (cmd == "until") {
            double ms;
            if (!(in >> ms)) return error("until needs a time in ms");
            until_ns_ = ms * 1e6;
            resume("until");
        } else if (cmd == "set") {
            std::string name, val;
            in >> name >> val;
            setInput(name, val);
        } else if (cmd == "bp") {
            breakpoint(in);
        } else if (cmd == "snap") {
            snapNow();
        } else if (cmd == "trace") {
            std::string cpu; size_t n = 64;
            in >> cpu >> n;
            auto& q = cpu == "klr" ? trace_klr_ : trace_dme_;
            std::string out;
            for (size_t i = q.size() > n ? q.size() - n : 0; i < q.size(); ++i) {
                char ctx[64];
                snprintf(ctx, sizeof ctx, "/%016llx/%016llx/%016llx",
                         static_cast<unsigned long long>(q[i].c0),
                         static_cast<unsigned long long>(q[i].c1),
                         static_cast<unsigned long long>(q[i].c2));
                out += (out.empty() ? "" : ",") + hex(q[i].pc) + ctx;
            }
            printf("SIM: [TRACE] %s %s\n", cpu == "klr" ? "klr" : "dme", out.c_str());
        } else if (cmd == "rom") {
            std::string cpu, path;
            in >> cpu >> std::ws;
            std::getline(in, path);   // the rest of the line, spaces and all
            if (cpu != "dme" && cpu != "klr") return error("rom needs dme or klr");
            if (path.empty()) return error("rom needs a .mem file");
            if (!paused_ || stop_pending_) return error("pause the simulation before loading a ROM");
            if (loadRom(cpu == "klr", path)) romLines();
        } else if (cmd == "status") {
            state(paused_ ? "paused" : "running", "status");
            printf("SIM: [INPUTS] %s\n", inputsLine().c_str());
            bpLine();
            romLines();
        } else if (cmd == "quit") {
            quit_ = true;
        } else {
            error("unknown command: " + cmd);
        }
        fflush(stdout);
    }

    void resume(const char* why) {
        if (stop_pending_) return;
        paused_ = false;
        last_tick_ = std::chrono::steady_clock::now();
        last_tick_ns_ = static_cast<double>(tNs());
        state("running", why);
    }

    // While paused, advance just far enough for the testbench to print
    // one snapshot (at most one DME clock), then stay paused.
    void snapNow() {
        if (!paused_) { stop("snap"); return; }
        TB(live_snap_req) = TB(live_snap_req) + 1;
        while (TB(live_snap_ack) != TB(live_snap_req) && top_->eventsPending() && !ctx_->gotFinish()) {
            ctx_->time(top_->nextTimeSlot());
            top_->eval();
        }
        state("paused", "snap");
    }

    // ── ROM images ──────────────────────────────────────────
    std::string rom_[2];   // image in the DME / KLR EPROM

    // Packed Verilog string (right-aligned, zero-padded) to std::string
    template <typename W> static std::string widePath(const W& w) {
        std::string s;
        for (int i = static_cast<int>(sizeof(w) * 8) - 8; i >= 0; i -= 8) {
            char ch = static_cast<char>((w.data()[i / 32] >> (i % 32)) & 0xFF);
            if (ch) s += ch;
        }
        return s;
    }

    // Read a $readmemh image (hex bytes, @addr, // and /* */ comments)
    // into the testbench buffer and have the next DME clock copy it into
    // the EPROM. Bytes the file doesn't set are 0xFF, like a fresh load.
    bool loadRom(int klr, const std::string& path) {
        const char* cpu = klr ? "klr" : "dme";
        const size_t size = klr ? 4096 : 8192;
        std::string ext = path.size() >= 4 ? path.substr(path.size() - 4) : "";
        std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
        if (ext != ".mem")
            return error(std::string(cpu) + " ROM must be a .mem file: " + path), false;
        std::ifstream f(path);
        if (!f) return error(std::string("can't open ") + cpu + " ROM " + path), false;
        std::string text((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
        std::vector<uint8_t> img(size, 0xFF);
        size_t addr = 0, count = 0, line = 1;
        auto bad = [&](const std::string& why) {
            error(std::string(cpu) + " ROM " + path + " line " + std::to_string(line) + ": " + why);
            return false;
        };
        for (size_t i = 0; i < text.size();) {
            char ch = text[i];
            if (ch == '\n') { ++line; ++i; continue; }
            if (isspace(static_cast<unsigned char>(ch))) { ++i; continue; }
            if (text.compare(i, 2, "//") == 0) { while (i < text.size() && text[i] != '\n') ++i; continue; }
            if (text.compare(i, 2, "/*") == 0) {
                size_t e = text.find("*/", i + 2);
                if (e == std::string::npos) return bad("unterminated comment");
                line += std::count(text.begin() + i, text.begin() + e, '\n');
                i = e + 2;
                continue;
            }
            size_t j = i;
            while (j < text.size() && !isspace(static_cast<unsigned char>(text[j]))) ++j;
            std::string tok = text.substr(i, j - i);
            i = j;
            bool at = tok[0] == '@';
            std::string digits;
            for (char d : tok.substr(at)) if (d != '_') digits += d;
            char* end = nullptr;
            unsigned long v = digits.empty() ? 0 : std::strtoul(digits.c_str(), &end, 16);
            if (digits.empty() || *end || !isxdigit(static_cast<unsigned char>(digits[0])))
                return bad("not a hex value: " + tok);
            if (at) { addr = v; continue; }
            if (v > 0xFF) return bad("value wider than a byte: " + tok);
            if (addr >= size) return bad("past the end of the " + std::to_string(size) + "-byte EPROM");
            img[addr++] = static_cast<uint8_t>(v);
            ++count;
        }
        if (!count) return error(std::string(cpu) + " ROM " + path + " has no data"), false;
        for (size_t a = 0; a < size; ++a) TB(live_rom_buf)[a] = img[a];
        TB(live_rom_cpu) = klr ? 2 : 1;
        TB(live_rom_req) = TB(live_rom_req) + 1;
        while (TB(live_rom_ack) != TB(live_rom_req) && top_->eventsPending() && !ctx_->gotFinish()) {
            ctx_->time(top_->nextTimeSlot());
            top_->eval();
        }
        rom_[klr] = path;
        return true;
    }

    void romLines() const {
        printf("SIM: [ROM] dme %s\nSIM: [ROM] klr %s\n", rom_[0].c_str(), rom_[1].c_str());
    }

    void setInput(const std::string& name, const std::string& val) {
        for (auto& in : inputs_) {
            if (name != in.name) continue;
            long v;
            if (val == "auto") {
                if (!in.can_auto) return error(name + " has no auto mode");
                v = 0xFFFF;
            } else {
                char* end = nullptr;
                v = std::strtol(val.c_str(), &end, 0);
                if (val.empty() || *end) return error("bad value for " + name + ": " + val);
                long max = in.bits == 8 ? 0xFF : 0xFFFF;
                if (v < 0 || v > max) return error(name + " out of range: " + val);
            }
            if (in.bits == 8) *static_cast<uint8_t*>(in.ptr) = static_cast<uint8_t>(v);
            else *static_cast<uint16_t*>(in.ptr) = static_cast<uint16_t>(v);
            printf("SIM: [INPUTS] %s\n", inputsLine().c_str());
            return;
        }
        error("unknown input: " + name);
    }

    void breakpoint(std::istringstream& in) {
        std::string op, cpu, addr;
        in >> op >> cpu >> addr;
        if (op == "clear") {
            bp_dme_.clear();
            bp_klr_.clear();
        } else if (op == "add" || op == "del") {
            if (cpu != "dme" && cpu != "klr") return error("bp needs dme or klr");
            char* end = nullptr;
            unsigned long a = std::strtoul(addr.c_str(), &end, 16);
            if (addr.empty() || *end) return error("bad address: " + addr);
            auto& set = cpu == "dme" ? bp_dme_ : bp_klr_;
            if (op == "add") set.insert(a); else set.erase(a);
        } else if (op != "list") {
            return error("bp add|del|clear|list");
        }
        bpLine();
    }

    // ── output helpers ──────────────────────────────────────
    static std::string hex(uint32_t v) {
        char b[8];
        snprintf(b, sizeof b, "%04X", v);
        return b;
    }

    std::string inputsLine() const {
        std::string s;
        for (auto& in : inputs_) {
            long v = in.bits == 8 ? *static_cast<uint8_t*>(in.ptr) : *static_cast<uint16_t*>(in.ptr);
            s += (s.empty() ? "" : ",") + std::string(in.name) + "=" +
                 (in.can_auto && v == 0xFFFF ? "auto" : std::to_string(v));
        }
        return s;
    }

    void bpLine() const {
        auto join = [](const std::set<uint32_t>& s) {
            std::string o;
            for (auto a : s) o += (o.empty() ? "" : ",") + hex(a);
            return o;
        };
        printf("SIM: [BP] dme=%s klr=%s\n", join(bp_dme_).c_str(), join(bp_klr_).c_str());
    }

    void state(const char* st, const std::string& why) {
        printf("SIM: [STATE] %s t_ns=%llu dme_pc=%s klr_pc=%s reason=%s\n", st,
               static_cast<unsigned long long>(tNs()), hex(TB(live_dme_ipc)).c_str(),
               hex(TB(live_klr_ipc)).c_str(), why.c_str());
        fflush(stdout);
    }

    void error(const std::string& msg) {
        printf("SIM: [ERROR] %s\n", msg.c_str());
        fflush(stdout);
    }
};

}  // namespace

int main(int argc, char** argv) {
    // Line-buffered so the bridge sees each line as soon as it's printed
    setvbuf(stdout, nullptr, _IOLBF, 0);
    return LiveSim(argc, argv).run();
}
