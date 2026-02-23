module adc_delay_8 (
    input  wire       clk,            // Input Clock
    input  wire       rst,          // Active-low Reset
    input  wire [7:0] p0_in,          // 8-bit Input Bus (p0_in)
    output wire [7:0] data_out_xram   // Delayed 8-bit Output Bus (data_out_xram)
);

    // Internal shift register: 8 stages, each 8 bits wide
    reg [7:0] delay_pipe [0:7];

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Synchronous reset of all stages in the pipe
            for (i = 0; i < 8; i = i + 1) begin
                delay_pipe[i] <= 8'h00;
            end
        end else begin
            // Load the first stage with p0_in
            delay_pipe[0] <= p0_in;
            
            // Shift the data through the remaining 7 stages
            for (i = 1; i < 8; i = i + 1) begin
                delay_pipe[i] <= delay_pipe[i-1];
            end
        end
    end

    // Assign the final stage to the output
    assign data_out_xram = delay_pipe[7];

endmodule
