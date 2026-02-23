module var_interrupt_generator (
    input  wire clk,        // Fast Master Clock
    input  wire rst,        // Active high reset
    output reg  int_0,int_1 // The slowing square wave
);
    integer period_current,period_inc;
    localparam period_start = `RPMCONST/`RPMSTART;
    localparam period_end =   `RPMCONST/`RPMEND;
    localparam period_change = `SIM_TIME*`FREQ/(period_start+period_end)/22500000;
    integer cycle_count  = 0;
    integer tick_counter = 0;
    //localparam period_change=`SIM_TIME/`FRQ_SCALE;
//    localparam period_change=1600/10;
    reg [7:0] counter;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            int_1  <= 0;
            cycle_count  <= 0;
            tick_counter <= 0;
            period_inc = (period_start - period_end)/40;
            period_current = period_start;

        end else begin
            // Increment the counter for the current period
            if (tick_counter >= (period_current / 2) - 1) begin
                tick_counter <= 0;
                int_1  <= ~int_1;

                // On every full cycle of the int_1 (falling edge)
                if (int_1 == 1) begin 
                    if (cycle_count >= period_change) begin
                        cycle_count <= 0;
                        if (period_current > period_end)
                            period_current <= period_current - period_inc;
                    end else begin
                        cycle_count <= cycle_count + 1;
                    end
                end //if
            end else begin
                tick_counter <= tick_counter + 1;
            end
     end
    end //always
// 134 total cycles requires 8 bits (2^8 = 256)
    always @(posedge int_1 or posedge rst) begin
        if (rst) begin
            counter <= 8'd0;
            int_0 <= 1'b0;
        end else begin
            if (counter >= 8'd133) begin
                counter <= 8'd0;
            end else begin
                counter <= counter + 1'b1;
            end

            // Logic: Low for count 0 and 1 (2 cycles), High otherwise
            if (counter < 8'd2) begin
                int_0 <= 1'b0;
            end else begin
                int_0 <= 1'b1;
            end
        end
    end 

endmodule

