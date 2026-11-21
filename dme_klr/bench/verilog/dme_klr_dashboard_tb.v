// ============================================================
//  dme_klr_dashboard_tb.v  —  DME 951 + KLR combined testbench
//
//  Signal interconnect:
//    DME A_1_tach_pulse  → KLR ext_ign     (DME tach → KLR, inverted)
//    DME A_5_KLR_ign_out → KLR ext_trigger (DME ign out → KLR, inverted)
//    KLR ign_out         → (not connected to DME — spark output, not key switch)
//    KLR full_load       → DME full_load   (WOT flag → DME TPS ch6)
//    DME afm_wiper      → KLR tps_wiper   (TPS angle ch7)
//    DME ref_rpm        → KLR rpm_in      (RPM, only used by -DBOOST)
//    DME clk/tdc/speed_sensor → KLR dme_clk/tdc/speed_sensor
//                        (drives KLR's internal knock_signal_generator —
//                         see klr_tb.v / klr_knock_gen.v)
//
//  Snapshot format (every DASH_INTERVAL_MS, latched to DME clock):
//    [DS]  <ms>,<256hex_dme_iram>,<p1p2p3>,<rpm>
//    KLR: [DS] <ms>,<256hex_klr_ram>,<p1p2>,<ign><ignout><fl>
// ============================================================

`include "timescale.v"

`ifndef DASH_INTERVAL_MS
  `define DASH_INTERVAL_MS 100
`endif

`define DME_KLR_MS ($time / 1_000_000)

// LIVE: the live debugger (dme_klr/live/): the web UI drives the inputs
// (live_* below, read by the sub-testbenches under LIVE) and LIVE_DEBUG
// gives sim_main its hooks (breakpoints, stepping, on-demand snapshots,
// ROM reload). LIVE_DEBUG alone keeps a test's own scripted stimulus:
// build_live.sh --test <name> builds a regression test that way, so the
// dashboard can open it at the moment it warned.
`ifdef LIVE
  `define LIVE_DEBUG
`endif

// Snapshot interval in ns: DASH_INTERVAL_MS, or under LIVE_DEBUG what the
// live debugger set (live_dash_eff below)
`ifdef LIVE_DEBUG
  `define DASH_IV_NS ({32'd0, live_dash_eff} * 64'd1_000_000)
`else
  `define DASH_IV_NS (`VAL_DASH_INTERVAL_MS * 64'd1_000_000)
`endif

module dme_klr_dashboard_tb;

    // ── Interconnect ──────────────────────────────────────────
    wire tach_dme_to_klr;     // DME A_1_tach_pulse  (active-high)
    wire ign_out_dme_to_klr;  // DME A_5_KLR_ign_out (active-high)
    wire klr_ign_out;         // KLR spark output (NOT connected to DME ign)
    wire full_load_klr;        // KLR's own computed full_load output — see
                                // TEST_KLR_FULL_LOAD_STUCK_LOW override below,
                                // which feeds full_load (what the DME
                                // actually sees) from this instead of
                                // connecting it directly.
    wire full_load;            // KLR full_load → DME TPS ch6
    wire tdc;                  // DME crank-model TDC marker (see
                                // var_interrupt_generator/_cl) — not
                                // connected to the KLR, exposed for
                                // observation/logging at this top level
    // ── Throttle angle (what the KLR's TPS reads) ─────────────
    // throttle_pos: the throttle after its ~250 ms slew, on the DME's
    // AFM-wiper scale (0x28 closed .. 0xEB WOT) — u_dme.klr_throttle (see
    // i8051_dashboard_tb), or live_klr_tps when that's pinned. It is
    // never the AFM: the AFM lags the throttle in the closed-loop builds.
    // throttle_angle_deg: the same position in degrees, 0 closed ..
    // THROTTLE_WOT_DEG at 0xEB (nominal plate travel, for traces only).
    // klr_tps_code: the KLR's ch7 ADC reading that results (klr_tb maps
    // 26 + (pos-40)*213/195, clamps at 0xDB, ratiometric to ch3).
    // The DME's ch6 throttle switch is separate (TPS_IDLE_ADC/0xCC/0xF2
    // in i8051_dashboard_tb) and unchanged.
`ifndef THROTTLE_WOT_DEG
`define THROTTLE_WOT_DEG 90.0
`endif
    wire [7:0] throttle_pos;
    real       throttle_angle_deg;
    always @(*) throttle_angle_deg = (throttle_pos <= 8'd40) ? 0.0
                                   : (throttle_pos - 40) * `THROTTLE_WOT_DEG / 195.0;
    wire [7:0] klr_tps_code = u_klr.adc_ch7;
`ifdef LIVE_DEBUG
    // ── Live-debugger inputs ──────────────────────────────────
    // Written between evals by dme_klr/live/sim_main.cpp when the web UI
    // changes a control; read by the DME/KLR sub-testbenches under LIVE.
    // The engine runs on the closed-loop model (CL_MODE + AFM_CL_RAMP):
    // live_tps is the driver's throttle; AFM follows it ~250 ms later,
    // the firmware fuels for that airflow and RPM comes out of the
    // torque balance in var_interrupt_gen_cl.v. 16'hFFFF on live_rpm /
    // live_afm / live_boost means "use the model"; any other value pins
    // that signal.
    reg [15:0] live_rpm       /*verilator public_flat_rw*/ = 16'hFFFF;
    reg [15:0] live_afm       /*verilator public_flat_rw*/ = 16'hFFFF;
    reg [7:0]  live_tps       /*verilator public_flat_rw*/ = 8'h28;     // idle throttle
    // Warm-idle temps through the ROM's NTC map (see ntc_celsius in
    // i8051_dashboard_tb.v): raw 0x31 -> lin 0xC1 = 85 C (184 F) coolant,
    // raw 0x9E -> lin 0x5D = 20 C intake air
    reg [7:0]  live_coolant   /*verilator public_flat_rw*/ = 8'h31;
    reg [7:0]  live_airtemp   /*verilator public_flat_rw*/ = 8'h9E;
    reg [7:0]  live_battery   /*verilator public_flat_rw*/ = `_BATTERY;
    reg [7:0]  live_altitude  /*verilator public_flat_rw*/ = `_ALTITUDE;
    reg [7:0]  live_fuel_qual /*verilator public_flat_rw*/ = `_FUEL_QUAL;
    reg [15:0] live_boost     /*verilator public_flat_rw*/ = 16'hFFFF;  // KLR MAP (ch4)
    // Pins used by the open-loop log replay (dme_klr/replay/); same
    // 16'hFFFF / 8'hFF = "use the model" convention as above.
    reg [15:0] live_dme_tps   /*verilator public_flat_rw*/ = 16'hFFFF;  // DME ADC ch6 (throttle switch)
    reg [15:0] live_klr_tps   /*verilator public_flat_rw*/ = 16'hFFFF;  // throttle_pos (KLR TPS), 0x28 closed .. 0xEB WOT
    reg [15:0] live_o2        /*verilator public_flat_rw*/ = 16'hFFFF;  // {o2_7, o2_6}: 0 lean, 1 cross, 3 rich
    reg [15:0] live_knock     /*verilator public_flat_rw*/ = 16'hFFFF;  // 1: crank-synced knock on the KLR knock_sensor (klr_knock_gen.v)
    reg [7:0]  live_ac        /*verilator public_flat_rw*/ = 8'h00;     // DME T1 (P3.5): 1 = AC compressor on
    reg [7:0]  live_cat       /*verilator public_flat_rw*/ = 8'h00;     // DME T0 (P3.4): 0 = catalytic converter fitted, 1 = none
    // Knock for a set number of crank revolutions (live panel): N > 0
    // injects the live_knock = 1 drop on the next N TDCs; klr_knock_gen
    // counts it down
    reg [15:0] live_knock_revs /*verilator public_flat_rw*/ = 16'd0;
    // Snapshot interval (the dashboard's RESOLUTION box, sim_main
    // "interval <ms>"): 0 = DASH_INTERVAL_MS, else this many simulated ms
    // between DS snapshots (and lookup re-logs). live_dash_eff is the
    // interval in use, for sim_main to report.
    reg  [31:0] live_dash_ms  /*verilator public_flat_rw*/ = 32'd0;
    wire [31:0] live_dash_eff /*verilator public_flat_rd*/ =
        (live_dash_ms != 32'd0) ? live_dash_ms : `VAL_DASH_INTERVAL_MS;
    // Snapshot on demand: sim_main bumps req, the scheduler below emits
    // one DS pair and copies req to ack.
    // KLR ram 3Ah / 48h for the log replay's knock filter
    // (replay_main.cpp): the KLR only counts a knock while 3Ah > 48h
    wire [7:0] live_klr_ram3a /*verilator public_flat_rd*/ = u_klr.top.i8048_core_1.ram[7'h3A];
    wire [7:0] live_klr_ram48 /*verilator public_flat_rd*/ = u_klr.top.i8048_core_1.ram[7'h48];
    reg [31:0] live_snap_req  /*verilator public_flat_rw*/ = 32'd0;
    reg [31:0] live_snap_ack  /*verilator public_flat_rd*/ = 32'd0;
    // What rpm / afm / boost read right now, model or pinned: a snapshot
    // load pins the auto ones to these so the engine holds that point
`ifdef CL_MODE
    wire [15:0] live_rpm_now   /*verilator public_flat_rd*/ = u_dme.var_interrupt_generator_1.rpm_fp / `CL_INERTIA;
`else
    wire [15:0] live_rpm_now   /*verilator public_flat_rd*/ = 16'hFFFF;   // no torque model to pin from
`endif
    wire [7:0]  live_afm_now   /*verilator public_flat_rd*/ = u_dme.adc_ch0;
    wire [7:0]  live_boost_now /*verilator public_flat_rd*/ = u_klr.adc_ch4;
`ifdef LIVE
    assign throttle_pos = (live_klr_tps == 16'hFFFF) ? u_dme.klr_throttle   // throttle after its slew (see i8051_dashboard_tb)
                                                     : live_klr_tps[7:0];
`else
    assign throttle_pos = u_dme.klr_throttle;   // the test's own throttle script
`endif

    // Instruction-start trackers for breakpoints, stepping and the PC
    // trace. *_ipc is the address of the opcode most recently fetched and
    // *_icount bumps once per instruction; sim_main watches the count.
    // DME: opcode latch happens at S3P2 (osc_cnt==5) outside cycle 2 and
    // outside interrupt entry — the same condition i8051_core uses.
    // KLR: state 1 of a first machine cycle drives the opcode address.
    // Register context captured with each traced instruction, before it runs:
    // ctx0 = A B PSW SP DPH DPL [operand byte 1] [operand byte 2] (iram at
    // the addresses in the instruction's 2nd/3rd bytes), ctx1 = R0..R7 of the
    // active bank, ctx2 = @R0 @R1 code[A+DPTR] code[A+PC+1] [bit byte: iram
    // 20h + (operand byte 1 >> 3), the byte holding a bit operand] 0 0 0.
    `define LCPU  u_dme.i8051_top.u_cpu
    `define LROM  u_dme.i8051_top.u_eprom.mem
    `define LBANK(n) `LCPU.iram[{3'b000, `LCPU.psw[4:3], 3'd n}]
    reg [63:0] live_dme_ctx0   /*verilator public_flat_rd*/ = 64'd0;
    reg [63:0] live_dme_ctx1   /*verilator public_flat_rd*/ = 64'd0;
    reg [63:0] live_dme_ctx2   /*verilator public_flat_rd*/ = 64'd0;
    // KLR: ctx0 = A PSW T P1 P2 {F0,F1} @R0 @R1, ctx1 = R0..R7 of the active bank
    `define KCPU  u_klr.top.i8048_core_1
    `define KBANK(n) `KCPU.ram[(`KCPU.psw[4] ? 7'h18 : 7'h00) + 7'd n]
    reg [63:0] live_klr_ctx0   /*verilator public_flat_rd*/ = 64'd0;
    reg [63:0] live_klr_ctx1   /*verilator public_flat_rd*/ = 64'd0;
    reg [15:0] live_dme_ipc    /*verilator public_flat_rd*/ = 16'd0;
    reg [31:0] live_dme_icount /*verilator public_flat_rd*/ = 32'd0;
    reg [15:0] live_klr_ipc    /*verilator public_flat_rd*/ = 16'd0;
    reg [31:0] live_klr_icount /*verilator public_flat_rd*/ = 32'd0;
    always @(posedge u_dme.i8051_top.u_cpu.clk)
        if (u_dme.i8051_top.u_cpu.res_n && u_dme.i8051_top.u_cpu.osc_cnt == 4'd5 &&
            !u_dme.i8051_top.u_cpu.cycle_2 && !u_dme.i8051_top.u_cpu.irq_pending) begin
            live_dme_ipc    <= u_dme.i8051_top.u_cpu.pc;
            live_dme_icount <= live_dme_icount + 32'd1;
            live_dme_ctx0   <= {`LCPU.acc, `LCPU.b_reg, `LCPU.psw, `LCPU.sp, `LCPU.dph, `LCPU.dpl,
                                `LCPU.iram[`LROM[(`LCPU.pc + 16'd1) & 16'h1FFF] & 8'h7F],
                                `LCPU.iram[`LROM[(`LCPU.pc + 16'd2) & 16'h1FFF] & 8'h7F]};
            live_dme_ctx1   <= {`LBANK(0), `LBANK(1), `LBANK(2), `LBANK(3),
                                `LBANK(4), `LBANK(5), `LBANK(6), `LBANK(7)};
            live_dme_ctx2   <= {`LCPU.iram[`LBANK(0) & 8'h7F], `LCPU.iram[`LBANK(1) & 8'h7F],
                                `LROM[({`LCPU.dph, `LCPU.dpl} + {8'd0, `LCPU.acc}) & 16'h1FFF],
                                `LROM[(`LCPU.pc + 16'd1 + {8'd0, `LCPU.acc}) & 16'h1FFF],
                                `LCPU.iram[{3'b010, `LROM[(`LCPU.pc + 16'd1) & 16'h1FFF][6:3]}],
                                24'd0};
        end
    // DME stack tagging for the debugger's stack dump: what wrote each stack
    // byte. SP +2 with PC on an interrupt vector = interrupt entry ('i' low,
    // 'I' high byte), other SP +2 = call ('c'/'C'), SP +1 = PUSH ('p', with
    // the PUSH instruction's address). SP and PC update on the same edge, so
    // compare against the previous clock's SP.
    reg [7:0]  live_stk_tag [0:127];
    reg [15:0] live_stk_src [0:127];
    reg [7:0]  live_prev_sp = 8'h07;
    integer    live_stk_i;
    initial for (live_stk_i = 0; live_stk_i < 128; live_stk_i = live_stk_i + 1) live_stk_tag[live_stk_i] = "-";
    always @(posedge u_dme.i8051_top.u_cpu.clk) begin
        if (u_dme.i8051_top.u_cpu.sp == live_prev_sp + 8'd2) begin
            if (u_dme.i8051_top.u_cpu.pc == 16'h0003 || u_dme.i8051_top.u_cpu.pc == 16'h000B ||
                u_dme.i8051_top.u_cpu.pc == 16'h0013 || u_dme.i8051_top.u_cpu.pc == 16'h001B ||
                u_dme.i8051_top.u_cpu.pc == 16'h0023) begin
                live_stk_tag[(live_prev_sp + 8'd1) & 8'h7F] <= "i";
                live_stk_tag[(live_prev_sp + 8'd2) & 8'h7F] <= "I";
            end else begin
                live_stk_tag[(live_prev_sp + 8'd1) & 8'h7F] <= "c";
                live_stk_tag[(live_prev_sp + 8'd2) & 8'h7F] <= "C";
            end
        end else if (u_dme.i8051_top.u_cpu.sp == live_prev_sp + 8'd1) begin
            live_stk_tag[(live_prev_sp + 8'd1) & 8'h7F] <= "p";
            live_stk_src[(live_prev_sp + 8'd1) & 8'h7F] <= live_dme_ipc;
        end
        live_prev_sp <= u_dme.i8051_top.u_cpu.sp;
    end
    always @(posedge u_klr.top.i8048_core_1.clk)
        if (u_klr.top.i8048_core_1.res_n && u_klr.top.i8048_core_1.state_clk_en &&
            u_klr.top.i8048_core_1.state == 3'd1 && !u_klr.top.i8048_core_1.cycle_2) begin
            live_klr_ipc    <= {4'd0, u_klr.top.i8048_core_1.pc};
            live_klr_icount <= live_klr_icount + 32'd1;
            live_klr_ctx0   <= {`KCPU.acc, `KCPU.psw, `KCPU.timer_val, `KCPU.p1, `KCPU.p2,
                                6'd0, `KCPU.f0, `KCPU.f1,
                                `KCPU.ram[`KBANK(0) & 8'h7F], `KCPU.ram[`KBANK(1) & 8'h7F]};
            live_klr_ctx1   <= {`KBANK(0), `KBANK(1), `KBANK(2), `KBANK(3),
                                `KBANK(4), `KBANK(5), `KBANK(6), `KBANK(7)};
        end

    // Ignition pulse widths for the web UI's engine row and charts:
    // DME A_5 ign out (active-high) and the KLR spark output. Pulses
    // under 100 us are the KLR's wait_ign_2 re-assertion artifacts
    // (see klr_phase_monitor.v) and are skipped.
    time live_dme_ign_rise = 0, live_klr_ign_rise = 0;
    always @(posedge ign_out_dme_to_klr) live_dme_ign_rise = $time;
    always @(negedge ign_out_dme_to_klr)
        if ($time - live_dme_ign_rise >= 100_000)
            $display("SIM: [IGN] dme t_ns=%0d width_ns=%0d", $time, $time - live_dme_ign_rise);
    // Injector: fire_inj drives P1.0 (A_0_inj_driver) low and the T0
    // overflow ISR sets it high again, so the low time is the real pulse.
    time live_inj_fall = 0;
    always @(negedge u_dme.A_0_inj_driver) live_inj_fall = $time;
    always @(posedge u_dme.A_0_inj_driver)
        if (live_inj_fall != 0)
            $display("SIM: [INJ] t_ns=%0d width_ns=%0d", $time, $time - live_inj_fall);
    // DME tach (A_1, feeds the KLR's ign_in): the DME's own spark command,
    // which the KLR copies to its coil output after any knock retard.
    // The log replay measures that retard against it.
    time live_tach_rise = 0;
    always @(posedge tach_dme_to_klr) live_tach_rise = $time;
    always @(negedge tach_dme_to_klr)
        if (live_tach_rise != 0)
            $display("SIM: [TACH] t_ns=%0d width_ns=%0d", $time, $time - live_tach_rise);
    always @(posedge klr_ign_out) live_klr_ign_rise = $time;
    always @(negedge klr_ign_out)
        if ($time - live_klr_ign_rise >= 100_000)
            $display("SIM: [IGN] klr t_ns=%0d width_ns=%0d", $time, $time - live_klr_ign_rise);
`else
    assign throttle_pos = u_dme.klr_throttle;   // see i8051_dashboard_tb
`endif

    // ── Spark angles vs TDC ────────────────────────────────────
    // Crank position in half-teeth since the reference mark, counted from
    // the crank model's own edges, so the angles don't depend on RPM or on
    // what the firmware believes. The ref mark is 60 deg (44 half-teeth)
    // before the TDC that follows it (the model's tdc marker, 22 teeth on)
    // and the other TDC of the revolution is 180 deg (132 half-teeth)
    // later: side A = the TDC after the ref mark, side B = the other one.
    // There is no cam / cylinder-1 signal, so which cylinder of a pair
    // fired is not known here.
    //
    // One line per KLR spark (IGN_OUT falling after a >= 1 ms dwell),
    // positional to keep the logs small (there's one per spark):
    //   KLR: [SPARK] <ms>,<A|B>,<dme_btdc>,<klr_btdc>,<delay_us>,<dme31><dme57><klr73><klr3F>
    // dme_btdc: the DME's spark (its tach output rising = KLR ign_in
    // falling), klr_btdc: the KLR's spark, both in degrees before the
    // TDC (their difference is the retard); delay_us = time between them,
    // the last field the four bytes in hex. RPM is in the [DS] lines.
    // dme31/dme57 are the DME's advance and accel adjustment this spark
    // was scheduled from: the firmware writes the next spark's values
    // right after it fires, so these are the ones read at the previous
    // DME spark. klr73/klr3F are the KLR's knock
    // retard slot and tip-in retard as read by the timing delay calculation
    // (0x1B2: delay = (73h + 3Fh) x the spark period) that set this spark's
    // delay. Its result in 28h/29h moves to 20h/21h at the next trigger and
    // to 25h/26h, the one in use, at the trigger after, so this is the last
    // calculation from before the DME spark two sparks back.
    integer crank_hp = -1;                     // -1 until the first ref mark
    time    crank_ref_t = 0, crank_edge_t = 0, crank_hp_ns = 0;
    always @(negedge u_dme.reference_sensor_gen) begin
        crank_hp     = 0;
        crank_ref_t  = $time;
        crank_edge_t = $time;
    end
    always @(u_dme.speed_sensor_gen)
        if (crank_hp >= 0 && $time != crank_ref_t) begin
            crank_hp_ns  = $time - crank_edge_t;
            crank_edge_t = $time;
            crank_hp     = crank_hp + 1;
        end

    // Degrees before the coming TDC (negative = after), and which TDC
    task crank_btdc(output real deg, output reg side_b);
        real pos, hp;
        begin
            if (crank_hp < 0 || crank_hp_ns == 0) begin
                deg = -999.0; side_b = 1'b0;
            end else begin
                pos = crank_hp + ($time - crank_edge_t) / (1.0 * crank_hp_ns);
                if (pos < 110.0)      begin hp = 44.0  - pos; side_b = 1'b0; end
                else if (pos < 242.0) begin hp = 176.0 - pos; side_b = 1'b1; end
                else                  begin hp = 308.0 - pos; side_b = 1'b0; end
                deg = hp * 360.0 / 264.0;
            end
        end
    endtask

    real    spk_dme_deg = -999.0, spk_klr_deg;
    reg     spk_dme_side = 1'b0, spk_klr_side;
    time    spk_dme_t = 0, spk_klr_rise = 0;
    reg [7:0] spk_dme31 = 8'h00, spk_dme57 = 8'h00, spk_nxt31 = 8'hFF, spk_nxt57 = 8'hFF;
    reg [7:0] spk_calc73 = 8'h00, spk_calc3F = 8'h00, spk_klr73 = 8'h00, spk_klr3F = 8'h00;
    reg [7:0] spk_p73_0 = 8'h00, spk_p3F_0 = 8'h00, spk_p73_1 = 8'h00, spk_p3F_1 = 8'h00;
    // KLR timing delay calculation (mov r1,#73h at 0x1B2, bank 0)
    always @(posedge u_klr.top.i8048_core_1.clk)
        if (u_klr.top.i8048_core_1.res_n && u_klr.top.i8048_core_1.state_clk_en &&
            u_klr.top.i8048_core_1.state == 3'd1 && !u_klr.top.i8048_core_1.cycle_2 &&
            u_klr.top.i8048_core_1.pc == 12'h1B2) begin
            spk_calc73 <= u_klr.top.i8048_core_1.ram[7'h73];
            spk_calc3F <= u_klr.top.i8048_core_1.ram[7'h3F];
        end
    always @(posedge tach_dme_to_klr) begin
        crank_btdc(spk_dme_deg, spk_dme_side);
        spk_dme_t = $time;
        spk_dme31 = spk_nxt31;
        spk_dme57 = spk_nxt57;
        spk_nxt31 = u_dme.i8051_top.u_cpu.iram[7'h31];
        spk_nxt57 = u_dme.i8051_top.u_cpu.iram[7'h57];
        spk_klr73 = spk_p73_1;  spk_klr3F = spk_p3F_1;
        spk_p73_1 = spk_p73_0;  spk_p3F_1 = spk_p3F_0;
        spk_p73_0 = spk_calc73; spk_p3F_0 = spk_calc3F;
    end
    always @(posedge klr_ign_out) spk_klr_rise = $time;
    always @(negedge klr_ign_out)
        // A real dwell (the shorter ones are wait_ign_2 artifacts, the
        // longer ones the port floating during a KLR reset)
        if ($time - spk_klr_rise >= 1_000_000 && $time - spk_klr_rise < 50_000_000 &&
            spk_dme_t != 0 && $time - spk_dme_t < 50_000_000) begin
            crank_btdc(spk_klr_deg, spk_klr_side);
            if (spk_dme_deg > -900.0 && spk_klr_deg > -900.0)
                $display("KLR: [SPARK] %0d,%s,%0.2f,%0.2f,%0.1f,%02h%02h%02h%02h",
                         `DME_KLR_MS, spk_klr_side ? "B" : "A", spk_dme_deg, spk_klr_deg,
                         ($time - spk_dme_t) / 1000.0,
                         spk_dme31, spk_dme57, spk_klr73, spk_klr3F);
        end

    // ── Map and table lookups (dashboard MAPS tab) ───────────────────
    // One line per lookup result, for the Numbered Maps and the Directly
    // Addressed Tables of the DME disassembly:
    //   DME: [LKUP] <ms>,M<map>,<result>,<xa>=<xv>[,<ya>=<yv>]
    //   DME: [LKUP] <ms>,T<addr>,<result>,<xa>=<xv> | in=<index>
    // M<map>: map_lookup (0x051D) with map number R2 (decimal, the
    // workbook's Map column), its result the A it returns with (ret at
    // 0x0577, same SP as the call). xa/xv (and ya/yv for a 3D map) are the
    // iram address and value of each axis the map header names, read as
    // the lookup starts. A lookup whose map number has no map (2Ah.2 set
    // on return) is not logged.
    // T<addr>: the directly addressed tables. linear_lookup (0x05CD, ret
    // 0x05D9) on 112Eh / 1296h / 1124h logs its result and its axis
    // input as <xa>=<xv>; a MOVC A,@A+DPTR with DPTR on 10F4h / 10FCh /
    // 1104h / 1140h logs the byte read and in=<index> (A); 1140h + 10h
    // and up is the 1150h table.
    // <ms> has 3 decimals (us resolution), the other fields are hex. To
    // keep the logs small a table is logged when its result changes, and
    // otherwise once per DASH_INTERVAL_MS while it is used.
    // Everything is worked out inside the instruction-start branch (no
    // continuous assigns on iram / ROM: Icarus re-evaluates those on every
    // RAM write, which made runs ~4x slower).
    // (The LIVE_DEBUG block's LCPU/LROM macros aren't defined in a plain run)
    `define LKCPU u_dme.i8051_top.u_cpu
    `define LKROM u_dme.i8051_top.u_eprom.mem
    reg  [7:0]  lk_r2   [0:127];   // pending map_lookup, by the SP of the call
    reg  [31:0] lk_ax   [0:127];   // {xa, xv, ya, yv} at the call
    reg         lk_3d   [0:127];
    reg         lk_pend [0:127];
    reg  [15:0] lk_ldp  [0:127];   // pending linear_lookup: table address
    reg  [15:0] lk_lax  [0:127];   //   {xa, xv}
    reg         lk_lpend[0:127];
    reg  [7:0]  lk_last [0:263];   // last logged result: maps 0-255, tables 256+
    reg  [63:0] lk_lt   [0:263];   // ...and when
    reg         lk_seen [0:263];
    integer     lk_i;
    initial for (lk_i = 0; lk_i < 264; lk_i = lk_i + 1) lk_seen[lk_i] = 1'b0;
    initial for (lk_i = 0; lk_i < 128; lk_i = lk_i + 1) begin lk_pend[lk_i] = 1'b0; lk_lpend[lk_i] = 1'b0; end

    // Table slot (256+) for a T address, 0 if it isn't one
    function [8:0] lk_slot(input [15:0] a);
        case (a)
            16'h10F4: lk_slot = 9'd256;  16'h10FC: lk_slot = 9'd257;
            16'h1104: lk_slot = 9'd258;  16'h1124: lk_slot = 9'd259;
            16'h112E: lk_slot = 9'd260;  16'h1140: lk_slot = 9'd261;
            16'h1150: lk_slot = 9'd262;  16'h1296: lk_slot = 9'd263;
            default:  lk_slot = 9'd0;
        endcase
    endfunction
    // Log this result now? (changed, first, or DASH_INTERVAL_MS since the last)
    function lk_due(input [8:0] s, input [7:0] v);
        lk_due = !lk_seen[s] || lk_last[s] != v ||
                 ($time - lk_lt[s]) >= `DASH_IV_NS;
    endfunction
    reg [15:0] lk_pc, lk_dptr, lk_ma, lk_ta;
    reg [6:0]  lk_sp;
    reg [7:0]  lk_idx, lk_xa, lk_n, lk_ya, lk_v;
    reg [8:0]  lk_s;
    always @(posedge u_dme.i8051_top.u_cpu.clk)
        if (u_dme.i8051_top.u_cpu.res_n && u_dme.i8051_top.u_cpu.osc_cnt == 4'd5 &&
            !u_dme.i8051_top.u_cpu.cycle_2 && !u_dme.i8051_top.u_cpu.irq_pending) begin
            lk_pc   = `LKCPU.pc;
            lk_sp   = `LKCPU.sp[6:0];
            lk_dptr = {`LKCPU.dph, `LKCPU.dpl};
            if (lk_pc == 16'h051D) begin                        // map_lookup
                // its own map address decode (0x0522-0x053E): idx = code[1090h
                // + R2]; bit 0 = 3D; the map is at code[11E0h + idx&FE] : code[+1],
                // its header: axis address, point count, the points, then the
                // second axis' header for a 3D map
                lk_idx = `LKROM[(16'h1090 + {8'd0, `LKCPU.iram[{3'b000, `LKCPU.psw[4:3], 3'd2}]}) & 16'h1FFF];
                lk_ma  = {`LKROM[(16'h11E0 + {8'd0, lk_idx & 8'hFE}) & 16'h1FFF],
                          `LKROM[(16'h11E1 + {8'd0, lk_idx & 8'hFE}) & 16'h1FFF]};
                lk_xa  = `LKROM[lk_ma & 16'h1FFF];
                lk_n   = `LKROM[(lk_ma + 16'd1) & 16'h1FFF];
                lk_ya  = `LKROM[(lk_ma + 16'd2 + {8'd0, lk_n}) & 16'h1FFF];
                lk_r2[lk_sp]   <= `LKCPU.iram[{3'b000, `LKCPU.psw[4:3], 3'd2}];
                lk_3d[lk_sp]   <= lk_idx[0];
                lk_ax[lk_sp]   <= {lk_xa, `LKCPU.iram[lk_xa[6:0]], lk_ya, `LKCPU.iram[lk_ya[6:0]]};
                lk_pend[lk_sp] <= 1'b1;
            end else if (lk_pc == 16'h0577 && lk_pend[lk_sp]) begin   // its ret
                lk_pend[lk_sp] <= 1'b0;
                lk_s = {1'b0, lk_r2[lk_sp]};
                if (!`LKCPU.iram[7'h25][2] && lk_due(lk_s, `LKCPU.acc)) begin
                    lk_seen[lk_s] <= 1'b1; lk_last[lk_s] <= `LKCPU.acc; lk_lt[lk_s] <= $time;
                    if (lk_3d[lk_sp])
                        $display("DME: [LKUP] %0.3f,M%0d,%02h,%02h=%02h,%02h=%02h", $time / 1.0e6,
                                 lk_r2[lk_sp], `LKCPU.acc, lk_ax[lk_sp][31:24], lk_ax[lk_sp][23:16],
                                 lk_ax[lk_sp][15:8], lk_ax[lk_sp][7:0]);
                    else
                        $display("DME: [LKUP] %0.3f,M%0d,%02h,%02h=%02h", $time / 1.0e6,
                                 lk_r2[lk_sp], `LKCPU.acc, lk_ax[lk_sp][31:24], lk_ax[lk_sp][23:16]);
                end
            end else if (lk_pc == 16'h05CD) begin               // linear_lookup
                lk_xa = `LKROM[lk_dptr & 16'h1FFF];
                lk_ldp[lk_sp]   <= lk_dptr;
                lk_lax[lk_sp]   <= {lk_xa, `LKCPU.iram[lk_xa[6:0]]};
                lk_lpend[lk_sp] <= 1'b1;
            end else if (lk_pc == 16'h05D9 && lk_lpend[lk_sp]) begin  // its ret
                lk_lpend[lk_sp] <= 1'b0;
                lk_s = lk_slot(lk_ldp[lk_sp]);
                if (lk_s != 9'd0 && lk_due(lk_s, `LKCPU.acc)) begin
                    lk_seen[lk_s] <= 1'b1; lk_last[lk_s] <= `LKCPU.acc; lk_lt[lk_s] <= $time;
                    $display("DME: [LKUP] %0.3f,T%04h,%02h,%02h=%02h", $time / 1.0e6,
                             lk_ldp[lk_sp], `LKCPU.acc, lk_lax[lk_sp][15:8], lk_lax[lk_sp][7:0]);
                end
            end else if ((lk_dptr == 16'h10F4 || lk_dptr == 16'h10FC ||
                          lk_dptr == 16'h1104 || lk_dptr == 16'h1140) &&
                         `LKROM[lk_pc & 16'h1FFF] == 8'h93) begin       // MOVC A,@A+DPTR
                lk_ta = (lk_dptr == 16'h1140 && `LKCPU.acc >= 8'h10) ? 16'h1150 : lk_dptr;
                lk_s  = lk_slot(lk_ta);
                lk_v  = `LKROM[(lk_dptr + {8'd0, `LKCPU.acc}) & 16'h1FFF];
                if (lk_due(lk_s, lk_v)) begin
                    lk_seen[lk_s] <= 1'b1; lk_last[lk_s] <= lk_v; lk_lt[lk_s] <= $time;
                    $display("DME: [LKUP] %0.3f,T%04h,%02h,in=%02h", $time / 1.0e6,
                             lk_ta, lk_v, `LKCPU.acc - (lk_ta == 16'h1150 ? 8'h10 : 8'h00));
                end
            end
        end

    // ── KLR map and table lookups (dashboard KLR MAPS tab) ───────────
    // One line per result of the KLR's maps and tables (klr/disassemble/
    // klr_maps.py, and the maps_index sheet of 87KLR951.xlsx):
    //   KLR: [LKUP] <ms>,T<addr>,<result>,<xa>=<xv>[,<ya>=<yv>]
    // T0C00 target boost map  (A after the 0C80h interpolation, at 0A95h;
    //       51h = it - 57h), inputs 43h (throttle) and 44h (rpm index)
    // T0B00 CV open-loop map  (A at 0A89h, to 68h), inputs 43h, 44h
    // T0A00 rpm axis table    (A at the ret 0A81h, to 44h), inputs 24h
    //       and bank 0 R7 (07h), which rpm_axis_lookup adds in
    // T0925.. the rpm constants: one id per 9-byte entry (0925h, 092Eh,
    //       ...), the value at the mov @r1,a (0916h), input 44h
    // T0992 boost PID gain    (A at 0921h, to 6Bh), inputs 43h, 44h
    // Each is logged when its result changes, otherwise once per
    // DASH_INTERVAL_MS, like the DME lookups. A hook only fires if the ROM
    // has the expected opcode at its address, so an image with other code
    // there logs nothing for it.
    `define KLKCPU u_klr.top.i8048_core_1
    `define KLKROM u_klr.top.rom_1.rom
    `define KLKREG(n) `KLKCPU.ram[(`KLKCPU.psw[4] ? 7'h18 : 7'h00) + 7'd n]
    reg  [7:0]  klk_last [0:31];
    reg  [63:0] klk_lt   [0:31];
    reg         klk_seen [0:31];
    initial for (lk_i = 0; lk_i < 32; lk_i = lk_i + 1) klk_seen[lk_i] = 1'b0;
    function klk_due(input [4:0] s, input [7:0] v);
        klk_due = !klk_seen[s] || klk_last[s] != v ||
                  ($time - klk_lt[s]) >= `DASH_IV_NS;
    endfunction
    reg [11:0] klk_pc;
    reg [15:0] klk_ta;
    reg [7:0]  klk_r2, klk_xa, klk_ya;
    reg [4:0]  klk_s;
    reg [1:0]  klk_n;      // inputs to print: 1 or 2
    reg        klk_hit;
    always @(posedge u_klr.top.i8048_core_1.clk)
        if (`KLKCPU.res_n && `KLKCPU.state_clk_en && `KLKCPU.state == 3'd1 && !`KLKCPU.cycle_2) begin
            klk_pc  = `KLKCPU.pc;
            klk_hit = 1'b1;
            klk_n   = 2'd2;
            klk_xa  = 8'h43; klk_ya = 8'h44;
            if (klk_pc == 12'hA95 && `KLKROM[12'hA95] == 8'h37) begin          // cpl a after the boost map
                klk_ta = 16'h0C00; klk_s = 5'd0;
            end else if (klk_pc == 12'hA89 && `KLKROM[12'hA89] == 8'hB9) begin // mov r1,#68h after the CV map
                klk_ta = 16'h0B00; klk_s = 5'd1;
            end else if (klk_pc == 12'hA81 && `KLKROM[12'hA81] == 8'h83) begin // ret of rpm_axis_lookup
                klk_ta = 16'h0A00; klk_s = 5'd2; klk_xa = 8'h24; klk_ya = 8'h07;
            end else if (klk_pc == 12'h921 && `KLKROM[12'h921] == 8'hB9) begin // mov r1,#6Bh after the gain read
                klk_r2 = `KLKREG(2);
                klk_ta = 16'h0900 + {8'd0, klk_r2} + 16'd1; klk_s = 5'd3;
            end else if (klk_pc == 12'h916 && `KLKROM[12'h916] == 8'hA1) begin // mov @r1,a: one rpm constant
                klk_r2 = `KLKREG(2) - 8'd9;                                     // r2 already points at the next entry
                klk_ta = 16'h0900 + {8'd0, klk_r2};
                klk_s  = 5'd4 + ((klk_r2 - 8'h25) / 8'd9 > 8'd27 ? 5'd27 : (klk_r2 - 8'h25) / 8'd9);
                klk_xa = 8'h44; klk_n = 2'd1;
            end else
                klk_hit = 1'b0;
            if (klk_hit && klk_due(klk_s, `KLKCPU.acc)) begin
                klk_seen[klk_s] <= 1'b1; klk_last[klk_s] <= `KLKCPU.acc; klk_lt[klk_s] <= $time;
                if (klk_n == 2'd2)
                    $display("KLR: [LKUP] %0.3f,T%04h,%02h,%02h=%02h,%02h=%02h", $time / 1.0e6,
                             klk_ta, `KLKCPU.acc, klk_xa, `KLKCPU.ram[klk_xa[6:0]],
                             klk_ya, `KLKCPU.ram[klk_ya[6:0]]);
                else
                    $display("KLR: [LKUP] %0.3f,T%04h,%02h,%02h=%02h", $time / 1.0e6,
                             klk_ta, `KLKCPU.acc, klk_xa, `KLKCPU.ram[klk_xa[6:0]]);
            end
        end

    // ── Always-on FST visibility for the interconnect above ──────────
    // klr_vcd_combined.v (compiled into this build, in files/files_cl)
    // was meant to add these to the FST but its module is never
    // instantiated anywhere, so its dumpvars calls never ran — see the
    // ORPHANED MODULE note at the top of that file. Added here instead,
    // directly in this module (guaranteed to run, since this IS the
    // top-level testbench), so the six DME<->KLR interconnect signals
    // show up in every FST trace regardless of debug flags. One
    // $dumpvars line per signal (not a level-1 sweep of the whole
    // module) so dme_clk and the snapshot-task bookkeeping regs
    // (snapshot_busy, next_snap_ns) stay out of the always-on trace.
    // The DME/KLR sub-testbenches each already set up their own
    // $dumpfile (vcd.v / klr_vcd.v); this only adds more variables to
    // whichever of those opens the file first — no new $dumpfile call
    // needed here. #1: after vcd.v's $dumpfile — Verilator drops a
    // $dumpvars that comes first, and initial-block order isn't defined.
    // iverilog ignores any $dumpvars after t=0, so there it's #0 (still
    // t=0, after vcd.v's undelayed $dumpfile).
    // The KLR's trigger and ign inputs after the wire-loss faults, declared
    // here because the $dumpvars below names them (Icarus Verilog 13
    // doesn't allow a use before the declaration); assigned further down.
    wire ext_trigger, ext_ign;
    initial begin
`ifdef VERILATOR
        #1;
`else
        #0;
`endif
        $dumpvars(1, tach_dme_to_klr);
        $dumpvars(1, ign_out_dme_to_klr);
        $dumpvars(1, klr_ign_out);
        $dumpvars(1, full_load);
        $dumpvars(1, tdc);
        $dumpvars(1, throttle_pos);
        $dumpvars(1, throttle_angle_deg);
        $dumpvars(1, klr_tps_code);
        $dumpvars(1, ext_trigger);
        $dumpvars(1, ext_ign);
    end

    // ── DME sub-TB ───────────────────────────────────────────
    // ign tied high — ignition switch always on.
    // klr_ign_out is the spark output and must NOT drive ign (key switch).
    i8051_dashboard_tb u_dme (
        .ign            ( 1'b1               ),
        .A_1_tach_pulse ( tach_dme_to_klr    ),
        .A_5_KLR_ign_out( ign_out_dme_to_klr ),
        .full_load      ( full_load          ),
        .tdc            ( tdc                )
    );

    wire dme_clk = u_dme.clk;

    // ── ext_trigger / ext_ign wire loss faults ────────────────
    // trigger_in is wired directly to the KLR's CPU /RESET (res_n =
    // ~trigger_in — see klr_top.v header) and ign_in drives T1/INT.
    // Both wires are driven straight through from the DME with no
    // fault-injection point of their own, so — same pattern as
    // KLR_FULL_LOAD_STUCK_LOW below — the generator-driven signal is
    // renamed to _gen and a fault-gated override sits between it and
    // the KLR port.
    //   KLR_TRIGGER_STUCK_HIGH → trigger_in stuck 1 → res_n stuck 0 →
    //     KLR CPU held in permanent reset (never runs again). Real-run
    //     confirmed: no DTC (CPU can't run diagnostic code), but the
    //     DME's own IGN_OUT stops pulsing (a general "KLR not
    //     responding" fail-safe — see cl_ramp_to_3000_KLR_TRIGGER_STUCK_HIGH
    //     in validate_dash_log.py) and full_load reads stuck asserted.
    //   KLR_TRIGGER_STUCK_LOW  → trigger_in stuck 0 (its normal idle
    //     level between pulses) → res_n stuck 1 → the OPPOSITE failure
    //     mode from STUCK_HIGH: the CPU runs continuously and NEVER
    //     gets reset again, so it free-runs forever without ever
    //     re-syncing to TDC — unconfirmed against real hardware yet.
    //   KLR_IGN_IN_STUCK_HIGH  → ign_in stuck 1 → T1/INT frozen high;
    //     the CPU keeps running (trigger_in still resets it each
    //     cycle) but any T1/INT-based timing on the DME ign signal is
    //     lost. Real-run confirmed: full_load/TPS-bucket unaffected,
    //     but the same DME IGN_OUT fail-safe as TRIGGER_STUCK_HIGH
    //     still trips.
    //   KLR_IGN_IN_STUCK_LOW   → ign_in stuck 0 (its normal idle level)
    //     instead — unconfirmed against real hardware yet.
    // A fault time can't sit in the continuous assign itself: Icarus does
    // not re-evaluate an assign when only $time changes, so the fault
    // would land at the next edge of the _gen signal, not at the fault
    // time, while Verilator applies it on time. A flag clocked by dme_clk
    // fires at the same clock in both.
    wire ext_trigger_gen = ~ign_out_dme_to_klr;  // DME A_5_KLR_ign_out → KLR trigger (inverted)
    wire ext_ign_gen     = ~tach_dme_to_klr;     // DME tach → KLR ign (inverted)

`ifndef SER_PEEK_WALK_MS            // SER_PEEK_WALK: when the walk starts
  `define SER_PEEK_WALK_MS 0
`endif
`ifndef SER_WRITE_SWEEP_MS          // SER_WRITE_SWEEP: when the sweep starts
  `define SER_WRITE_SWEEP_MS 0
`endif
`ifndef TRIGGER_LOSS_T_MS
  `define TRIGGER_LOSS_T_MS 3000
`endif
`ifndef IGN_IN_LOSS_T_MS
  `define IGN_IN_LOSS_T_MS 3000
`endif
    // KLR_TRIGGER_STUCK_HIGH/LOW, KLR_IGN_IN_STUCK_HIGH/LOW: the line
    // sticks at TRIGGER_LOSS_T_MS / IGN_IN_LOSS_T_MS (HIGH wins if both)
    reg ext_trigger_lost = 1'b0;
    always @(posedge dme_clk)
        if ((`OPT_KLR_TRIGGER_STUCK_HIGH || `OPT_KLR_TRIGGER_STUCK_LOW) &&
            `DME_KLR_MS >= `VAL_TRIGGER_LOSS_T_MS) ext_trigger_lost <= 1'b1;
    assign ext_trigger = !ext_trigger_lost ? ext_trigger_gen : `OPT_KLR_TRIGGER_STUCK_HIGH;

    reg ext_ign_lost = 1'b0;
    always @(posedge dme_clk)
        if ((`OPT_KLR_IGN_IN_STUCK_HIGH || `OPT_KLR_IGN_IN_STUCK_LOW) &&
            `DME_KLR_MS >= `VAL_IGN_IN_LOSS_T_MS) ext_ign_lost <= 1'b1;
    assign ext_ign = !ext_ign_lost ? ext_ign_gen : `OPT_KLR_IGN_IN_STUCK_HIGH;

    // ── KLR sub-TB ───────────────────────────────────────────
    // EXT_STIM=1: external trigger/ign signals (not internal generator)
    // Signals are inverted: DME active-high → KLR active-low inputs
    klr_tb #(.EXT_STIM(1)) u_klr (
        .ext_trigger     ( ext_trigger         ),  // DME A_5_KLR_ign_out → KLR trigger (inverted)
        .ext_ign         ( ext_ign             ),  // DME tach → KLR ign (inverted)
        .ign_out         ( klr_ign_out         ),  // KLR spark output → DME ign
        .full_load       ( full_load_klr       ),  // KLR WOT flag → DME
        .tps_wiper       ( throttle_pos        ),  // throttle → KLR TPS angle ch7
        .rpm_in          ( u_dme.ref_rpm       ),  // DME tick-measured RPM (reg [31:0]) → KLR -DBOOST map (unused if -DBOOST undefined)
        .fuel_cut        ( u_dme.inj_skipping ),  // DME fuel cut or rev limit → KLR -DBOOST model (turbo spools down)
        .dme_clk         ( dme_clk             ),  // → KLR's knock_signal_generator (crank-synced knock_sensor waveform)
        .tdc             ( tdc                 ),  // → KLR's knock_signal_generator
        .speed_sensor    ( u_dme.speed_sensor  )   // → KLR's knock_signal_generator
    );

    // KLR_FULL_LOAD_STUCK_LOW: the KLR's own full_load computation
    // stays correct internally (its own ram[0x3A]/DTC logic sees
    // whatever real throttle position exists), but the wire actually
    // reaching the DME is stuck low — the WOT indication itself "isn't
    // happening" regardless of real throttle, e.g. a broken P1.5 wire
    // or connector between the two ECUs. Distinct from the KLR-side TPS
    // faults (which make the KLR itself misread throttle position) —
    // here the KLR computes full_load correctly, it just never reaches
    // the DME. No TEST_ prefix, matching the KLR_BATT_LOW/
    // KLR_TPS_SUPPLY_LOW/etc. naming convention for KLR-side fault
    // macros elsewhere in this test suite.
// KLR_FULL_LOAD_STUCK_HIGH: the same wire stuck at the WOT level, so the
// DME sees full load whenever the throttle is off idle.
    assign full_load = `OPT_KLR_FULL_LOAD_STUCK_LOW  ? 1'b0 :
                       `OPT_KLR_FULL_LOAD_STUCK_HIGH ? 1'b1 : full_load_klr;

    // ── Serial diagnostic tester (DME RXD/TXD) ───────────────
    // A model of a tester on the DME's diagnostic serial port, for the
    // firmware's polled serial routine (0x1E6D, reached from the main
    // loop through 0x101A):
    //   - init_serial (0x1E53) sends FF with the 9th bit set; a tester
    //     that answers FF before the first poll selects streaming mode
    //     (no answer: 23h.7 is set and TXD becomes the lambda output).
    //   - Each poll then sends RPM (37h), advance (31h), fuel (4B:4A>>5
    //     or 0 in fuel cut), the RAM byte at the address held in 7Ah,
    //     and a slot byte with the 9th bit set: slot 29h = 0..5 sends the
    //     byte at 13h 12h 11h 49h 2Fh 10h (table 11D4h), then FF.
    //   - A byte received after slot k is stored on the next poll at
    //     table 11DAh[k]: 7Ah 26h 28h 7Ah 26h 28h (the code at 0x1EA7).
    // The tester answers slots 0 and 3 with live_ser_peek, so the peek
    // byte of the following frames is RAM[live_ser_peek]. With
    // live_ser_tester[1] set it also answers slots 1 and 4 with
    // live_ser_w26 and slots 2 and 5 with live_ser_w28, which the DME
    // stores in 26h and 28h; otherwise those slots go unanswered and 26h
    // and 28h keep init_serial's 00h and 80h. It also answers every FF
    // (the hello, and the end marker, which the DME ignores since 29h =
    // FF there).
    // live_ser_tester[0] = 1 connects it (+ser_tester=1 at start: the
    // stock ROM only listens for the answer to its hello at boot);
    // +ser_peek=<hex> sets the first address; +ser_w26=<hex> and
    // +ser_w28=<hex> set the bytes for 26h and 28h and turn on
    // live_ser_tester[1]. Off, RXD idles high.
    // In the 89 ROM the code that would use them (0x1F21: 26h added to
    // the ignition value in R5; 0x1F2D: 28h as a fuel multiplier through
    // 0x1DF0) is bypassed: the hooks at 0x104A and 0x1050 jump straight
    // past it, so the stored bytes have no effect on the engine there.
    // The frames the DME sends are decoded from TXD whether or not the
    // tester is on, and summarised in each snapshot's DME: [SER] line.
    reg  [7:0] live_ser_tester /*verilator public_flat_rw*/ = 8'h00;
    reg  [7:0] live_ser_peek   /*verilator public_flat_rw*/ = 8'h37;
    reg  [7:0] live_ser_w26    /*verilator public_flat_rw*/ = 8'h00;
    reg  [7:0] live_ser_w28    /*verilator public_flat_rw*/ = 8'h80;
    initial begin : ser_args
        integer v;
        if ($value$plusargs("ser_tester=%d", v)) live_ser_tester = v[7:0];
        if ($value$plusargs("ser_peek=%h", v))   live_ser_peek   = v[7:0];
        if ($value$plusargs("ser_w26=%h", v)) begin
            live_ser_w26    = v[7:0];
            live_ser_tester = live_ser_tester | 8'h02;
        end
        if ($value$plusargs("ser_w28=%h", v)) begin
            live_ser_w28    = v[7:0];
            live_ser_tester = live_ser_tester | 8'h02;
        end
        if (`OPT_SER_PEEK_WALK) begin      // see SER_PEEK_WALK below
            live_ser_tester = 8'd1;
            live_ser_peek   = 8'h10;
        end
        if (`OPT_SER_WRITE_SWEEP)          // see SER_WRITE_SWEEP below
            live_ser_tester = live_ser_tester | 8'h01;
    end
    wire ser_clk  = u_dme.i8051_top.u_cpu.clk;
    // the DME's mode-2 baud tick (16 per bit), so both ends run in step
    wire ser_tick = u_dme.i8051_top.u_cpu.baud_m2_pulse;
    wire ser_txd  = u_dme.txd;
    reg  ser_rxd_line = 1'b1;          // drives u_dme.rxd (i8051_dashboard_tb)

    // Receiver on TXD: start, D0..D7, 9th bit, stop
    reg        ser_rx_act = 1'b0;
    reg  [3:0] ser_rx_cnt = 4'd0, ser_rx_bit = 4'd0;
    reg  [8:0] ser_rx_sh  = 9'd0;
    // Frame decoder
    reg  [7:0] ser_buf [0:3];
    reg  [2:0] ser_nbuf   = 3'd0;
    reg  [2:0] ser_slot   = 3'd0;      // slot the next slot byte is
    reg  [7:0] ser_slotv [0:5];
    reg [31:0] ser_frames = 32'd0;     // complete 4-byte frames seen
    reg [31:0] ser_hellos = 32'd0;     // FF with no data bytes before it
    reg [31:0] ser_replies = 32'd0;    // bytes the tester sent
    reg  [7:0] ser_rpm = 8'd0, ser_adv = 8'd0, ser_fuel = 8'd0, ser_peekv = 8'd0;
    reg  [7:0] ser_peek_addr = 8'd0;   // 7Ah when that frame's peek byte went out
    reg  [7:0] ser_last_slot = 8'd0;
    // Transmitter on RXD: 2 idle bits, start, D0..D7, 9th bit (0), stop
    reg        ser_tx_go = 1'b0, ser_tx_busy = 1'b0;
    reg  [7:0] ser_tx_byte = 8'd0;
    reg  [3:0] ser_tx_cnt = 4'd0, ser_tx_bit = 4'd0;
    reg [12:0] ser_tx_sh = 13'h1FFF;
    integer    ser_i;
    initial for (ser_i = 0; ser_i < 6; ser_i = ser_i + 1) ser_slotv[ser_i] = 8'd0;
    initial for (ser_i = 0; ser_i < 4; ser_i = ser_i + 1) ser_buf[ser_i] = 8'd0;

    always @(posedge ser_clk) begin
        ser_tx_go <= 1'b0;
        if (ser_tick) begin
            if (!ser_rx_act) begin
                if (!ser_txd) begin
                    ser_rx_act <= 1'b1;
                    ser_rx_cnt <= 4'd0;
                    ser_rx_bit <= 4'd0;
                end
            end else begin
                ser_rx_cnt <= ser_rx_cnt + 4'd1;
                if (ser_rx_cnt == 4'd7) begin
                    if (ser_rx_bit == 4'd0) begin
                        if (ser_txd) ser_rx_act <= 1'b0;        // glitch, not a start bit
                    end else if (ser_rx_bit <= 4'd9)
                        ser_rx_sh <= {ser_txd, ser_rx_sh[8:1]};
                end
                if (ser_rx_cnt == 4'd15) begin
                    ser_rx_bit <= ser_rx_bit + 4'd1;
                    if (ser_rx_bit == 4'd10) begin               // end of the stop bit
                        ser_rx_act <= 1'b0;
                        if (!ser_rx_sh[8]) begin                 // data byte
                            if (ser_nbuf < 3'd4) ser_buf[ser_nbuf[1:0]] <= ser_rx_sh[7:0];
                            if (ser_nbuf == 3'd3) ser_peek_addr <= u_dme.i8051_top.u_cpu.iram[7'h7A];
                            if (ser_nbuf != 3'd7) ser_nbuf <= ser_nbuf + 3'd1;
                        end else begin                           // slot byte or FF
                            if (ser_nbuf == 3'd4) begin
                                ser_frames <= ser_frames + 32'd1;
                                ser_rpm  <= ser_buf[0];
                                ser_adv  <= ser_buf[1];
                                ser_fuel <= ser_buf[2];
                                ser_peekv <= ser_buf[3];
                            end
                            ser_last_slot <= ser_rx_sh[7:0];
                            if (ser_rx_sh[7:0] == 8'hFF) begin
                                if (ser_nbuf == 3'd0) ser_hellos <= ser_hellos + 32'd1;
                                ser_slot <= 3'd0;
                                if (live_ser_tester[0]) begin
                                    ser_tx_byte <= 8'hFF;
                                    ser_tx_go   <= 1'b1;
                                end
                            end else begin
                                if (ser_slot < 3'd6) ser_slotv[ser_slot] <= ser_rx_sh[7:0];
                                if (live_ser_tester[0] && (ser_slot == 3'd0 || ser_slot == 3'd3)) begin
                                    ser_tx_byte <= live_ser_peek;
                                    ser_tx_go   <= 1'b1;
                                end else if (live_ser_tester[0] && live_ser_tester[1] &&
                                             (ser_slot == 3'd1 || ser_slot == 3'd4)) begin
                                    ser_tx_byte <= live_ser_w26;
                                    ser_tx_go   <= 1'b1;
                                end else if (live_ser_tester[0] && live_ser_tester[1] &&
                                             (ser_slot == 3'd2 || ser_slot == 3'd5)) begin
                                    ser_tx_byte <= live_ser_w28;
                                    ser_tx_go   <= 1'b1;
                                end
                                if (ser_slot < 3'd6) ser_slot <= ser_slot + 3'd1;
                            end
                            ser_nbuf <= 3'd0;
                        end
                    end
                end
            end
        end
        // Transmitter: a request while busy is dropped
        if (ser_tx_go && !ser_tx_busy) begin
            ser_tx_busy <= 1'b1;
            ser_tx_cnt  <= 4'd0;
            ser_tx_bit  <= 4'd0;
            ser_tx_sh   <= {1'b1, 1'b0, ser_tx_byte, 1'b0, 2'b11};
            ser_replies <= ser_replies + 32'd1;
        end else if (ser_tx_busy && ser_tick) begin
            ser_tx_cnt <= ser_tx_cnt + 4'd1;
            if (ser_tx_cnt == 4'd0) ser_rxd_line <= ser_tx_sh[0];
            if (ser_tx_cnt == 4'd15) begin
                ser_tx_sh  <= {1'b1, ser_tx_sh[12:1]};
                ser_tx_bit <= ser_tx_bit + 4'd1;
                if (ser_tx_bit == 4'd12) begin
                    ser_tx_busy  <= 1'b0;
                    ser_rxd_line <= 1'b1;
                end
            end
        end
    end

    // ── Serial trace group (FST/VCD) ──
    // In the serial tests (SER_PEEK_WALK, SER_WRITE_SWEEP) the trace gets a
    // ser_trace scope with the iram bytes the frame and the tester touch,
    // the UART pins and both SBUF halves, with or without the debug flags.
    // $dumpvars can't name array elements, hence the wires.
    generate if (1) begin : ser_trace
        wire [7:0] r10 = u_dme.i8051_top.u_cpu.iram[7'h10];   // AFM (slot 5)
        wire [7:0] r11 = u_dme.i8051_top.u_cpu.iram[7'h11];   // battery (slot 2)
        wire [7:0] r12 = u_dme.i8051_top.u_cpu.iram[7'h12];   // air temp (slot 1)
        wire [7:0] r13 = u_dme.i8051_top.u_cpu.iram[7'h13];   // coolant (slot 0)
        wire [7:0] r26 = u_dme.i8051_top.u_cpu.iram[7'h26];   // SER_ADV_TRIM
        wire [7:0] r28 = u_dme.i8051_top.u_cpu.iram[7'h28];   // SER_FUEL_TRIM
        wire [7:0] r29 = u_dme.i8051_top.u_cpu.iram[7'h29];   // SER_SLOT
        wire [7:0] r2f = u_dme.i8051_top.u_cpu.iram[7'h2F];   // slot 4
        wire [7:0] r31 = u_dme.i8051_top.u_cpu.iram[7'h31];   // advance (frame byte 2)
        wire [7:0] r37 = u_dme.i8051_top.u_cpu.iram[7'h37];   // RPM (frame byte 1)
        wire [7:0] r49 = u_dme.i8051_top.u_cpu.iram[7'h49];   // load (slot 3)
        wire [7:0] r7a = u_dme.i8051_top.u_cpu.iram[7'h7A];   // SER_PEEK_ADDR
        wire       txd     = u_dme.txd;                       // DME TXD (P3.1)
        wire       rxd     = u_dme.rxd;                       // DME RXD (P3.0), from the tester
        wire [7:0] sbuf_tx = u_dme.i8051_top.u_cpu.sbuf_tx;
        wire [7:0] sbuf_rx = u_dme.i8051_top.u_cpu.sbuf_rx;
    end endgenerate
    initial begin
`ifdef VERILATOR
        #1;                       // after vcd.v's $dumpfile (see above)
`else
        #0;
`endif
        if (`OPT_SER_PEEK_WALK || `OPT_SER_WRITE_SWEEP)
            $dumpvars(1, ser_trace);
    end

    // ── SER_PEEK_WALK: read iram 10h-62h and 7Ah-7Fh through the peek ──
    // The tester is on from t=0 and its peek address starts at 10h. The
    // DME reads the peek byte at 0x1EC8 (mov A,@R1 with R1 = 7Ah), so
    // the testbench samples 7Ah and RAM[7Ah] on every cycle the PC sits
    // there (the last sample before it moves is the value the DME read;
    // if an interrupt is taken there it is resampled on return). When a
    // frame completes (at or after SER_PEEK_WALK_MS, so a ramp test can
    // wait for its target RPM) whose sample shows 7Ah = the address under test,
    // the peek byte decoded from TXD is checked against that sample:
    //   DME: [SERPEEK] <ms>,<addr>,<peek byte from TXD>,<RAM>,<ok|BAD>
    // then the peek moves to the next address: 10h..62h, then 7Ah..7Fh
    // (at 7Ah the peek reads its own address back). After 7Fh:
    //   DME: [SERPEEK] DONE pass=<n> fail=<n> 10-62=<bytes> 7A-7F=<bytes>
    localparam [7:0] SPW_FIRST = 8'h10, SPW_GAP_LO = 8'h62, SPW_GAP_HI = 8'h7A,
                     SPW_LAST  = 8'h7F;
    reg  [7:0] spw_addr = SPW_FIRST;     // address under test
    reg  [7:0] spw_snap_a = 8'h00, spw_snap_v = 8'h00;
    reg        spw_done = 1'b0;
    integer    spw_pass = 0, spw_fail = 0;
    reg  [7:0] spw_bytes [0:127];
    integer    spw_j;
    wire [7:0] spw_next = (spw_addr == SPW_GAP_LO) ? SPW_GAP_HI : spw_addr + 8'd1;
    always @(posedge ser_clk) begin
        if (u_dme.i8051_top.u_cpu.pc == 16'h1EC8) begin
            spw_snap_a <= u_dme.i8051_top.u_cpu.iram[7'h7A];
            spw_snap_v <= u_dme.i8051_top.u_cpu.iram[u_dme.i8051_top.u_cpu.iram[7'h7A][6:0]];
        end
    end
    // a frame completes on the slot byte after 4 data bytes
    wire spw_frame = ser_tick && ser_rx_act && ser_rx_cnt == 4'd15 && ser_rx_bit == 4'd10 &&
                     ser_rx_sh[8] && ser_nbuf == 3'd4;
    always @(posedge ser_clk) begin
        if (`OPT_SER_PEEK_WALK && spw_frame && !spw_done && spw_snap_a == spw_addr &&
            `DME_KLR_MS >= `VAL_SER_PEEK_WALK_MS) begin
            // === (not ==): a RAM byte the firmware never writes (7Ch on
            // the 89 ROM) powers up X under Icarus (0 under Verilator's
            // --x-initial), so the DME sends X and the RAM holds X. That
            // is a correct read; == would make it X, i.e. a fail.
            $display("DME: [SERPEEK] %0d,%02h,%02h,%02h,%0s", `DME_KLR_MS, spw_addr,
                     ser_buf[3], spw_snap_v, (ser_buf[3] === spw_snap_v) ? "ok" : "BAD");
            spw_bytes[spw_addr[6:0]] = ser_buf[3];
            if (ser_buf[3] === spw_snap_v) spw_pass = spw_pass + 1;
            else                          spw_fail = spw_fail + 1;
            if (spw_addr == SPW_LAST) begin
                spw_done <= 1'b1;
                $write("DME: [SERPEEK] DONE pass=%0d fail=%0d 10-62=", spw_pass, spw_fail);
                for (spw_j = SPW_FIRST; spw_j <= SPW_GAP_LO; spw_j = spw_j + 1)
                    $write("%02h", spw_bytes[spw_j]);
                $write(" 7A-7F=");
                for (spw_j = SPW_GAP_HI; spw_j <= SPW_LAST; spw_j = spw_j + 1)
                    $write("%02h", spw_bytes[spw_j]);
                $write("\n");
            end else begin
                spw_addr      <= spw_next;
                live_ser_peek <= spw_next;
            end
        end
    end

    // ── SER_WRITE_SWEEP: sweep 26h, then 28h, through the tester ──
    // From SER_WRITE_SWEEP_MS the tester answers slots 1/4 (26h) and 2/5
    // (28h) too. It starts by sending 00h for both, steps 26h up from 01h
    // to FFh with 28h at 00h, sends 26h = 00h, steps 28h up from 01h to
    // FFh, then sends 28h = 00h: 513 steps. A step moves on one frame
    // after the tester sent the stepped byte (the DME stores a reply on
    // its next poll, 0x1EAE), once 26h and 28h are checked against what
    // was sent:
    //   DME: [SERWR] <ms>,<26h sent>,<28h sent>,<RAM 26h>,<RAM 28h>,<ok|BAD>
    // The DME can drop a reply: it clears RI (0x1EF3) a few instructions
    // after its slot byte's TI, and if an interrupt lands in between and
    // runs longer than the tester takes to answer, the answer arrives
    // first and is cleared unread. The testbench flags each one:
    //   DME: [SERWR] <ms>,lost,<slot>,<byte>
    // A step that doesn't show in RAM is retried at the tester's next
    // answer for that byte (up to SWW_TRIES checks), logged with "retry"
    // in place of ok, so only a byte that never lands counts as BAD.
    // After the last step:
    //   DME: [SERWR] DONE pass=<n> fail=<n> retries=<n> lost=<n>
    // and the run ends 1 s later (SIM_TIME is only a backstop).
    localparam integer SWW_LAST = 512, SWW_TRIES = 4;
    integer    sww_step  = 0;
    reg        sww_on    = 1'b0, sww_done = 1'b0, sww_armed = 1'b0;
    integer    sww_pass = 0, sww_fail = 0, sww_try = 0, sww_retries = 0, sww_lost = 0;
    reg [63:0] sww_end_ms = 64'd0;
    reg  [7:0] sww_r26, sww_r28;
    // the 26h / 28h bytes for a step
    function [15:0] sww_vals;
        input integer st;
        begin
            if (st >= 1 && st <= 255)        sww_vals = {st[7:0], 8'h00};
            else if (st >= 257 && st <= 511) sww_vals = {8'h00, st[7:0]};  // st-256 = st[7:0]
            else                             sww_vals = 16'h0000;          // 0, 256, 512
        end
    endfunction
    // a slot byte (not FF) has just been received: the same instant the
    // receiver above decides its reply for slot ser_slot
    wire sww_slot_ev = ser_tick && ser_rx_act && ser_rx_cnt == 4'd15 && ser_rx_bit == 4'd10 &&
                       ser_rx_sh[8] && ser_rx_sh[7:0] != 8'hFF;
    // the reply to this slot is the byte being stepped (step 0: 28h, sent
    // after 26h in the same cycle)
    wire sww_is26 = (ser_slot == 3'd1 || ser_slot == 3'd4);
    wire sww_is28 = (ser_slot == 3'd2 || ser_slot == 3'd5);
    wire sww_stepped = (sww_step >= 1 && sww_step <= 256) ? sww_is26 : sww_is28;
    always @(posedge ser_clk) begin
        if (`OPT_SER_WRITE_SWEEP && !sww_on && !sww_done &&
            `DME_KLR_MS >= `VAL_SER_WRITE_SWEEP_MS) begin
            sww_on          <= 1'b1;
            live_ser_w26    <= 8'h00;
            live_ser_w28    <= 8'h00;
            live_ser_tester <= live_ser_tester | 8'h03;
        end else if (sww_on && sww_slot_ev) begin
            if (sww_armed) begin
                sww_armed = 1'b0;
                sww_r26   = u_dme.i8051_top.u_cpu.iram[7'h26];
                sww_r28   = u_dme.i8051_top.u_cpu.iram[7'h28];
                sww_try   = sww_try + 1;
                if (sww_r26 === live_ser_w26 && sww_r28 === live_ser_w28) begin
                    $display("DME: [SERWR] %0d,%02h,%02h,%02h,%02h,ok", `DME_KLR_MS,
                             live_ser_w26, live_ser_w28, sww_r26, sww_r28);
                    sww_pass = sww_pass + 1;
                end else if (sww_try < SWW_TRIES) begin
                    $display("DME: [SERWR] %0d,%02h,%02h,%02h,%02h,retry", `DME_KLR_MS,
                             live_ser_w26, live_ser_w28, sww_r26, sww_r28);
                    sww_retries = sww_retries + 1;
                end else begin
                    $display("DME: [SERWR] %0d,%02h,%02h,%02h,%02h,BAD", `DME_KLR_MS,
                             live_ser_w26, live_ser_w28, sww_r26, sww_r28);
                    sww_fail = sww_fail + 1;
                end
                if (sww_try < SWW_TRIES && !(sww_r26 === live_ser_w26 && sww_r28 === live_ser_w28))
                    ;                   // same step: re-armed at the next answer below
                else if (sww_step == SWW_LAST) begin
                    sww_on     <= 1'b0;
                    sww_done   <= 1'b1;
                    sww_end_ms <= `DME_KLR_MS;
                    live_ser_tester <= live_ser_tester & ~8'h02;
                    $display("DME: [SERWR] DONE pass=%0d fail=%0d retries=%0d lost=%0d",
                             sww_pass, sww_fail, sww_retries, sww_lost);
                end else begin
                    sww_try  = 0;
                    sww_step = sww_step + 1;
                    {live_ser_w26, live_ser_w28} <= sww_vals(sww_step);
                end
            end else if (sww_stepped)
                sww_armed = 1'b1;   // checked at the end of the next frame
        end
    end
    always @(posedge ser_clk)
        if (sww_done && `DME_KLR_MS >= sww_end_ms + 1000) finish_sim;

    // Lost replies: the tester finished sending after the DME's slot byte
    // (0x1EEC) but before the DME's clr RI (0x1EF3) in the same poll.
    // A reply normally finishes after 0x1EF3 and is read at 0x1E9D on
    // the next poll.
    reg        sww_txb_q = 1'b0, sww_in_win = 1'b0, sww_txd_win = 1'b0;
    reg [15:0] sww_pc_q = 16'h0000;
    reg  [2:0] sww_tx_slot = 3'd0;
    reg  [7:0] sww_tx_val = 8'h00;
    always @(posedge ser_clk) begin
        sww_txb_q <= ser_tx_busy;
        sww_pc_q  <= u_dme.i8051_top.u_cpu.pc;
        if (ser_tx_go && !ser_tx_busy) begin
            sww_tx_slot <= ser_slot - 3'd1;     // the slot it answers
            sww_tx_val  <= ser_tx_byte;
        end
        if (u_dme.i8051_top.u_cpu.pc == 16'h1EEC && sww_pc_q != 16'h1EEC) begin
            sww_in_win  <= 1'b1;
            sww_txd_win <= 1'b0;
        end else if (sww_txb_q && !ser_tx_busy && sww_in_win)
            sww_txd_win <= 1'b1;                // reply done inside the window
        if (u_dme.i8051_top.u_cpu.pc == 16'h1EF3 && sww_pc_q != 16'h1EF3) begin
            sww_in_win <= 1'b0;
            if (sww_txd_win && live_ser_tester[1]) begin
                $display("DME: [SERWR] %0d,lost,%0d,%02h", `DME_KLR_MS, sww_tx_slot, sww_tx_val);
                sww_lost = sww_lost + 1;
            end
        end
    end

    // ── Snapshot-busy flag ───────────────────────────────────
    reg snapshot_busy;
    initial snapshot_busy = 1'b0;

    // ── Combined snapshot task ───────────────────────────────
    task emit_combined_snapshot;
        integer i;
        begin
            snapshot_busy = 1'b1;

            // ── [DS] — DME 8051 iram (128 bytes) ─────────────
            $write("DME: [DS] %0d,", `DME_KLR_MS);
            for (i = 0; i < 128; i = i + 1)
                $write("%02h", u_dme.i8051_top.u_cpu.iram[i[6:0]]);
            // Source input-only pins from driven *_in signals (not the CPU
            // output latch) so O2 (P1.7:6) and serial (P3.1:0) don't emit X.
            $write(",%02h%02h%02h",
               {u_dme.p1_in[7:6], u_dme.p1[5:0]},
               u_dme.p2,
               {u_dme.p3[7:6], u_dme.t1, u_dme.t0, u_dme.speed_sensor, u_dme.reference_sensor, u_dme.p3_in[1:0]});
	    //$write(",%02h%02h%02h", u_dme.p1, u_dme.p2, u_dme.p3_in);
            $write(",%0d", u_dme.ref_rpm);
            // ADC channel inputs 0-7 as fed to the DME's ADC (see adc_ch0..7)
            $write(",%02h%02h%02h%02h%02h%02h%02h%02h\n", u_dme.adc_ch0, u_dme.adc_ch1,
                   u_dme.adc_ch2, u_dme.adc_ch3, u_dme.adc_ch4, u_dme.adc_ch5,
                   u_dme.adc_ch6, u_dme.adc_ch7);

            // ── [SER] — diagnostic serial frames (see the tester above)
            // <ms>,<tester on>,<peek addr asked>,<frames>,<rpm><adv><fuel><peek>,
            // <7Ah for that peek>,<next slot>,<slot 0..5 bytes>,<hellos>,<replies>
            // Only once there is something to show, so logs without serial
            // traffic are unchanged.
            if (live_ser_tester[0] || ser_frames != 0 || ser_hellos > 1)
                $write("DME: [SER] %0d,%0d,%02h,%0d,%02h%02h%02h%02h,%02h,%0d,%02h%02h%02h%02h%02h%02h,%0d,%0d\n",
                    `DME_KLR_MS, live_ser_tester[0], live_ser_peek, ser_frames,
                    ser_rpm, ser_adv, ser_fuel, ser_peekv, ser_peek_addr, ser_slot,
                    ser_slotv[0], ser_slotv[1], ser_slotv[2], ser_slotv[3], ser_slotv[4], ser_slotv[5],
                    ser_hellos, ser_replies);

            // ── KLR: [DS] — 8048 RAM (128 bytes) ─────────────────
            $write("KLR: [DS] %0d,", `DME_KLR_MS);
            for (i = 0; i < 128; i = i + 1)
                $write("%02h", u_klr.top.i8048_core_1.ram[i[6:0]]);
            // TODO: confirm KLR port hierarchy for p1/p2
            $write(",%02h%02h", u_klr.top.p1, u_klr.top.p2);
            // Trailing bit tail — appended, not reordered, so any
            // existing positional readers of the first 3 bits are
            // unaffected. ext_trigger/ext_ign are the actual signals
            // reaching the KLR ports (post fault-injection override,
            // if any — see KLR_TRIGGER_STUCK_HIGH/KLR_IGN_IN_STUCK_HIGH
            // above), unlike tach_dme_to_klr which is the raw DME
            // signal before invert and before any override.
            $write(",%0b%0b%0b%0b%0b\n",
                tach_dme_to_klr,    // ign input to KLR (before invert)
                klr_ign_out,        // KLR ign output
                full_load,          // full load / WOT flag
                ext_trigger,        // KLR trigger_in, post fault-injection override
                ext_ign);           // KLR ign_in, post fault-injection override

`ifdef LIVE_DEBUG
            // CPU registers for the debugger's operand-value column
            $display("SIM: [REGS] dme t_ms=%0d acc=%02h b=%02h psw=%02h sp=%02h dptr=%02h%02h ie=%02h ip=%02h tcon=%02h tmod=%02h tl0=%02h th0=%02h tl1=%02h th1=%02h scon=%02h sbuf=%02h pcon=%02h p0=%02h p1=%02h p2=%02h p3=%02h",
                `DME_KLR_MS, u_dme.i8051_top.u_cpu.acc, u_dme.i8051_top.u_cpu.b_reg, u_dme.i8051_top.u_cpu.psw,
                u_dme.i8051_top.u_cpu.sp, u_dme.i8051_top.u_cpu.dph, u_dme.i8051_top.u_cpu.dpl,
                u_dme.i8051_top.u_cpu.ie, u_dme.i8051_top.u_cpu.ip, u_dme.i8051_top.u_cpu.tcon,
                u_dme.i8051_top.u_cpu.tmod, u_dme.i8051_top.u_cpu.tl0, u_dme.i8051_top.u_cpu.th0,
                u_dme.i8051_top.u_cpu.tl1, u_dme.i8051_top.u_cpu.th1, u_dme.i8051_top.u_cpu.scon,
                u_dme.i8051_top.u_cpu.sbuf_rx, u_dme.i8051_top.u_cpu.pcon,
                u_dme.i8051_top.u_cpu.p0, u_dme.i8051_top.u_cpu.p1, u_dme.i8051_top.u_cpu.p2,
                u_dme.i8051_top.u_cpu.p3);
            // stk=<tag per byte 64h..79h>, '.'-separated; p carries the PUSH address
            $write("SIM: [REGS] dmestk t_ms=%0d stk=", `DME_KLR_MS);
            for (i = 'h64; i <= 'h79; i = i + 1) begin
                if (live_stk_tag[i] == "p") $write("p%04h", live_stk_src[i]);
                else                        $write("%s", live_stk_tag[i]);
                if (i != 'h79) $write(".");
            end
            $write("\n");
            $display("SIM: [REGS] klr t_ms=%0d sp=%0d acc=%02h psw=%02h p1=%02h p2=%02h t=%02h f0=%0d f1=%0d",
                `DME_KLR_MS, u_klr.top.i8048_core_1.sp, u_klr.top.i8048_core_1.acc, u_klr.top.i8048_core_1.psw,
                u_klr.top.i8048_core_1.p1, u_klr.top.i8048_core_1.p2,
                u_klr.top.i8048_core_1.timer_val,
                u_klr.top.i8048_core_1.f0, u_klr.top.i8048_core_1.f1);
`endif
            snapshot_busy = 1'b0;
        end
    endtask

    // ── Snapshot scheduler — latched to DME clock ────────────
    reg [63:0] next_snap_ns;
    initial    next_snap_ns = `VAL_DASH_INTERVAL_MS * 64'd1_000_000;

    always @(posedge dme_clk) begin
        if ($time >= next_snap_ns) begin
            emit_combined_snapshot;
            // the next multiple of the interval: the same as + interval,
            // and on the grid again after the live debugger changes it
            next_snap_ns <= ($time / `DASH_IV_NS + 64'd1) * `DASH_IV_NS;
        end
`ifdef LIVE_DEBUG
        else begin
            if (live_snap_req != live_snap_ack)
                emit_combined_snapshot;
            // A shorter interval takes effect now, not after the snapshot
            // already due: the next one moves to the next multiple of it
            if (next_snap_ns - $time > `DASH_IV_NS)
                next_snap_ns <= ($time / `DASH_IV_NS + 64'd1) * `DASH_IV_NS;
        end
        live_snap_ack <= live_snap_req;
`endif
    end

`ifdef LIVE_DEBUG
    // ── ROM reload (sim_main "rom" command) ──────────────────
    // sim_main fills live_rom_buf with the new image (0xFF where the file
    // has no data), sets live_rom_cpu (1 = DME, 2 = KLR) and bumps req;
    // the next DME clock copies the buffer into that CPU's EPROM array and
    // copies req to ack. live_*_rom_path are the compiled-in images (the
    // same macros i8051_top.v / klr_top.v load), for sim_main to report.
    reg [7:0]  live_rom_buf [0:8191] /*verilator public_flat_rw*/;
    reg [1:0]  live_rom_cpu  /*verilator public_flat_rw*/ = 2'd0;
    reg [31:0] live_rom_req  /*verilator public_flat_rw*/ = 32'd0;
    reg [31:0] live_rom_ack  /*verilator public_flat_rd*/ = 32'd0;
`ifdef RUNTIME_OPTS
    // the paths come from +DME_ROM_DIR/FILE etc. (test_opts), so they are
    // set when the sim starts, not compiled in
    reg [8*512-1:0] live_dme_rom_path /*verilator public_flat_rd*/;
    reg [8*512-1:0] live_klr_rom_path /*verilator public_flat_rd*/;
    initial begin
`ifdef VERILATOR
        // the paths are strings here; assigning one to a vector directly
        // makes Verilator 5.040 emit C++ that doesn't compile (VL_EXTEND_WN)
        $sformat(live_dme_rom_path, "%s", `DME_ROM_PATH);
        $sformat(live_klr_rom_path, "%s", `KLR_ROM_PATH);
`else
        live_dme_rom_path = `DME_ROM_PATH;
        live_klr_rom_path = `KLR_ROM_PATH;
`endif
    end
`else
    reg [8*512-1:0] live_dme_rom_path /*verilator public_flat_rd*/ = {`DME_ROM_DIR, `DME_ROM_FILE};
    reg [8*512-1:0] live_klr_rom_path /*verilator public_flat_rd*/ = {`KLR_ROM_DIR, `KLR_ROM_FILE};
`endif
    integer live_rom_i;
    always @(posedge dme_clk)
        if (live_rom_req != live_rom_ack) begin
            if (live_rom_cpu == 2'd1)
                for (live_rom_i = 0; live_rom_i < 8192; live_rom_i = live_rom_i + 1)
                    `LROM[live_rom_i] = live_rom_buf[live_rom_i];
            else if (live_rom_cpu == 2'd2)
                for (live_rom_i = 0; live_rom_i < 4096; live_rom_i = live_rom_i + 1)
                    u_klr.top.rom_1.rom[live_rom_i] = live_rom_buf[live_rom_i];
            live_rom_ack <= live_rom_req;
        end
`endif

    // Hard simulation boundary — terminates at exactly SIM_TIME (the
    // run script's -DSIM_TIME / +SIM_TIME, else test_opts.vh's default).
    // A test can also end early through finish_sim (SER_WRITE_SWEEP).
    task finish_sim;
        begin
            // ── DME memory dumps ──────────────────────────────────
            $writememh("dme_rom_out.hex", u_dme.i8051_top.u_eprom.mem);
            $writememh("dme_ram_out.hex", u_dme.i8051_top.u_cpu.iram);
            // ── KLR memory dumps ──────────────────────────────────
            $writememh("klr_rom_out.hex", u_klr.top.rom_1.rom);
            $writememh("klr_ram_out.hex", u_klr.top.i8048_core_1.ram);
            $finish;
        end
    endtask
    initial begin
        #(`VAL_SIM_TIME);
        finish_sim;
    end

endmodule
