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
//    save [label]              save a snapshot of the whole model now (see
//                              Snapshots below); while running it is taken
//                              at the next quiescent moment
//    load <dir>                while paused, restore a snapshot directory
//                              (+load=<dir> does the same at start)
//    autosnap on|off|max <n>   snapshot on every warning (default on, at
//                              most once a sim second per kind of warning
//                              and <n> = 25 per run)
//    breakonwarn on|off        also pause after a warning's snapshot
//                              (default off; +breakonwarn=1)
//    quit
//
//  Snapshots: a warning or error line from the model ([WARN], WARNING or
//  ERROR in its text, seen through live_printf.h) makes the driver save
//  <snapdir>/<date>-t<ms>ms-<warning>/ (+snapdir=<dir>, default
//  ./snapshots):
//    state.bin   every variable of the model (gen_state.py lists them:
//                CPU registers and RAM, ROM arrays, peripherals, engine
//                model, Verilator's own edge state), the delay-scheduler
//                wake-up times, inputs, breakpoints and instruction trace
//    sim.json    the same for people: trigger line, time, inputs, ROM
//                identity, CPU registers, RAM, testbench pins, the [DS] /
//                [REGS] lines of that moment and the trace
//    rom/dme|klr/<image>.mem  the EPROM contents at that moment
//  Loading one in a fresh process (load / +load=) gives the same run from
//  that time on, in the same build of the simulator; snapshot.h explains
//  how.
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
//    SIM: [SNAP]   saved t_ns=<n> reason=warn|manual dir=<path>
//    SIM: [SNAP]   loaded t_ns=<n> exact=0|1 dir=<path>   (exact=0: another build,
//                  clock phases approximated)
//    SIM: [SNAP]   skipped <why>                   (auto snapshot not taken)
//    SIM: [SNAPCFG] auto=on|off break=on|off taken=<n> max=<n>
// ============================================================

#include "Vdme_klr_dashboard_tb.h"
#include "Vdme_klr_dashboard_tb___024root.h"
#include "Vdme_klr_dashboard_tb_dme_klr_dashboard_tb.h"
#include "verilated.h"
#include "snapshot.h"

#include <poll.h>
#include <unistd.h>

#include <chrono>
#include <algorithm>
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <deque>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <map>
#include <memory>
#include <set>
#include <sstream>
#include <string>
#include <vector>

// ── Model output (live_printf.h) ────────────────────────────
// Every $display / $write of the model lands here: printed as before,
// and each complete line handed to the driver.
static std::function<void(const std::string&)> g_onModelLine;
static std::string g_modelLine;

int live_printf(const char* fmt, ...) {
    char buf[1024];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    if (n < 0) return n;
    std::string s;
    if (n < static_cast<int>(sizeof buf)) {
        s.assign(buf, n);
    } else {
        s.resize(n + 1);
        va_start(ap, fmt);
        vsnprintf(&s[0], n + 1, fmt, ap);
        va_end(ap);
        s.resize(n);
    }
    fwrite(s.data(), 1, s.size(), stdout);
    for (char ch : s) {
        if (ch != '\n') { g_modelLine += ch; continue; }
        if (g_onModelLine) g_onModelLine(g_modelLine);
        g_modelLine.clear();
    }
    return n;
}

// The public regs declared under `ifdef LIVE in dme_klr_dashboard_tb.v
#define TB(sig) (root->dme_klr_dashboard_tb->sig)

namespace {

struct Input {
    const char* name;
    void* ptr;
    int bits;          // 8 or 16
    bool can_auto;     // 16'hFFFF = follow the model
    long pin_max = 0;  // pinned values above this are held at it (0 = none)
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
            // ch4 above F5 wraps ram[52h] (the KLR adds 10); klr_tb.v caps it too
            {"boost",     &TB(live_boost),     16, true, 0xF5},
            {"coolant",   &TB(live_coolant),    8, false},
            {"airtemp",   &TB(live_airtemp),    8, false},
            {"battery",   &TB(live_battery),    8, false},
            {"altitude",  &TB(live_altitude),   8, false},
            {"fuel_qual", &TB(live_fuel_qual),  8, false},
            {"dme_tps",   &TB(live_dme_tps),   16, true},
            {"klr_tps",   &TB(live_klr_tps),   16, true},
            {"o2",        &TB(live_o2),        16, true},
            {"knock",     &TB(live_knock),     16, true},
            {"ac",        &TB(live_ac),         8, false},   // DME T1: 1 = AC compressor on
        };
        liveFields(root->vlSymsp, fields_);
        layout_ = liveLayoutHash(fields_);
        if (fields_.size() < 100)
            error("this build lists only " + std::to_string(fields_.size()) +
                  " model variables, so snapshots can't be saved or loaded: rerun ./build_live.sh");
        afm_field_ = field({"TOP__dme_klr_dashboard_tb__u_dme.afm_commanded",
                            "TOP__dme_klr_dashboard_tb__u_dme.__PVT__afm_commanded"});
        std::string dir = ctx_->commandArgsPlusMatch("snapdir=");
        if (!dir.empty()) snapdir_ = dir.substr(dir.find('=') + 1);
        if (*ctx_->commandArgsPlusMatch("autosnap=0")) auto_snap_ = false;
        if (*ctx_->commandArgsPlusMatch("breakonwarn=1")) break_on_warn_ = true;
        if (*ctx_->commandArgsPlusMatch("loadpin=0")) pin_on_load_ = false;
        if (scripted_) auto_snap_ = false;
        g_onModelLine = [this](const std::string& l) { modelLine(l); };
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
            if (!arg.empty() && loadRom(c, arg.substr(arg.find('=') + 1))) rom_arg_[c] = true;
        }
        romLines();
        printf("SIM: [READY] %s\n", inputsLine().c_str());
        snapCfgLine();
        state("paused", "start");
        std::string load = ctx_->commandArgsPlusMatch("load=");
        if (!load.empty()) loadSnapshot(load.substr(load.find('=') + 1));
        // +runto=<ns> [+runlabel=<text>]: run there and pause, then say
        // "loaded" (how the bridge opens a regression test's warning)
        std::string runto = ctx_->commandArgsPlusMatch("runto=");
        if (!runto.empty()) {
            std::string label = ctx_->commandArgsPlusMatch("runlabel=");
            runto_label_ = label.empty() ? "runto" : label.substr(label.find('=') + 1);
            until_ns_ = std::strtod(runto.c_str() + runto.find('=') + 1, nullptr);
            runto_ = true;
            resume("runto");
        }
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
        housekeeping();
        if (paused_) return;   // a warning's snapshot may have just paused
        if (stop_pending_) {
            // Wait for the testbench to emit the requested DS snapshot
            if (TB(live_snap_ack) == TB(live_snap_req)) {
                stop_pending_ = false;
                paused_ = true;
                if (runto_ && stop_reason_ == "until") {
                    runto_ = false;
                    printf("SIM: [SNAP] loaded t_ns=%llu exact=1 dir=%s\n",
                           static_cast<unsigned long long>(tNs()), runto_label_.c_str());
                }
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

    // Every time slot, running or not: pending AFM updates, learning the
    // always-present coroutines, and a snapshot in progress
    void housekeeping() {
        if (tps_changed_) {
            // The tb's `afm_commanded <= #AFM_LAG_NS tps_commanded` fork
            // started in this eval; remember when it lands (see Afm)
            tps_changed_ = false;
            afm_.push_back({ctx_->time() + static_cast<uint64_t>(kAfmLagNs / ns_per_tick_ + 0.5), tps_new_, false});
        }
        if (!afm_.empty()) applyAfm();
        if (!ref_.ready() && tNs() >= LiveReference::kStartNs) ref_.sample(liveDelays(dly()));
        if (save_) stepSave();
    }

    // Advance one time slot while paused (save / load find their moment
    // this way): trace kept, breakpoints and steps not checked
    bool advance() {
        if (!top_->eventsPending() || ctx_->gotFinish()) return false;
        ctx_->time(top_->nextTimeSlot());
        top_->eval();
        housekeeping();
        if (TB(live_dme_icount) != last_dme_ic_) {
            last_dme_ic_ = TB(live_dme_icount);
            push(trace_dme_, {TB(live_dme_ipc), TB(live_dme_ctx0), TB(live_dme_ctx1), TB(live_dme_ctx2)});
        }
        if (TB(live_klr_icount) != last_klr_ic_) {
            last_klr_ic_ = TB(live_klr_icount);
            push(trace_klr_, {TB(live_klr_ipc), TB(live_klr_ctx0), TB(live_klr_ctx1), 0});
        }
        return true;
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
        if (scripted_ && (cmd == "save" || cmd == "load" || cmd == "set" || (cmd == "autosnap" && line.find(" on") != std::string::npos)))
            return error(cmd + " isn't available while running a regression test (build_live.sh --test): its "
                         "inputs come from the test's script and its state can't be saved. RESTART goes back to the live simulator");
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
        } else if (cmd == "save") {
            std::string label;
            std::getline(in >> std::ws, label);
            requestSave("manual", label, "", false);
            if (paused_) {
                // Not running: step to the moment ourselves
                while (save_ && advance()) {}
                if (save_) { save_.reset(); error("save: simulation ended before a snapshot could be taken"); }
                state("paused", "save");
            }
        } else if (cmd == "load") {
            std::string dir;
            std::getline(in >> std::ws, dir);
            if (dir.empty()) return error("load needs a snapshot directory");
            if (!paused_ || stop_pending_) return error("pause the simulation before loading a snapshot");
            loadSnapshot(dir);
        } else if (cmd == "autosnap") {
            std::string v;
            in >> v;
            if (v == "on") auto_snap_ = true;
            else if (v == "off") auto_snap_ = false;
            else if (v == "max") { int n = -1; in >> n; if (n < 0) return error("autosnap max <n>"); auto_max_ = n; }
            else if (!v.empty()) return error("autosnap on|off|max <n>");
            snapCfgLine();
        } else if (cmd == "breakonwarn") {
            std::string v;
            in >> v;
            if (v == "on") break_on_warn_ = true;
            else if (v == "off") break_on_warn_ = false;
            else if (!v.empty()) return error("breakonwarn on|off");
            snapCfgLine();
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
                if (in.pin_max && v > in.pin_max) v = in.pin_max;
            }
            if (in.bits == 8) {
                auto* p = static_cast<uint8_t*>(in.ptr);
                if (p == &TB(live_tps) && *p != v) { tps_changed_ = true; tps_new_ = static_cast<uint8_t>(v); }
                *p = static_cast<uint8_t>(v);
            } else {
                *static_cast<uint16_t*>(in.ptr) = static_cast<uint16_t>(v);
            }
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

    // ── Snapshots ───────────────────────────────────────────
    LiveFieldList fields_;       // every variable of the model (gen_state.py)
    uint64_t layout_ = 0;
    LiveReference ref_;          // coroutines that are always waiting (snapshot.h)
    std::string snapdir_ = "snapshots";
    bool rom_arg_[2] = {false, false};   // image given with +dme_rom= / +klr_rom=
    bool auto_snap_ = true, break_on_warn_ = false;
#ifdef LIVE_SCRIPTED
    bool scripted_ = true;       // build_live.sh --test: the test's own stimulus
#else
    bool scripted_ = false;
#endif
    bool runto_ = false;         // +runto= in progress
    std::string runto_label_;
    bool pin_on_load_ = true;    // +loadpin=0: keep rpm/afm/boost on auto after a load
    int auto_max_ = 25, auto_taken_ = 0;
    bool limit_told_ = false;
    std::map<std::string, uint64_t> kind_last_ns_;   // last auto snapshot per kind of warning
    struct SaveReq { std::string reason, label, trigger; bool pause; int phase = 0; long evals = 0; };
    std::unique_ptr<SaveReq> save_;
    bool capturing_ = false;
    std::vector<std::string> captured_;   // the model's lines while the tb prints a snapshot
    // AFM lag (i8051_dashboard_tb.v, LIVE): `afm_commanded <= #AFM_LAG_NS
    // tps_commanded` keeps each new throttle value inside a coroutine for
    // 250 ms, where a snapshot can't reach it. The driver keeps the same
    // list; after a load it makes those writes itself (driver = true).
    static constexpr double kAfmLagNs = 250e6;
    struct Afm { uint64_t due; uint8_t val; bool driver; };
    std::vector<Afm> afm_;
    bool tps_changed_ = false;
    uint8_t tps_new_ = 0;
    LiveField* afm_field_ = nullptr;
    static constexpr long kSaveEvals = 4'000'000;    // time slots to find a quiescent moment
    static constexpr long kLoadEvals = 40'000'000;   // fresh process: past start-up, AFM forks done

    VlDelayScheduler& dly() { return root->__VdlySched; }

    LiveField* field(std::initializer_list<const char*> names) {
        for (const char* n : names)
            for (auto& f : fields_) if (f.name == n) return &f;
        return nullptr;
    }
    std::vector<LiveField*> fieldsEnding(const std::string& suffix) {
        std::vector<LiveField*> out;
        for (auto& f : fields_)
            if (f.name.size() >= suffix.size() && f.name.compare(f.name.size() - suffix.size(), suffix.size(), suffix) == 0
                && f.name.find(".__V") == std::string::npos)
                out.push_back(&f);
        return out;
    }

    void applyAfm() {
        uint64_t now = ctx_->time();
        for (size_t i = 0; i < afm_.size();) {
            if (afm_[i].due > now) { ++i; continue; }
            if (afm_[i].driver && afm_field_) *static_cast<uint8_t*>(afm_field_->ptr) = afm_[i].val;
            afm_.erase(afm_.begin() + i);
        }
    }

    // A line the model printed: collect it during a capture, and start an
    // automatic snapshot on a warning or error
    void modelLine(const std::string& line) {
        if (capturing_) captured_.push_back(line);
        if (line.find("[WARN]") == std::string::npos && line.find("WARNING") == std::string::npos
            && line.find("ERROR") == std::string::npos)
            return;
        if (!auto_snap_ || save_) return;
        std::string kind = warnKind(line);
        uint64_t now = tNs();
        auto last = kind_last_ns_.find(kind);
        if (last != kind_last_ns_.end() && now - last->second < 1'000'000'000ULL) return;
        if (auto_taken_ >= auto_max_) {
            if (!limit_told_) printf("SIM: [SNAP] skipped limit of %d automatic snapshots reached (autosnap max <n>)\n", auto_max_);
            limit_told_ = true;
            return;
        }
        kind_last_ns_[kind] = now;
        ++auto_taken_;
        requestSave("warn", "", line, break_on_warn_);
    }

    // The words of a warning without its numbers, so repeats of one warning
    // share a kind: "DME: [WARN] t=812 ms  INJ PW 9.1 ms > one rev ..." ->
    // "dme warn inj pw one rev ..."
    static std::string warnKind(const std::string& line) {
        std::string k, tok;
        auto flush = [&] {
            bool digit = std::any_of(tok.begin(), tok.end(), [](char c) { return isdigit(static_cast<unsigned char>(c)); });
            if (!tok.empty() && !digit && tok != "t" && tok != "ms") k += (k.empty() ? "" : " ") + tok;
            tok.clear();
        };
        for (char ch : line) {
            if (isalnum(static_cast<unsigned char>(ch))) tok += static_cast<char>(tolower(static_cast<unsigned char>(ch)));
            else flush();
        }
        flush();
        return k;
    }

    void requestSave(const std::string& reason, const std::string& label, const std::string& trigger, bool pause) {
        if (save_) return;
        save_ = std::make_unique<SaveReq>(SaveReq{reason, label, trigger, pause});
    }

    // Snapshot steps, one per time slot: have the testbench print its
    // [DS]/[REGS] lines (captured for sim.json), then wait for a
    // quiescent moment and write the files.
    void stepSave() {
        SaveReq& s = *save_;
        if (s.phase == 0) {
            captured_.clear();
            capturing_ = true;
            TB(live_snap_req) = TB(live_snap_req) + 1;
            s.phase = 1;
            return;
        }
        if (s.phase == 1) {
            if (TB(live_snap_ack) != TB(live_snap_req)) return;
            capturing_ = false;
            s.phase = 2;
        }
        if (!quiescent(true)) {
            if (++s.evals > kSaveEvals) {
                save_.reset();
                error("snapshot: no quiescent moment found (a coroutine stayed mid-block); not saved");
            }
            return;
        }
        std::unique_ptr<SaveReq> req = std::move(save_);
        writeSnapshot(*req);
        if (req->pause && !paused_) {
            step_dme_ = step_klr_ = 0;
            until_ns_ = -1;
            stop_pending_ = false;
            paused_ = true;
            state("paused", "warning");
        }
    }

    // Every coroutine waiting on a delay is one the fresh process also has
    // waiting (allowAfm: or one of the AFM forks the driver tracks)
    bool quiescent(bool allowAfm) {
        if (!ref_.ready()) return false;
        LiveCensus c;
        for (auto& e : liveDelays(dly())) {
            if (allowAfm && isAfmKey(e.key)) continue;
            ++c[e.fn];
        }
        return c == ref_.ref;
    }
    bool isAfmKey(uint64_t key) const {
        for (auto& a : afm_) if (!a.driver && a.due == key) return true;
        return false;
    }

    static std::string slug(const std::string& s, size_t max) {
        std::string o;
        for (char ch : s) {
            if (isalnum(static_cast<unsigned char>(ch))) o += static_cast<char>(tolower(static_cast<unsigned char>(ch)));
            else if (!o.empty() && o.back() != '-') o += '-';
            if (o.size() >= max) break;
        }
        while (!o.empty() && o.back() == '-') o.pop_back();
        return o;
    }

    static uint64_t le(const LiveField& f) {
        uint64_t v = 0;
        memcpy(&v, f.ptr, std::min<size_t>(f.size, 8));
        return v;
    }

    void writeSnapshot(const SaveReq& req) {
        if (fields_.size() < 100)
            return error("this build lists only " + std::to_string(fields_.size()) +
                         " model variables, so it can't save snapshots: rerun ./build_live.sh");
        namespace fs = std::filesystem;
        uint64_t t_ns = tNs();
        std::time_t now = std::time(nullptr);
        char stamp[32], iso[32];
        std::strftime(stamp, sizeof stamp, "%Y%m%d-%H%M%S", std::localtime(&now));
        std::strftime(iso, sizeof iso, "%Y-%m-%dT%H:%M:%SZ", std::gmtime(&now));
        std::string what = slug(req.label.empty() ? (req.trigger.empty() ? req.reason : warnKind(req.trigger)) : req.label, 40);
        std::string base = std::string(stamp) + "-t" + std::to_string(t_ns / 1000000) + "ms" + (what.empty() ? "" : "-" + what);
        std::error_code ec;
        fs::path dir = fs::absolute(fs::path(snapdir_) / base, ec);
        for (int n = 2; fs::exists(dir); ++n) dir = fs::absolute(fs::path(snapdir_) / (base + "-" + std::to_string(n)), ec);
        fs::create_directories(dir / "rom" / "dme", ec);
        fs::create_directories(dir / "rom" / "klr", ec);
        if (ec) return error("snapshot: can't create " + dir.string() + ": " + ec.message());

        // Delay entries, without the AFM forks (those go in the afm list)
        std::vector<LiveDelay> delays;
        for (auto& e : liveDelays(dly())) if (!isAfmKey(e.key)) delays.push_back(e);

        // ── state.bin ───────────────────────────────────────
        size_t total = 0;
        for (auto& f : fields_) total += f.size;
        {
            std::ofstream o(dir / "state.bin", std::ios::binary);
            char hx[32];
            snprintf(hx, sizeof hx, "%016llx", static_cast<unsigned long long>(layout_));
            o << "DMEKLR-LIVE-STATE 1\n" << "layout " << hx << "\n" << "verilator " << Verilated::productVersion() << "\n" << "time " << ctx_->time() << "\n";
            o << "delays " << delays.size() << "\n";
            for (auto& e : delays) o << e.key << " " << e.fn << "\n";
            o << "afm " << afm_.size() << "\n";
            for (auto& a : afm_) o << a.due << " " << static_cast<int>(a.val) << "\n";
            o << "rom dme " << rom_[0] << "\n" << "rom klr " << rom_[1] << "\n";
            for (auto a : bp_dme_) o << "bp dme " << hex(a) << "\n";
            for (auto a : bp_klr_) o << "bp klr " << hex(a) << "\n";
            for (int c = 0; c < 2; ++c)
                for (auto& st : c ? trace_klr_ : trace_dme_)
                    o << "trace " << (c ? "klr " : "dme ") << st.pc << " " << st.c0 << " " << st.c1 << " " << st.c2 << "\n";
            o << "fields " << fields_.size() << " " << total << "\n";
            for (auto& f : fields_) o << f.name << " " << f.size << "\n";
            o << "data\n";
            for (auto& f : fields_) o.write(static_cast<const char*>(f.ptr), static_cast<std::streamsize>(f.size));
            if (!o) return error("snapshot: writing " + (dir / "state.bin").string() + " failed");
        }

        // ── EPROM images as .mem ────────────────────────────
        std::string romJson[2];
        const char* romSuffix[2] = {"u_eprom__DOT__mem", "rom_1__DOT__rom"};
        for (int c = 0; c < 2; ++c) {
            auto found = fieldsEnding(romSuffix[c]);
            if (found.empty()) { romJson[c] = "{\"path\":" + liveJson(rom_[c]) + "}"; continue; }
            const LiveField& f = *found[0];
            const auto* p = static_cast<const uint8_t*>(f.ptr);
            std::string name = fs::path(rom_[c]).filename().string();
            if (name.empty()) name = c ? "klr.mem" : "dme.mem";
            std::string rel = std::string("rom/") + (c ? "klr/" : "dme/") + name;
            std::ofstream m(dir / rel);
            m << "// " << (c ? "KLR" : "DME") << " EPROM at t=" << t_ns << " ns, snapshot of " << rom_[c] << "\n";
            for (size_t a = 0; a < f.size; ++a) {
                char b[4];
                snprintf(b, sizeof b, "%02x", p[a]);
                m << b << ((a & 15) == 15 ? "\n" : " ");
            }
            char crc[16];
            snprintf(crc, sizeof crc, "%08x", liveCrc32(p, f.size));
            romJson[c] = "{\"path\":" + liveJson(rom_[c]) + ",\"file\":" + liveJson(rel) + ",\"bytes\":" +
                         std::to_string(f.size) + ",\"crc32\":\"" + crc + "\"}";
        }

        // ── sim.json ────────────────────────────────────────
        std::ostringstream j;
        j << "{\n\"format\":\"dme-klr-live-snapshot\",\"version\":1,\n";
        j << "\"created\":\"" << iso << "\",\"reason\":" << liveJson(req.reason) << ",\"label\":" << liveJson(req.label)
          << ",\"trigger\":" << liveJson(req.trigger) << ",\n";
        j << "\"t_ns\":" << t_ns << ",\"pc\":{\"dme\":\"" << hex(TB(live_dme_ipc)) << "\",\"klr\":\"" << hex(TB(live_klr_ipc)) << "\"},\n";
        j << "\"inputs\":{";
        for (size_t i = 0; i < inputs_.size(); ++i) {
            auto& in = inputs_[i];
            long v = in.bits == 8 ? *static_cast<uint8_t*>(in.ptr) : *static_cast<uint16_t*>(in.ptr);
            j << (i ? "," : "") << liveJson(in.name) << ":" << (in.can_auto && v == 0xFFFF ? "\"auto\"" : std::to_string(v));
        }
        j << "},\n\"breakpoints\":{\"dme\":[";
        { bool first = true; for (auto a : bp_dme_) { j << (first ? "" : ",") << "\"" << hex(a) << "\""; first = false; } }
        j << "],\"klr\":[";
        { bool first = true; for (auto a : bp_klr_) { j << (first ? "" : ",") << "\"" << hex(a) << "\""; first = false; } }
        j << "]},\n\"roms\":{\"dme\":" << romJson[0] << ",\"klr\":" << romJson[1] << "},\n";
        // CPU registers: the core's own scalars (no Verilator temporaries)
        const char* cores[2][2] = {{"dme", "u_cpu__DOT__"}, {"klr", "i8048_core_1__DOT__"}};
        j << "\"registers\":{";
        for (int c = 0; c < 2; ++c) {
            j << (c ? "," : "") << "\"" << cores[c][0] << "\":{";
            bool first = true;
            for (auto& f : fields_) {
                size_t at = f.name.find(cores[c][1]);
                if (at == std::string::npos || f.size > 8 || f.name.find("__V") != std::string::npos) continue;
                std::string reg = f.name.substr(at + strlen(cores[c][1]));
                if (reg.find("__DOT__") != std::string::npos) continue;
                char v[24];
                snprintf(v, sizeof v, "%llx", static_cast<unsigned long long>(le(f)));
                j << (first ? "" : ",") << liveJson(reg) << ":\"" << v << "\"";
                first = false;
            }
            j << "}";
        }
        j << "},\n\"memories\":{";
        {
            bool first = true;
            const char* mems[][2] = {{"dme_iram", "u_cpu__DOT__iram"}, {"klr_ram", "i8048_core_1__DOT__ram"}};
            for (auto& m : mems)
                for (auto* f : fieldsEnding(m[1])) {
                    j << (first ? "" : ",") << "\"" << m[0] << "\":\"" << liveHexBytes(f->ptr, f->size) << "\"";
                    first = false;
                    break;
                }
        }
        // Testbench-level signals: pins between the CPUs, engine model, live inputs
        j << "},\n\"signals\":{";
        {
            bool first = true;
            for (auto& f : fields_) {
                size_t dot = f.name.find('.');
                std::string inst = f.name.substr(0, dot), mem = f.name.substr(dot + 1);
                if (inst != "TOP__dme_klr_dashboard_tb" && inst != "TOP__dme_klr_dashboard_tb__u_dme") continue;
                if (mem.rfind("__PVT__", 0) == 0) mem = mem.substr(7);
                if (f.size > 8 || mem.find("__") != std::string::npos) continue;
                char v[24];
                snprintf(v, sizeof v, "%llx", static_cast<unsigned long long>(le(f)));
                j << (first ? "" : ",") << liveJson((inst.size() > 26 ? "dme." : "") + mem) << ":\"" << v << "\"";
                first = false;
            }
        }
        j << "},\n\"lines\":[";
        for (size_t i = 0; i < captured_.size(); ++i) j << (i ? ",\n" : "\n") << liveJson(captured_[i]);
        j << "],\n\"trace\":{";
        for (int c = 0; c < 2; ++c) {
            j << (c ? "," : "") << "\"" << (c ? "klr" : "dme") << "\":[";
            auto& q = c ? trace_klr_ : trace_dme_;
            for (size_t i = 0; i < q.size(); ++i) j << (i ? "," : "") << "\"" << hex(q[i].pc) << "\"";
            j << "]";
        }
        j << "},\n\"afm_pending\":[";
        for (size_t i = 0; i < afm_.size(); ++i)
            j << (i ? "," : "") << "{\"t_ns\":" << static_cast<uint64_t>(afm_[i].due * ns_per_tick_) << ",\"value\":" << static_cast<int>(afm_[i].val) << "}";
        char hx[32];
        snprintf(hx, sizeof hx, "%016llx", static_cast<unsigned long long>(layout_));
        j << "],\n\"model\":{\"layout\":\"" << hx << "\",\"fields\":" << fields_.size() << ",\"bytes\":" << total
          << ",\"delays\":" << delays.size() << ",\"verilator\":" << liveJson(Verilated::productVersion()) << "}\n}\n";
        std::ofstream(dir / "sim.json") << j.str();

        printf("SIM: [SNAP] saved t_ns=%llu reason=%s dir=%s\n", static_cast<unsigned long long>(t_ns),
               req.reason.c_str(), dir.string().c_str());
        fflush(stdout);
    }

    bool loadSnapshot(const std::string& dirArg) {
        if (fields_.size() < 100)
            return error("this build lists only " + std::to_string(fields_.size()) +
                         " model variables, so it can't load snapshots: rerun ./build_live.sh"), false;
        namespace fs = std::filesystem;
        fs::path dir(dirArg);
        std::ifstream in(dir / "state.bin", std::ios::binary);
        if (!in) return error("load: no state.bin in " + dirArg), false;
        std::string line, word;
        auto bad = [&](const std::string& why) { error("load: " + dirArg + ": " + why); return false; };
        if (!std::getline(in, line) || line != "DMEKLR-LIVE-STATE 1") return bad("not a snapshot (or a newer format)");
        uint64_t layout = 0, time = 0;
        std::string verilator;   // version that built the saving simulator (newer snapshots)
        std::vector<LiveDelay> delays;
        std::vector<Afm> afm;
        std::string roms[2];
        std::set<uint32_t> bps[2];
        std::deque<Step> traces[2];
        std::vector<std::pair<std::string, size_t>> names;
        size_t total = 0;
        while (std::getline(in, line) && line != "data") {
            std::istringstream ls(line);
            ls >> word;
            if (word == "layout") { std::string h; ls >> h; layout = std::strtoull(h.c_str(), nullptr, 16); }
            else if (word == "time") ls >> time;
            else if (word == "verilator") std::getline(ls >> std::ws, verilator);
            else if (word == "delays" || word == "afm") {
                size_t n = 0;
                ls >> n;
                for (size_t i = 0; i < n && std::getline(in, line); ++i) {
                    std::istringstream es(line);
                    if (word == "delays") { LiveDelay d{}; es >> d.key >> d.fn; delays.push_back(d); }
                    else { uint64_t due = 0; int v = 0; es >> due >> v; afm.push_back({due, static_cast<uint8_t>(v), true}); }
                }
            } else if (word == "rom") {
                std::string cpu, path;
                ls >> cpu >> std::ws;
                std::getline(ls, path);
                roms[cpu == "klr"] = path;
            } else if (word == "bp") {
                std::string cpu, a;
                ls >> cpu >> a;
                bps[cpu == "klr"].insert(std::strtoul(a.c_str(), nullptr, 16));
            } else if (word == "trace") {
                std::string cpu;
                Step st{};
                unsigned pc = 0;
                ls >> cpu >> pc >> st.c0 >> st.c1 >> st.c2;
                st.pc = static_cast<uint16_t>(pc);
                traces[cpu == "klr"].push_back(st);
            } else if (word == "fields") {
                size_t n = 0;
                ls >> n >> total;
                for (size_t i = 0; i < n && std::getline(in, line); ++i) {
                    size_t sp = line.rfind(' ');
                    names.emplace_back(line.substr(0, sp), std::strtoull(line.c_str() + sp + 1, nullptr, 10));
                }
            }
        }
        if (line != "data") return bad("state.bin is truncated");
        if (layout != layout_ || names.size() != fields_.size()) {
            size_t differ = 0;
            std::string example;
            std::map<std::string, size_t> mine;
            for (auto& f : fields_) mine[f.name] = f.size;
            for (auto& [n, sz] : names) {
                auto it = mine.find(n);
                if (it == mine.end() || it->second != sz) { if (!differ++) example = n; }
            }
            std::string why = "saved by a different build of the simulator";
            if (!verilator.empty() && verilator != Verilated::productVersion())
                why += " (Verilator " + verilator + "; this one is " + Verilated::productVersion() + ")";
            else if (differ)
                why += " (" + std::to_string(differ) + " of " + std::to_string(names.size()) +
                       " variables differ, e.g. " + example + ")";
            return bad(why + ". Nothing was loaded: a snapshot only loads into the simulator build that saved it");
        }
        std::vector<char> data(total);
        if (!in.read(data.data(), static_cast<std::streamsize>(total))) return bad("state.bin is truncated");

        // Bring this process to a moment where its coroutines are all at
        // their always-present points (a fresh process: past start-up)
        long n = 0;
        bool autoSnap = auto_snap_;
        auto_snap_ = false;   // no snapshots of the state being replaced
        save_.reset();
        while (!quiescent(false)) {
            if (++n > kLoadEvals || !advance()) { auto_snap_ = autoSnap; return bad("couldn't reach a quiescent moment in this process"); }
        }
        auto_snap_ = autoSnap;
        bool exact = liveRemapDelays(dly(), delays, time, ctx_->time());
        ctx_->time(time);
        size_t off = 0;
        for (auto& f : fields_) { memcpy(f.ptr, data.data() + off, f.size); off += f.size; }
        afm_ = afm;
        tps_changed_ = false;
        for (int c = 0; c < 2; ++c) if (!rom_arg_[c] && !roms[c].empty()) rom_[c] = roms[c];
        bp_dme_ = bps[0];
        bp_klr_ = bps[1];
        trace_dme_ = traces[0];
        trace_klr_ = traces[1];
        last_dme_ic_ = TB(live_dme_icount);
        last_klr_ic_ = TB(live_klr_icount);
        step_dme_ = step_klr_ = 0;
        until_ns_ = -1;
        save_.reset();
        capturing_ = false;
        kind_last_ns_.clear();
        printf("SIM: [SNAP] loaded t_ns=%llu exact=%d dir=%s\n", static_cast<unsigned long long>(tNs()), exact ? 1 : 0,
               fs::absolute(dir).string().c_str());
        // Hold the engine at the saved operating point: rpm / afm / boost
        // that were following the model are pinned to what they read then
        // (tick auto in the dashboard to let the model run again)
        if (pin_on_load_) {
            if (TB(live_rpm) == 0xFFFF) TB(live_rpm) = TB(live_rpm_now);
            if (TB(live_afm) == 0xFFFF) TB(live_afm) = TB(live_afm_now);
            if (TB(live_boost) == 0xFFFF) TB(live_boost) = std::min<uint16_t>(TB(live_boost_now), 0xF5);
        }
        // A [DS] / [REGS] pair of the restored state, so the dashboard's
        // stats and RAM views show it straight away
        TB(live_snap_req) = TB(live_snap_req) + 1;
        while (TB(live_snap_ack) != TB(live_snap_req) && advance()) {}
        romLines();
        printf("SIM: [INPUTS] %s\n", inputsLine().c_str());
        bpLine();
        state("paused", "snapshot");
        return true;
    }

    void snapCfgLine() const {
        printf("SIM: [SNAPCFG] auto=%s break=%s taken=%d max=%d\n", auto_snap_ ? "on" : "off",
               break_on_warn_ ? "on" : "off", auto_taken_, auto_max_);
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
