//
// Inputs:
// Reset (pin 4) - Trigger signal from DME (80 degrees before TDC)
// Ext int (pin 6) - Ignition signal from DME
// T1 (pin 39) - Ignition signal from DME

module var_timing_generator (
    input  wire clk,rst,        // Fast Master Clock
    output reg trigger = 1'b1,  // start high → res_n=0 (CPU held in reset until first pulse ends)
    output reg  ign // The slowing square wave
);
    integer period_current,period_inc;
    localparam period_start = `RPMCONST/`RPMSTART;
    localparam period_end =   `RPMCONST/`RPMEND;
    localparam [63:0] period_change = (64'd1 * `SIM_TIME * `KLR_FREQ) / (period_start + period_end) / 22500000;
    integer cycle_count  = 0;
    integer tick_counter = 0;
    reg [23:0] counter;
    


    // ── Clocked always block — compatible with both iverilog and Verilator ──
    // Original used mixed sensitivity (negedge trigger OR posedge rst OR posedge clk)
    // which Verilator handles differently. Rewritten as pure posedge clk with
    // explicit reset. The negedge trigger sensitivity was redundant — the counter
    // already resets to 0 on rst, and trigger is driven combinatorially from counter.
    // The #10 delays on ign are removed (Verilator ignores them; functionally
    // the 10ns delay is irrelevant at KLR_FREQ timescales).
    always @(posedge clk) begin
        if (!rst) begin
            counter <= 24'd0;
            ign     <= 1'b0;
        end else begin
            // Wrap counter at end of period
            if (counter >= 24'd400000) begin
                counter <= 24'd0;
            end else begin
                counter <= counter + 1'b1;
            end

            // ── Trigger pulse ─────────────────────────────────────────
            // Narrow pulse at the START of each cycle (counter 0..99).
            if (counter < 24'd100) begin
                trigger <= 1'b1;
            end else begin
                trigger <= 1'b0;
            end

            // ── Ignition signal ───────────────────────────────────────
            // Goes HIGH 25% into the cycle, stays HIGH for 25%, then LOW.
            if (counter >= 24'd100000 && counter < 24'd200000) begin
                ign <= 1'b1;
            end else begin
                ign <= 1'b0;
            end
        end
    end

endmodule
