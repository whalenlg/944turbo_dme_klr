module adc_8090 (
    input  wire       clk,           		 // Input Clock
    input  wire       oe,start,ale,          // Active-low Reset
    input  wire [7:0] data_in7,data_in6,data_in5,data_in4,data_in3,data_in2,data_in1,data_in0,    		 // Delayed 8-bit Output Bus (data_out_xram)
    input  wire [2:0] addr,         		 // 3-bit Address (p0_in)
    output reg [7:0] data_out,     		 // Delayed 8-bit Output Bus (data_out_xram)
    output wire eoc
);

    // Internal shift register: 8 stages, each 8 bits wide
    reg [7:0] delay_pipe [0:7];
    reg [2:0] addr_reg;
    integer i;

    always @(posedge clk or posedge start) begin
        if (ale) begin
           addr_reg <= addr;
        end 
        if (start) begin
            // Synchronous reset of all stages in the pipe
            for (i = 0; i < 8; i = i + 1) begin
                delay_pipe[i] <= 8'h00;
            end
        end else begin
            // Load the first stage with p0_in
            case (addr_reg) 
              3'h0: delay_pipe[0] <= data_in0;
              3'h1: delay_pipe[0] <= data_in1;
              3'h2: delay_pipe[0] <= data_in2;
              3'h3: delay_pipe[0] <= data_in3;
              3'h4: delay_pipe[0] <= data_in4;
              3'h5: delay_pipe[0] <= data_in5;
              3'h6: delay_pipe[0] <= data_in6;
              3'h7: delay_pipe[0] <= data_in7;
            endcase
            
            // Shift the data through the remaining 7 stages
            for (i = 1; i < 8; i = i + 1) begin
                delay_pipe[i] <= delay_pipe[i-1];
            end
        end
        data_out <= delay_pipe[7];
    end
endmodule
