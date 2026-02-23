module i8048_top (
    input wire clk, res_n, int_n, t0, t1,
    input wire [7:0] bus_in,
    output wire [7:0] p1, p2, bus_out, bus_addr,
    output wire ale, psen_n, rd_n, wr_n, prog
    );


    wire [11:0] pc;
    wire [7:0]  ir;
    wire [7:0]  acc;
    wire        cycle_2;
    wire [7:0]  rom_data;
    reg  [11:0] rom_addr;


    // --- The Address Multiplexer ---
    // This is the "Brain" that decides what the ROM sees
    always @(*) begin
        if (cycle_2) begin
            case (ir)
                8'hA3: rom_addr = {pc[11:8], acc}; // MOVP: Current Page + Acc
                8'hE3: rom_addr = {4'b0011, acc};  // MOVP3: Page 3 + Acc
                default: rom_addr = pc;            // Standard 2-byte operand fetch
            endcase
        end else begin
            rom_addr = pc; // Standard Opcode Fetch
        end
    end


    // --- Instantiate your Core ---
    i8048_core i8048_core_1 (
        .clk(clk),
        .res_n(res_n),
        .int_n(int_n),.t0(t0),.t1(t1),
        .rom_data(rom_data), .bus_in(bus_in),
        .pc(pc),    // The core outputs its PC
        .ir(ir),          // Export IR for the mux
        .p1(p1),.p2(p2),.bus_out(bus_out),.bus_addr(bus_addr),
        .acc(acc),        // Export Acc for the mux
        .ale(ale), .psen_n(psen_n), .rd_n(rd_n), .wr_n(wr_n), .prog(prog), 
        .cycle_2(cycle_2) // Export cycle state
    );

    // --- Instantiate your ROM (89KLR_951.bin) ---
    // Ensure this module loads your hex/mem file
    rom_1 rom_1 (
        .addr(rom_addr),
        .data(rom_data)
    );

endmodule

module rom_1(
   input wire [11:0] addr,
   output wire [7:0] data
   );
    reg [7:0] rom [0:4095];
    assign #10 data =  rom[addr];
endmodule




