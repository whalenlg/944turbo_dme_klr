//
// Inputs:
// Reset (pin 4) - Trigger signal from DME (80 degrees before TDC)
// Ext int (pin 6) - Ignition signal from DME
// T1 (pin 39) - Ignition signal from DME

module var_timing_generator (
    input  wire clk,rst,        // Fast Master Clock
    output reg trigger,        // Active high reset
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
            if (counter >= 24'd400000) begin
                counter <= 24'd0;
            end else begin
                counter <= counter + 1'b1;
            end

            // Logic: Low for count 0 and 1 (2 cycles), High otherwise
            if (counter < 24'd380000) begin
                #10 ign <= 1'b0;
            end else begin
                #10 ign <= 1'b1;
            end
            if (counter < 24'd190000) begin
                trigger <= 1'b0;
            end else if (counter < 190100) 
                     begin
                       trigger <= 1'b1;
                     end
                     else trigger <= 1'b0;
        end
    end 

endmodule

