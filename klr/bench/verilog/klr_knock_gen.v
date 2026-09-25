// ============================================================
//  klr_knock_gen.v  —  Crank-synchronized knock sensor stimulus
//
//  Testbench-only knock_sensor waveform generator for the combined
//  DME+KLR dashboard sim (see dme_klr_dashboard_tb.v). Lives on the
//  KLR side since it drives klr_tb's knock_sensor input port, but
//  is synchronized to DME-side crank-position signals (tdc,
//  speed_sensor) passed in from the top-level testbench — klr_tb
//  and the DME sub-TB are sibling instances there, neither can see
//  the other's internals directly, so the top level wires this
//  module's clk/tdc/speed_sensor inputs from u_dme and its output
//  to u_klr.knock_sensor.
//
//  Three modes, selected by the same `ifdef`s as before the move:
//
//  TEST_KNOCK_PULSE:
//    - Waits until `SIM_TIME/2 before watching for tdc at all, so
//      the engine has settled at a representative RPM first.
//    - tdc falling edge (1->0) marks each cylinder's TDC event. On
//      a 4-cylinder engine, every 4th tdc falling edge is "the same
//      cylinder" as the first one seen after the wait above (tdc
//      falling edges 1, 5, 9, 13, ... — verified against a Python
//      model of this exact state machine before writing this).
//    - For each of that cylinder's next 10 TDC events: count 32
//      speed_sensor rising edges after TDC, then drop knock_sensor;
//      count a further 107 speed_sensor rising edges (~7ms at the
//      65.133us/pulse rate measured at this RPM at design time —
//      counts real pulses, not a fixed time, so it tracks actual
//      RPM rather than assuming it stays constant), then restore
//      knock_sensor.
//    - After 10 repeats, knock_sensor stays at nominal for the
//      rest of the simulation.
//
//  TEST_KNOCK_SHORT_TO_GROUND:
//    - knock_sensor short-to-ground: held at a constant 0 for the
//      whole test (not pulsing — a permanent fault, unlike
//      TEST_KNOCK_PULSE's timed drops), while fake_knock/
//      knock_reset (knock_gen.v, inside klr_tb) continue operating
//      normally — this only changes what knock_sensor itself
//      reports, not the self-test path knock_gen.v's
//      TEST_KNOCK_FAKE_BLOCKED flag targets.
//
//  Default (neither defined): flat nominal 8'd110.
// ============================================================

`include "timescale.v"

module klr_knock_gen (
    input  wire       clk,          // DME clock (dme_clk)
    input  wire       tdc,          // DME crank-model TDC marker
    input  wire       speed_sensor, // DME speed_sensor (crank tooth pulses)
    output wire [7:0] knock_sensor  // drives KLR knock_sensor input
);

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

    always @(posedge clk) begin
        tdc_prev          <= tdc;
        speed_sensor_prev <= speed_sensor;

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
            if (speed_sensor_prev == 1'b0 && speed_sensor == 1'b1) begin
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

    assign knock_sensor = knock_sensor_sig;

`elsif TEST_KNOCK_SHORT_TO_GROUND
    assign knock_sensor = 8'd0;
`else
    assign knock_sensor = 8'd110;
`endif

endmodule
