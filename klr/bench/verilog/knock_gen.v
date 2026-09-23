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
//  trigger_in is the same crank-synchronized reference-sensor
//  trigger klr_system itself runs on (see klr_tb.v's trigger_in_mux
//  — this port is wired to that same net, so knock_noise samples in
//  lockstep with the KLR's own trigger timing rather than off `clk`
//  directly). Rising edge is the sample clock for knock_noise's
//  rolling average, below.
//
//  Low-pass-filter-style one-shot (clocked off the same `clk` as the
//  rest of the design) — models fake_knock's contribution to
//  knock_sum as a single low period, NOT retriggerable, released by
//  the next trigger_in tooth rather than a fixed timer:
//    - The FIRST falling edge of fake_knock (seen while idle) starts
//      the hold.
//    - While holding, fake_knock_stretched is forced LOW
//      unconditionally — fake_knock's actual value is completely
//      ignored for the whole window, including any further falling
//      edges, rises, or brief blips (intentional — this is the
//      low-pass filtering behavior: one clean falling edge in, one
//      clean rising edge out, at the next trigger_in tooth).
//    - The hold releases on the next rising edge of trigger_in (the
//      crank-synchronized reference trigger, not a fixed clk-cycle
//      timer) — a fixed-time hold (previously 2.4ms) doesn't scale
//      with RPM, and at idle RPM released well inside a single
//      trigger_in period; tying release to the next tooth instead
//      guarantees at least one full trigger_in cycle of hold at any
//      RPM, and fake_knock_stretched goes back to mirroring
//      fake_knock directly (whatever it happens to be at that point).
//
//  Two outputs:
//
//    knock_sum — drives adc_ch5 (LM2902 comparator threshold-trip
//      channel). knock_reset takes priority: 0 forces flat 8'd000
//      regardless of fake_knock. Otherwise (knock_reset=1):
//      fake_knock_stretched=1 -> knock_sensor+8'd145, else just
//      knock_sensor. With the current klr_tb.v tie-off
//      (knock_sensor=8'd110), that's 0 / 110 / 255 decimal.
//      Unchanged by the knock_noise rework below.
//
//    knock_noise — drives adc_ch0 (knock sensor noise-level
//      channel): a rolling average of the last 10 samples of
//      (knock_sensor/4 + fake_knock*32), sampled on each rising
//      edge of trigger_in (the crank-synchronized reference trigger,
//      NOT `clk` directly — matches how the real KLR/firmware would
//      see this, sampled once per trigger tooth rather than every
//      clock cycle). Uses the RAW fake_knock input directly, not any
//      filtered/stretched version — no relation to knock_sum's
//      trigger_in-released one-shot filter, which only affects
//      knock_sum.
//
//  knock_sensor is still a fixed placeholder (8'd110, tied in
//  klr_tb.v) rather than a real sensor model — that's planned as
//  future work.
// ============================================================

`include "timescale.v"

module knock_gen (
    input  wire       clk,
    input  wire       fake_knock,
    input  wire       knock_reset,
    input  wire [7:0] knock_sensor,
    input  wire       trigger_in,
    output wire [7:0] knock_sum,
    output wire [7:0] knock_noise
);

    reg        holding              = 1'b0;  // 1 while knock_sum's hold is asserted
    reg        fake_knock_prev      = 1'b1;  // assume idle-high at sim start; shared falling-edge reference
    reg        trigger_in_prev_hold = 1'b0;  // edge detector for the release condition, local to this hold

    // TEST_KNOCK_FAKE_BLOCKED: simulates a broken connection between the
    // KLR CPU's P1.7 self-test pin and this circuitry (e.g. a bad trace
    // or open connector pin) — fake_knock_eff is forced permanently
    // idle-high, so fake_knock_prev never sees a falling edge below,
    // holding never gets asserted, and knock_sum always just
    // reflects knock_sensor directly (no +145 self-test offset ever
    // applied) — regardless of what the firmware actually drives on the
    // real fake_knock input. knock_noise's rolling average below uses
    // the raw fake_knock input directly and is unaffected by this flag
    // (matches the module's original raw-fake_knock behavior for ch0).
`ifdef TEST_KNOCK_FAKE_BLOCKED
    wire fake_knock_eff = 1'b1;
`else
    wire fake_knock_eff = fake_knock;
`endif

    // knock_sum's non-retriggering hold, released by the next trigger_in tooth
    always @(posedge clk) begin
        fake_knock_prev      <= fake_knock_eff;
        trigger_in_prev_hold <= trigger_in;

        if (!holding) begin
            // Idle -- only a falling edge seen HERE (while idle) starts
            // the hold. Not retriggerable: falls seen later, while
            // already holding, are ignored entirely.
            if (fake_knock_prev && !fake_knock_eff) begin
                holding <= 1'b1;
            end
        end else if (trigger_in && !trigger_in_prev_hold) begin
            // Next trigger_in tooth -- release back to idle/passthrough.
            holding <= 1'b0;
        end
    end

    wire fake_knock_stretched = holding ? 1'b0 : fake_knock_eff;

    assign knock_sum   = !knock_reset ? 8'd0
                        : fake_knock_stretched ? (knock_sensor + 8'd145)
                        : knock_sensor;

    // knock_noise: rolling average of the last 10 samples, sampled on
    // each rising edge of trigger_in. Two sample_val formulas:
    //
    //   Default: (knock_sensor/4 + fake_knock*32). knock_sensor>>2 is an
    //   exact truncating /4 for this unsigned 8-bit value; fake_knock*32
    //   is either 0 or 8'd32 since fake_knock is 1 bit — per-sample
    //   range is 0-63+32=0-95.
    //
    //   -DKLR_ADC0_NOISE_HIGH: (knock_sensor/256 + fake_knock*4) instead
    //   — a deliberately much smaller-scale variant for that fault test.
    //   NOTE: knock_sensor>>8 on this 8-bit value is always 0 regardless
    //   of knock_sensor's actual value (a >=8 shift on an 8-bit operand
    //   always zeros it) — so under this formula, knock_sensor's value
    //   has no numeric effect at all; only fake_knock (0 or 4 per
    //   sample) drives sample_val.
    //
    // Either way, the 10-tap sum stays well within 8 bits per-sample
    // (max 95 in the default case, max 4 in the NOISE_HIGH case) — the
    // 10-tap sum can reach 950 in the default case, needing 10 bits;
    // sample_sum is sized for that worst case regardless of which
    // formula is active.
    localparam integer AVG_TAPS = 10;

    reg  [7:0] sample_hist [0:AVG_TAPS-1];
    reg  [3:0] hist_idx      = 0;
    reg        trigger_prev  = 1'b0;
    integer    i;

    initial begin
        for (i = 0; i < AVG_TAPS; i = i + 1)
            sample_hist[i] = 8'd0;
    end

`ifdef KLR_ADC0_NOISE_HIGH
    wire [7:0] sample_val = (knock_sensor >> 8) + (fake_knock ? 8'd4 : 8'd0);
`else
    wire [7:0] sample_val = (knock_sensor >> 2) + (fake_knock ? 8'd32 : 8'd0);
`endif

    always @(posedge clk) begin
        trigger_prev <= trigger_in;
        if (trigger_in && !trigger_prev) begin
            // Rising edge of trigger_in -- take one new sample, advance
            // the ring-buffer index (wraps 9->0).
            sample_hist[hist_idx] <= sample_val;
            hist_idx <= (hist_idx == AVG_TAPS - 1) ? 4'd0 : hist_idx + 4'd1;
        end
    end

    wire [10:0] sample_sum = sample_hist[0] + sample_hist[1] + sample_hist[2] + sample_hist[3] + sample_hist[4]
                            + sample_hist[5] + sample_hist[6] + sample_hist[7] + sample_hist[8] + sample_hist[9];

    // TEST_KNOCK_FAKE_BLOCKED overrides knock_noise to a hard, immediate
    // 0xFF for the entire simulation — a plain assign, not fed through
    // the rolling average above, so there's no settling delay: it's 0xFF
    // from t=0, not "0xFF once 10 samples have flushed through." The
    // rolling-average machinery above still runs underneath (harmless —
    // just unused) so the non-blocked case doesn't need a separate code
    // path.
`ifdef TEST_KNOCK_FAKE_BLOCKED
    assign knock_noise = 8'hFF;
`else
    assign knock_noise = sample_sum / 11'd10;
`endif

endmodule

