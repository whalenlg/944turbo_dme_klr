// ----------------------------------------------------------------
//  ADC0809 model — START/ALE/OE tied to !xrd_n
//
//  Behaviour:
//    1. posedge start: latch data_in and addr, begin 11-cycle countdown
//    2. After 11 ALE cycles: result is ready, waiting for next start
//    3. posedge start (next read): present held result on data_out,
//       latch new data_in, begin new 11-cycle countdown
//    4. data_out holds until next posedge start
//
//  The pipeline runs freely for exactly 11 ALE cycles after each
//  start, then stops. The result is presented on the NEXT start.
//  This means each read returns the conversion from the previous
//  read — one read behind, which is correct ADC0809 behaviour.
// ----------------------------------------------------------------
module adc_delay_8 (
    input  wire       clk,       // ALE — pipeline clock
    input  wire       rst,       // active-low reset
    input  wire [7:0] data_in,   // combinatorial ADC mux
    input  wire       start,     // !xrd_n
    output reg  [7:0] data_out
);

    localparam DEPTH = 8;

    reg [7:0] pipe    [0:DEPTH-1];
    reg [7:0] result;             // holds completed conversion
    reg [3:0] count;              // counts ALE cycles after start
    reg       running;            // pipeline active
    integer   i;

    // Pipeline — runs for DEPTH ALE cycles after each posedge start
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < DEPTH; i = i + 1)
                pipe[i] <= 8'h00;
            result  <= 8'h00;
            count   <= 4'd0;
            running <= 1'b0;
        end else begin
            if (running) begin
                // Shift pipeline
                pipe[0] <= data_in;
                for (i = 1; i < DEPTH; i = i + 1)
                    pipe[i] <= pipe[i-1];
                if (count == DEPTH - 1) begin
                    // Conversion complete — store result, stop
                    result  <= pipe[DEPTH-1];
                    running <= 1'b0;
                    count   <= 4'd0;
                end else begin
                    count <= count + 1'b1;
                end
            end
        end
    end

    // posedge start: present previous result, start new conversion
    always @(posedge start or negedge rst) begin
        if (!rst) begin
            data_out <= 8'h00;
            running  <= 1'b0;
            count    <= 4'd0;
        end else begin
            data_out <= result;   // output previous conversion
            running  <= 1'b1;    // start new conversion
            count    <= 4'd0;
        end
    end

endmodule
