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
    // TPS angle: DME AFM wiper → KLR TPS angle ch7
    // TPS supply is fixed 201 in klr_tb (5V regulated, independent of battery)
    wire [7:0] tps_wiper_sig;
`ifdef LIVE
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
    reg [15:0] live_klr_tps   /*verilator public_flat_rw*/ = 16'hFFFF;  // KLR TPS angle, in afm_wiper units
    reg [15:0] live_o2        /*verilator public_flat_rw*/ = 16'hFFFF;  // {o2_7, o2_6}: 0 lean, 1 cross, 3 rich
    reg [15:0] live_knock     /*verilator public_flat_rw*/ = 16'hFFFF;  // 1: crank-synced knock on the KLR knock_sensor (klr_knock_gen.v)
    // Snapshot on demand: sim_main bumps req, the scheduler below emits
    // one DS pair and copies req to ack.
    // KLR ram 3Ah / 48h for the log replay's knock filter
    // (replay_main.cpp): the KLR only counts a knock while 3Ah > 48h
    wire [7:0] live_klr_ram3a /*verilator public_flat_rd*/ = u_klr.top.i8048_core_1.ram[7'h3A];
    wire [7:0] live_klr_ram48 /*verilator public_flat_rd*/ = u_klr.top.i8048_core_1.ram[7'h48];
    reg [31:0] live_snap_req  /*verilator public_flat_rw*/ = 32'd0;
    reg [31:0] live_snap_ack  /*verilator public_flat_rd*/ = 32'd0;
    assign tps_wiper_sig = (live_klr_tps == 16'hFFFF) ? u_dme.afm_wiper   // throttle after its slew (see i8051_dashboard_tb)
                                                      : live_klr_tps[7:0];

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
`ifdef CL_ISV_AIR
    assign tps_wiper_sig = u_dme.throttle_afm;   // without the ISV's bypass air
`else
    assign tps_wiper_sig = u_dme.afm_wiper;
`endif
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
    // needed here.
    initial begin
        $dumpvars(1, tach_dme_to_klr);
        $dumpvars(1, ign_out_dme_to_klr);
        $dumpvars(1, klr_ign_out);
        $dumpvars(1, full_load);
        $dumpvars(1, tdc);
        $dumpvars(1, tps_wiper_sig);
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
    wire ext_trigger_gen = ~ign_out_dme_to_klr;  // DME A_5_KLR_ign_out → KLR trigger (inverted)
    wire ext_ign_gen     = ~tach_dme_to_klr;     // DME tach → KLR ign (inverted)

`ifdef KLR_TRIGGER_STUCK_HIGH
  `ifndef TRIGGER_LOSS_T_MS
  `define TRIGGER_LOSS_T_MS 3000
  `endif
    wire ext_trigger = (`DME_KLR_MS >= `TRIGGER_LOSS_T_MS) ? 1'b1 : ext_trigger_gen;
`elsif KLR_TRIGGER_STUCK_LOW
  `ifndef TRIGGER_LOSS_T_MS
  `define TRIGGER_LOSS_T_MS 3000
  `endif
    wire ext_trigger = (`DME_KLR_MS >= `TRIGGER_LOSS_T_MS) ? 1'b0 : ext_trigger_gen;
`else
    wire ext_trigger = ext_trigger_gen;
`endif

`ifdef KLR_IGN_IN_STUCK_HIGH
  `ifndef IGN_IN_LOSS_T_MS
  `define IGN_IN_LOSS_T_MS 3000
  `endif
    wire ext_ign = (`DME_KLR_MS >= `IGN_IN_LOSS_T_MS) ? 1'b1 : ext_ign_gen;
`elsif KLR_IGN_IN_STUCK_LOW
  `ifndef IGN_IN_LOSS_T_MS
  `define IGN_IN_LOSS_T_MS 3000
  `endif
    wire ext_ign = (`DME_KLR_MS >= `IGN_IN_LOSS_T_MS) ? 1'b0 : ext_ign_gen;
`else
    wire ext_ign = ext_ign_gen;
`endif

    // ── KLR sub-TB ───────────────────────────────────────────
    // EXT_STIM=1: external trigger/ign signals (not internal generator)
    // Signals are inverted: DME active-high → KLR active-low inputs
    klr_tb #(.EXT_STIM(1)) u_klr (
        .ext_trigger     ( ext_trigger         ),  // DME A_5_KLR_ign_out → KLR trigger (inverted)
        .ext_ign         ( ext_ign             ),  // DME tach → KLR ign (inverted)
        .ign_out         ( klr_ign_out         ),  // KLR spark output → DME ign
        .full_load       ( full_load_klr       ),  // KLR WOT flag → DME
        .tps_wiper   ( tps_wiper_sig       ),  // AFM → KLR TPS angle ch7
        .rpm_in          ( u_dme.ref_rpm       ),  // DME tick-measured RPM (reg [31:0]) → KLR -DBOOST map (unused if -DBOOST undefined)
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
`ifdef KLR_FULL_LOAD_STUCK_LOW
    assign full_load = 1'b0;
`else
    assign full_load = full_load_klr;
`endif

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

`ifdef LIVE
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
    initial    next_snap_ns = `DASH_INTERVAL_MS * 64'd1_000_000;

    always @(posedge dme_clk) begin
        if ($time >= next_snap_ns) begin
            emit_combined_snapshot;
            next_snap_ns <= next_snap_ns + (`DASH_INTERVAL_MS * 64'd1_000_000);
        end
`ifdef LIVE
        else if (live_snap_req != live_snap_ack)
            emit_combined_snapshot;
        live_snap_ack <= live_snap_req;
`endif
    end

`ifdef LIVE
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
    reg [8*512-1:0] live_dme_rom_path /*verilator public_flat_rd*/ = {`DME_ROM_DIR, `DME_ROM_FILE};
    reg [8*512-1:0] live_klr_rom_path /*verilator public_flat_rd*/ = {`KLR_ROM_DIR, `KLR_ROM_FILE};
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

    // Hard simulation boundary — terminates at exactly SIM_TIME.
    // SIM_TIME must be passed via -DSIM_TIME=<ns> from the run script.
    // No default — intentional, so a missing define causes a compile error
    // rather than silently capping a long test at 10s.
`ifndef SIM_TIME
  ERROR_SIM_TIME_must_be_defined  // force compile error if omitted
`endif
    initial begin
        #`SIM_TIME;
        // ── DME memory dumps ──────────────────────────────────
        $writememh("dme_rom_out.hex", u_dme.i8051_top.u_eprom.mem);
        $writememh("dme_ram_out.hex", u_dme.i8051_top.u_cpu.iram);
        // ── KLR memory dumps ──────────────────────────────────
        $writememh("klr_rom_out.hex", u_klr.top.rom_1.rom);
        $writememh("klr_ram_out.hex", u_klr.top.i8048_core_1.ram);
        $finish;
    end

endmodule
