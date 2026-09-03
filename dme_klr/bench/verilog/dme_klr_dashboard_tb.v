// ============================================================
//  dme_klr_dashboard_tb.v  —  DME 951 + KLR combined testbench
//
//  Signal interconnect:
//    DME A_1_tach_pulse  → KLR ext_ign     (DME tach → KLR, inverted)
//    DME A_5_KLR_ign_out → KLR ext_trigger (DME ign out → KLR, inverted)
//    KLR ign_out         → (not connected to DME — spark output, not key switch)
//    KLR full_load       → DME full_load   (WOT flag → DME TPS ch6)
//    DME afm_wiper      → KLR tps_wiper   (TPS angle ch7)
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
    wire full_load;            // KLR full_load → DME TPS ch6
    wire tdc;                  // DME crank-model TDC marker (see
                                // var_interrupt_generator/_cl) — not
                                // connected to the KLR, exposed for
                                // observation/logging at this top level
    // TPS angle: DME AFM wiper → KLR TPS angle ch7
    // TPS supply is fixed 201 in klr_tb (5V regulated, independent of battery)
    wire [7:0] tps_wiper_sig;
    assign tps_wiper_sig = u_dme.afm_wiper;

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

    // ── Knock sensor stimulus (TEST_KNOCK_PULSE) ────────────────
    // Crank-position-synchronized knock pulse train — engine knock is
    // specific to crank position, so this lives here (not in klr_tb.v)
    // where tdc/speed_sensor (DME-side, crank-position signals) and
    // knock_sensor (KLR-side, now an input port) are both reachable —
    // klr_tb and the DME sub-TB are sibling instances, neither can see
    // the other's internals directly.
    //
    //   - Waits until `SIM_TIME/2 before watching for tdc at all, so
    //     the engine has settled at a representative RPM first.
    //   - tdc falling edge (1->0) marks each cylinder's TDC event. On
    //     a 4-cylinder engine, every 4th tdc falling edge is "the same
    //     cylinder" as the first one seen after the wait above (tdc
    //     falling edges 1, 5, 9, 13, ... — verified against a Python
    //     model of this exact state machine before writing this).
    //   - For each of that cylinder's next 10 TDC events: count 32
    //     speed_sensor rising edges after TDC, then drop knock_sensor;
    //     count a further 107 speed_sensor rising edges (~7ms at the
    //     65.133us/pulse rate measured at this RPM at design time —
    //     counts real pulses, not a fixed time, so it tracks actual
    //     RPM rather than assuming it stays constant), then restore
    //     knock_sensor.
    //   - After 10 repeats, knock_sensor stays at nominal for the
    //     rest of the simulation.
`ifdef TEST_KNOCK_PULSE
    localparam KNOCK_CYLINDERS    = 4;
    localparam KNOCK_DELAY_PULSES = 32;    // speed_sensor pulses after TDC before dropping
    localparam KNOCK_HOLD_PULSES  = 107;   // speed_sensor pulses held low (~7ms @ 65.133us/pulse)
    localparam KNOCK_REPEATS      = 5;

    reg [7:0]  knock_sensor_sig;
    reg        knock_started;      // has the `SIM_TIME/2 wait elapsed?
    reg        tdc_prev;
    reg        speed_sensor_prev;
    reg [31:0] tdc_count;          // total tdc falling edges seen since knock_started
    reg [31:0] pulse_count;        // speed_sensor rising edges since the current tdc event
    reg [3:0]  rep_count;          // completed repeats (0-10)
    reg [1:0]  knock_state;        // 0=waiting for next same-cyl TDC, 1=counting to drop, 2=counting to restore, 3=done

    initial begin
        knock_sensor_sig  = 8'd110;
        knock_started     = 1'b0;
        tdc_prev           = 1'b0;
        speed_sensor_prev  = 1'b0;
        tdc_count          = 32'd0;
        pulse_count        = 32'd0;
        rep_count          = 4'd0;
        knock_state        = 2'd0;
    end

    always @(posedge dme_clk) begin
        tdc_prev          <= tdc;
        speed_sensor_prev <= u_dme.speed_sensor;

        if (!knock_started) begin
            if ($time >= 64'd`SIM_TIME / 64'd2)
                knock_started <= 1'b1;
        end else if (knock_state != 2'd3) begin
            // tdc falling edge this cycle? — old (pre-increment)
            // tdc_count is what's checked here, thanks to non-blocking
            // assignment semantics: tdc_count still reads its prior
            // value below even though it's assigned above in the same
            // always block. 0, 4, 8, ... => the 1st, 5th, 9th, ...
            // tdc event — "the same cylinder" every KNOCK_CYLINDERS-th
            // time.
            if (tdc_prev && !tdc) begin
                tdc_count <= tdc_count + 32'd1;
                if ((tdc_count % KNOCK_CYLINDERS) == 0) begin
                    pulse_count <= 32'd0;
                    knock_state <= 2'd1;
                end
            end

            // speed_sensor rising edge this cycle?
            if (speed_sensor_prev == 1'b0 && u_dme.speed_sensor == 1'b1) begin
                case (knock_state)
                    2'd1: begin // counting toward drop (KNOCK_DELAY_PULSES)
                        if (pulse_count + 32'd1 >= KNOCK_DELAY_PULSES) begin
                            knock_sensor_sig <= 8'd0;
                            pulse_count       <= 32'd0;
                            knock_state       <= 2'd2;
                        end else begin
                            pulse_count <= pulse_count + 32'd1;
                        end
                    end
                    2'd2: begin // counting toward restore (KNOCK_HOLD_PULSES)
                        if (pulse_count + 32'd1 >= KNOCK_HOLD_PULSES) begin
                            knock_sensor_sig <= 8'd110;
                            pulse_count       <= 32'd0;
                            rep_count         <= rep_count + 4'd1;
                            knock_state       <= (rep_count + 4'd1 >= KNOCK_REPEATS) ? 2'd3 : 2'd0;
                        end else begin
                            pulse_count <= pulse_count + 32'd1;
                        end
                    end
                    default: ; // 0 or 3: not counting pulses right now
                endcase
            end
        end
    end
`elsif TEST_KNOCK_SHORT_TO_GROUND
    // knock_sensor short-to-ground: held at a constant 0 for the whole
    // test (not pulsing — a permanent fault, unlike TEST_KNOCK_PULSE's
    // timed drops), while fake_knock/knock_reset continue operating
    // normally (unaffected — this only changes what knock_sensor
    // itself reports, not the self-test path knock_gen.v's
    // TEST_KNOCK_FAKE_BLOCKED flag targets).
    wire [7:0] knock_sensor_sig = 8'd0;
`else
    wire [7:0] knock_sensor_sig = 8'd110;
`endif

    // ── KLR sub-TB ───────────────────────────────────────────
    // EXT_STIM=1: external trigger/ign signals (not internal generator)
    // Signals are inverted: DME active-high → KLR active-low inputs
    klr_tb #(.EXT_STIM(1)) u_klr (
        .ext_trigger     ( ~ign_out_dme_to_klr ),  // DME A_5_KLR_ign_out → KLR trigger (inverted)
        .ext_ign         ( ~tach_dme_to_klr    ),  // DME tach → KLR ign (inverted)
        .ign_out         ( klr_ign_out         ),  // KLR spark output → DME ign
        .full_load       ( full_load           ),  // KLR WOT flag → DME
        .tps_wiper   ( tps_wiper_sig       ),  // AFM → KLR TPS angle ch7
        .knock_sensor    ( knock_sensor_sig    )   // crank-synchronized knock pulse train, see above
    );

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
            $write(",%0d\n", u_dme.ref_rpm);

            // ── KLR: [DS] — 8048 RAM (128 bytes) ─────────────────
            $write("KLR: [DS] %0d,", `DME_KLR_MS);
            for (i = 0; i < 128; i = i + 1)
                $write("%02h", u_klr.top.i8048_core_1.ram[i[6:0]]);
            // TODO: confirm KLR port hierarchy for p1/p2
            $write(",%02h%02h", u_klr.top.p1, u_klr.top.p2);
            $write(",%0b%0b%0b\n",
                tach_dme_to_klr,    // ign input to KLR (before invert)
                klr_ign_out,        // KLR ign output
                full_load);         // full load / WOT flag

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
    end

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
