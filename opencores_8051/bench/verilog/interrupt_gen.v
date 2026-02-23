module interrupt_generator #(
    //------------------------------------------------------------
    // Configurable parameters
    //------------------------------------------------------------
    // INT_1: square wave, period in clock cycles
//    parameter INT1_PERIOD = 2480, //1136 RPM
    parameter INT1_PERIOD = 1240, //2272 RPM

    // INT_0: pulse with custom high-time and full period
//    parameter INT0_PERIOD = 327360, //132 * INT1_PERIOD
    parameter INT0_PERIOD = 163680, //132 * INT1_PERIOD
//    parameter INT0_HIGH   = 4960 
    parameter INT0_HIGH   = 2480 
)(
    input  wire clk,
    input  wire rst,

    output reg int_0,   // interrupt 0 pulse output
    output reg int_1    // interrupt 1 pulse output
);

    //------------------------------------------------------------
    // INT_1: Square wave generator
    //------------------------------------------------------------
    localparam INT1_HALF = INT1_PERIOD / 2;

    reg [$clog2(INT1_PERIOD)-1:0] int1_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            int1_cnt <= 0;
            int_1    <= 0;
        end else begin
            if (int1_cnt == INT1_PERIOD-1)
                int1_cnt <= 0;
            else
                int1_cnt <= int1_cnt + 1;

            int_1 <= (int1_cnt < INT1_HALF);
        end
    end


    //------------------------------------------------------------
    // INT_0: configurable pulse generator
    //------------------------------------------------------------
    reg [$clog2(INT0_PERIOD)-1:0] int0_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            int0_cnt <= 1;
            int_0    <= 1;
        end else begin
            if (int0_cnt == INT0_PERIOD-1)
                int0_cnt <= 1;
            else
                int0_cnt <= int0_cnt + 1;

            int_0 <= !(int0_cnt < INT0_HIGH);
        end
    end

endmodule

