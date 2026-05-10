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
    localparam period_change = `SIM_TIME*`FREQ/(period_start+period_end)/22500000;
    integer cycle_count  = 0;
    integer tick_counter = 0;
    reg [23:0] counter;
    


   always @(negedge trigger or posedge rst or posedge clk) begin
        if (!rst) begin
            counter <= 16'd0;
            ign <= #10 1'b0;
        end else begin
            // Wrap counter at end of period
            if (counter >= 24'd400000) begin
                counter <= 24'd0;
            end else begin
                counter <= counter + 1'b1;
            end

            // ── Trigger pulse ─────────────────────────────────────────
            // Narrow pulse at the START of each cycle (counter 0..99).
            // Matches oscilloscope: blue spike fires at the leading edge
            // of every engine cycle, well before the ignition event.
            if (counter < 24'd100) begin
                trigger <= 1'b1;
            end else begin
                trigger <= 1'b0;
            end

            // ── Ignition signal ───────────────────────────────────────
            // Goes HIGH 25% into the cycle (counter 100000),
            // stays HIGH for 25% of the cycle (until counter 200000),
            // then LOW for the remaining 50%.
            // Matches oscilloscope: IGN rising edge ~10ms after trigger,
            // HIGH for ~10ms, LOW for ~20ms at ~1500 RPM (40ms period).
            if (counter >= 24'd100000 && counter < 24'd200000) begin
                #10 ign <= 1'b1;
            end else begin
                #10 ign <= 1'b0;
            end
        end
    end 

endmodule

