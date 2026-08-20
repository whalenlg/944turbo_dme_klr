// ============================================================
//  knock_gen.v  —  Knock AND gate (ch5) + noise level model (ch0)
//
//  Models the connection into the KLR's adc_ch0 and adc_ch5 inputs.
//
//  fake_knock is a firmware-driven output of klr_system (P1.7) —
//  the firmware sets this pin to inject a fake knock reading for
//  self-test. 1 bit wide.
//
//  knock_reset is klr_system's P2.5 output (see klr_tb.v, where
//  it's wired from the p2_mon bus) — gates the ch5 comparator
//  chain only (per the schematic, P2.5 feeds into the S3 stages of
//  the top chain). 1 bit wide.
//
//  Low-pass-filter-style one-shot timer (clocked off the same `clk`
//  as the rest of the design) — models fake_knock's contribution to
//  knock_sum as a single, fixed 2.4ms low period, NOT retriggerable:
//    - The FIRST falling edge of fake_knock (seen while idle) starts
//      a fixed 2.4ms hold_cnt countdown (HOLD_CYCLES, derived from
//      `FRQ_SCALE / `KLR_FREQ so it self-corrects if the clock
//      frequency changes).
//    - While hold_cnt is running, fake_knock_stretched is forced LOW
//      unconditionally — fake_knock's actual value is completely
//      ignored for the whole window, including any further falling
//      edges, rises, or brief blips (intentional — this is the
//      low-pass filtering behavior: one clean falling edge in, one
//      clean rising edge out, 2.4ms later).
//    - At exactly 2.4ms, the timer releases and fake_knock_stretched
//      goes back to mirroring fake_knock directly (whatever it
//      happens to be at that point).
//
//  knock_noise has its OWN, separate 500us retriggerable filter
//  (noise_hold_cnt / fake_knock_noise_stretched) — a classic
//  retriggerable monostable, unlike knock_sum's fixed one-shot above:
//    - EVERY falling edge of fake_knock (re)starts a 500us
//      noise_hold_cnt countdown (NOISE_HOLD_CYCLES).
//    - While counting, fake_knock_noise_stretched is forced LOW
//      regardless of fake_knock's value — so any pulse (and its
//      matching fall) occurring within 500us of the LAST falling
//      edge is filtered out, and each such fall restarts the 500us
//      window from that point.
//    - Once 500us elapses with no further falls, it releases and
//      mirrors fake_knock directly.
//  This is intentionally a different filter from knock_sum's — a
//  shorter, retriggering window rather than a longer, fixed one —
//  so the two outputs settle at different times for the same
//  fake_knock input.
//
//  Two outputs:
//
//    knock_sum — drives adc_ch5 (LM2902 comparator threshold-trip
//      channel). knock_reset takes priority: 0 forces flat 8'd000
//      regardless of fake_knock. Otherwise (knock_reset=1):
//      fake_knock_stretched=1 -> knock_sensor+8'd145, else just
//      knock_sensor. With the current klr_tb.v tie-off
//      (knock_sensor=8'd110), that's 0 / 110 / 255 decimal.
//
//    knock_noise — drives adc_ch0 (knock sensor noise-level
//      channel): fake_knock_noise_stretched ? (knock_sensor+8'd145)
//      : knock_sensor. Filtered by its own 500us retriggerable timer
//      (see above) — NOT the same filter/timing as knock_sum. NOT
//      gated by knock_reset at all (per spec: only knock_sum reacts
//      to knock_reset going low). Same value formula as knock_sum,
//      just a different (shorter, retriggering) filter window.
//
//  knock_sensor is still a fixed placeholder (8'd110, tied in
//  klr_tb.v) rather than a real sensor model — that's planned as
//  future work. Its contribution is the baseline value always; the
//  8'd145 offset is added on top only while the relevant filtered
//  fake_knock signal is asserted.
// ============================================================

`include "timescale.v"

module knock_gen (
    input  wire       clk,
    input  wire       fake_knock,
    input  wire       knock_reset,
    input  wire [7:0] knock_sensor,
    output wire [7:0] knock_sum,
    output wire [7:0] knock_noise
);

    // Clock period (ns), same expression as klr_tb.v's own `parameter DELAY`
    // (DELAY there is the half-period; full period is 2x that).
    localparam integer CLK_PERIOD_NS    = 2 * (`FRQ_SCALE / `KLR_FREQ);
    localparam integer HOLD_CYCLES      = 2400000 / CLK_PERIOD_NS;  // knock_sum: fixed 2.4ms one-shot
    localparam integer NOISE_HOLD_CYCLES = 500000 / CLK_PERIOD_NS;  // knock_noise: retriggerable 500us

    reg [31:0] hold_cnt        = 0;     // 0 = idle; counts 1..HOLD_CYCLES while holding (knock_sum)
    reg [31:0] noise_hold_cnt  = 0;     // 0 = idle; counts 1..NOISE_HOLD_CYCLES while holding (knock_noise)
    reg        fake_knock_prev = 1'b1;  // assume idle-high at sim start; shared falling-edge reference

    // knock_sum's fixed, non-retriggering 2.4ms one-shot
    always @(posedge clk) begin
        fake_knock_prev <= fake_knock;

        if (hold_cnt == 0) begin
            // Idle -- only a falling edge seen HERE (while idle) starts
            // the one-shot. Not retriggerable: falls seen later, while
            // hold_cnt is already counting, are ignored entirely.
            if (fake_knock_prev && !fake_knock) begin
                hold_cnt <= 1;
            end
        end else if (hold_cnt < HOLD_CYCLES) begin
            hold_cnt <= hold_cnt + 1;  // keep counting; fake_knock is ignored during this window
        end else begin
            hold_cnt <= 0;  // 2.4ms elapsed -- release back to idle/passthrough
        end
    end

    // knock_noise's independent, retriggerable 500us filter
    always @(posedge clk) begin
        if (fake_knock_prev && !fake_knock) begin
            // Every falling edge (re)starts the 500us window
            noise_hold_cnt <= 1;
        end else if (noise_hold_cnt > 0 && noise_hold_cnt < NOISE_HOLD_CYCLES) begin
            noise_hold_cnt <= noise_hold_cnt + 1;
        end else if (noise_hold_cnt >= NOISE_HOLD_CYCLES) begin
            noise_hold_cnt <= 0;  // 500us elapsed with no further falls -- release
        end
    end

    wire fake_knock_stretched =
        (hold_cnt > 0 && hold_cnt < HOLD_CYCLES) ? 1'b0 : fake_knock;
    wire fake_knock_noise_stretched =
        (noise_hold_cnt > 0 && noise_hold_cnt < NOISE_HOLD_CYCLES) ? 1'b0 : fake_knock;

    assign knock_sum   = !knock_reset ? 8'd0
                        : fake_knock_stretched ? (knock_sensor + 8'd145)
                        : knock_sensor;
    assign knock_noise = fake_knock_noise_stretched ? (knock_sensor + 8'd145) : knock_sensor;

endmodule
