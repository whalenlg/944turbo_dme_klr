module o2_generator #(
    //------------------------------------------------------------
    // Configurable parameters
    //------------------------------------------------------------
    // O2_TOP: square wave, period in clock cycles
    parameter O2_PERIOD = 15000000
    )(
    input  wire clk,
    input  wire rst,

    output reg o2_top,   // o2 0 pulse output
    output reg o2_bottom    // o2 1 pulse output
);

    //------------------------------------------------------------
    // O2_TOP: Square wave generator
    //------------------------------------------------------------
    localparam O2_ONE = O2_PERIOD / 3;
    localparam O2_TWO = O2_ONE * 2;

    reg [$clog2(O2_PERIOD)-1:0] o2top_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) 
        begin
            o2top_cnt <= 0; //normal
            o2_top    <= 0;
            o2_bottom <= 1;
        end
        else
           if (o2top_cnt == O2_PERIOD-1)
           begin
             o2top_cnt <= 0;
             o2_top    <= 0; //normal
             o2_bottom <= 1;
           end
           else
           begin
             o2top_cnt <= o2top_cnt + 1;
             if ((o2top_cnt > O2_ONE) && (o2top_cnt < O2_TWO)) 
             begin //LEAN
               o2_top    <=1;
               o2_bottom <=1;
             end
             else if (o2top_cnt > O2_TWO) //RICH
             begin
               o2_top    <=0;
               o2_bottom <=0;
             end
           end
    end
endmodule

