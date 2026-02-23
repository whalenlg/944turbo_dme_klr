module i8048_core (
    input  wire        clk, res_n, t0, t1,int_n,
    input  wire [7:0] rom_data,
    input  wire [7:0]  bus_in,
    output reg  [11:0] pc,
    output reg  [7:0]  ir,p1,p2, acc, bus_addr, bus_out,
    output reg         ale, psen_n, rd_n, wr_n, prog, cycle_2
);

    // --- Registers & State ---
    reg [2:0] state;               
    reg [7:0] psw;
    reg [7:0] ram [0:127];          
    reg       irq_in_progress, irq_en_ext, irq_en_timer;
    reg       timer_en, timer_flag,timer_running,timer_mode,mb_latch;
    reg [7:0] timer_val;
    reg [4:0] prescaler;
    reg [7:0] rmem_dat, rmem_dat2, wmem_dat, wmem_dat2,acc_preop,ram_preop,timer_preop,bus_preop;
    reg [11:0] next_pc;
    // --- Helpers ---
    reg [2:0] sp;
    wire       bs = psw[4];        
    //wire [6:0] rn_addr      = {2'b00, bs, ir[2:0]};
    wire [6:0] rn_addr = (psw[4]) ? {4'b0011, ir[2:0]} : {4'b0000, ir[2:0]};

    wire [6:0] ri_addr      = {1'b0,ram[rn_addr][6:0]};
    reg [2:0] sp_minus_1,sp_minus_2,intr_in_progress;
    wire [11:0] ret_addr = pc + 12'd2;
    reg f1,f0;
    reg [7:0] callmem1, callmem2, retmem1,retmem2;
  
// Determine current R0 or R1 based on PSW bank bit (psw[4])
// Better yet, just use the absolute RAM address:
wire [6:0] ptr_addr = (ir[0] ? ram[psw[4]?8'h19:8'h01] : ram[psw[4]?8'h18:8'h00]);
reg [255:0] opinstr[255:0];

wire is_2_cycle = 
    (ir[3:0] == 4'h4) || // JMP & CALL (All pages: 04, 24, 44, 64, 84, A4, C4, E4)
    (ir[3:0] == 4'h6) || // All Conditional Jumps (JZ, JNZ, JC, JNC, JT0/1, JNT0/1, etc.)
    (ir[3:0] == 4'h2) || // All JB0-JB7 instructions (12, 32, 52, 72, 92, B2, D2, F2)
    (ir[7:4] == 4'hB) || // MOV Rn, #data (B8-BF) and MOV @Ri, #data (B0-B1)
    (ir[7:4] == 4'hE) || // DJNZ Rn (E8-EF)
    (ir == 8'h23)     || // MOV A, #data
    (ir == 8'hA3)     || // MOVP A, @A (Requires a stall cycle for ROM address mux)
    (ir == 8'hE3)     ||  // MOVP3 A, @A (Requires a stall cycle)
    (ir == 8'h9A)     || // <--- Add this
    (ir == 8'h8A)     || // <--- And these for safety
    (ir == 8'h99)     || 
    (ir[7:4] == 4'hE) ||  // Catch E8-EF
    (ir == 8'h16)     ||
    (ir[3:0] == 4'h6) ||
    (ir == 8'h60)      ||
    (ir == 8'h61)      ||
    (ir == 8'h03)      ||
    (ir == 8'hB6)      ||
    (ir == 8'h83)      ||
    (ir == 8'h93)      ||
    (ir == 8'h53)      ||
    (ir == 8'h43)      ||
    (ir == 8'hD3)      ||
    (ir == 8'h13)      ||
    (ir == 8'hB3)      ||
    (ir == 8'h89);

wire next_cycle_state = (cycle_2 == 0 && is_2_cycle) ? 1'b1 : 1'b0;

initial
   $readmemh("/Users/Mike/coding_projects/944/DME_sim/gemini8048/bin/op_ins8048.hex",opinstr);


// Task to display bus and memory status
task display_read_status;
    input[7:0] instr;
    input [7:0] data_old;
    input [7:0] data_read;
    input [7:0] data_out;
    input [11:0] address;
    begin
        $display("\t\t\t\tOpCode: %h | Instr: %s | Addr: %h | OldVal: %h | ReadVal: %h | ResultVal: %h",
                 instr,opinstr[instr],address, data_old, data_read, data_out);
    end
endtask

task service_interrupt;
    input [11:0] vector;
    input [11:0] return_addr; // Pass the address explicitly
    begin
        irq_in_progress <= 1'b1;
        // Store the address passed to the task, not the 'live' PC register
        ram[{psw[2:0], 1'b0} + 6'h08] <= return_addr[7:0];
        ram[{psw[2:0], 1'b1} + 6'h08] <= {psw[7:4], return_addr[11:8]};
        psw[2:0] <= psw[2:0] + 1'b1; // Move Stack Pointer
        pc <= vector;                // Jump to ISR
        #10 display_read_status(ir,pc[7:0], {psw[7:4], return_addr[11:8]},return_addr[7:0],vector);
    end
endtask

// --- Address Bus Multiplexer ---
// If we are in cycle_2 of a MOVP instruction, we point to the page/acc.
// Otherwise, we point to the PC.
wire [11:0] mem_addr = (ir == 8'hA3 && cycle_2) ? {pc[11:8], acc} : 
                       (ir == 8'hE3 && cycle_2) ? {4'b0011, acc} : 
                       pc;


// --- ROM Data Latching ---
always @(posedge clk) begin
    if (!res_n) begin
        ir <= 8'h00;
        cycle_2 <= 0;
    end else begin
        if (!cycle_2) begin
            // Fetch phase: Update IR with new opcode
            ir <= rom_data; 
        end
    sp_minus_1 <= sp - 3'd1;
    sp_minus_2 <= sp - 3'd2;
    sp <= psw[2:0];
    end

end



    // --- Timing Engine ---
    always @(posedge clk or negedge res_n) begin
        if (!res_n) begin
            pc <= 12'h000; state <= 3'd1; cycle_2 <= 0; psw <= 8'h00;
            irq_in_progress <= 0; irq_en_ext <= 0; irq_en_timer <= 0;
            timer_en <= 0; timer_flag <= 0; timer_val <= 0; prescaler <= 0;
            f1 <= 0;f0 <= 0;
            mb_latch <= 0;
            //{p1, p2, bus_out, bus_addr} <= 40'hFFFFFFFF; {ale, psen_n, rd_n, wr_n, prog} <= 5'b01111;
            {ale, psen_n, rd_n, wr_n, prog} <= 5'b01111;
        end else begin
            case (state)
                3'd1: begin ale <= 1; psen_n <= 0; rd_n <= 1; wr_n <= 1; prog <= 1; state <= 3'd2; end
                3'd2: begin ale <= 0; state <= 3'd3; end
                3'd3: begin 
//                    if (!cycle_2) ir <= rom_data; 
                    // Handle MOVX Read Strobe
                    if (ir == 8'h80 || ir == 8'h81) rd_n <= 0; 
                    state <= 3'd4; 
                end
                3'd4: begin 
                    psen_n <= 1; 
                    // Handle MOVX Write and Expander PROG Strobes
//                    if (ir == 8'h90 || ir == 8'h91) begin wr_n <= 0; db_out <= acc; end
                    if (ir[7:4] == 4'h3 && ir[3:2] == 2'b11) prog <= 0; // MOVD expander
                    state <= 3'd5; 
                end




                3'd5: begin
                    state <= 3'd1;
                    if (!irq_in_progress && !cycle_2) begin
                        if (irq_en_ext && !int_n) begin
                             // Force the math inside the task call so the stack gets the NEXT address
                             service_interrupt(12'h003, is_2_cycle ? pc + 2 : pc + 1);
                        end 
                        else if (irq_en_timer && timer_flag) begin
                             service_interrupt(12'h007, is_2_cycle ? pc + 2 : pc + 1);
                        end 
                        else begin
                            execute_instruction();
                        end
                    end else begin
                        execute_instruction();
                    end
                end





            endcase
        end
    end

    // --- Full Instruction Set Decoder ---

task execute_instruction;
    begin
        casez (ir)
            // --- Accumulator & ALU ---
            8'h03: begin // ADD A, #data
                if (!cycle_2) begin
                    pc <= pc + 1'b1;
                    cycle_2 <= 1'b1;
                end else begin
                    acc_preop <= acc;
                    {psw[7], acc} <= acc + rom_data;
                    psw[6] <= (acc[3:0] + rom_data[3:0] > 4'hF);
                    #10 display_read_status(ir,acc_preop,rom_data,acc,pc);
                    pc <= pc + 1'b1;
                    cycle_2 <= 1'b0;
                end
            end
            8'h07: begin // DEC A [cite: 108]
                acc_preop <= acc;
                acc <= acc - 1'b1;
                #10 display_read_status(ir,acc_preop,8'hXX,acc,12'hACC);
                pc <= pc + 1'b1;
            end
            8'h17: begin // INC A [cite: 1, 2]
                acc_preop <= acc;
                acc <= acc + 1'b1; 
                #10 display_read_status(ir,acc_preop,8'hXX,acc,12'hACC);
                pc <= pc + 1'b1; 
            end

            8'h27: begin // CLR A
                acc_preop <= acc;
                acc <= 8'h00;     // Set all bits to 0
                #10 display_read_status(ir,acc_preop,8'hXX,acc,12'hACC);
                pc  <= pc + 1'b1; // Advance to next instruction
            end

            8'h37: begin // CPL A (Complement Accumulator)
                     acc <= ~acc;      // Bitwise NOT: 0 becomes 1, 1 becomes 0
                     pc  <= pc + 1'b1; // Advance to next instruction
                   end

            8'h43: begin // ORL A, #data [cite: 166, 168]
                if (!cycle_2) begin
                    pc <= pc + 1'b1;
                    cycle_2 <= 1'b1;
                end else begin
                acc_preop <= acc;
                    acc_preop <= acc;
                    acc <= acc | rom_data;
                    #10 display_read_status(ir,acc_preop,rom_data,acc,pc);
                    pc <= pc + 1'b1;
                    cycle_2 <= 1'b0;
                end
            end
            8'h47: begin // SWAP A [cite: 114]
                acc_preop <= acc;
                acc <= {acc[3:0], acc[7:4]};
                #10 display_read_status(ir,acc_preop,8'hXX,acc,12'hACC);
                pc <= pc + 1'b1;
            end
            8'h53: begin // ANL A, #data [cite: 161, 165]
                if (!cycle_2) begin
                    pc <= pc + 1'b1;
                    acc_preop <= acc;
                    cycle_2 <= 1'b1;
                end else begin
                    acc <= acc & rom_data;
                    #10 display_read_status(ir,acc_preop,rom_data,acc,pc);
                    pc <= pc + 1'b1;
                    cycle_2 <= 1'b0;
                end
            end
            8'h67: begin // RRC A [cite: 149]
                acc_preop <= acc;
                acc <= {psw[7], acc[7:1]};
                psw[7] <= acc[0];
                #10 display_read_status(ir,acc_preop,8'hXX,acc,12'hACC);
                pc <= pc + 1'b1;
            end
            8'h77: begin // RR A [cite: 150]
                acc_preop <= acc;
                acc <= {acc[0], acc[7:1]};
                #10 display_read_status(ir,acc_preop,8'hXX,acc,12'hACC);
                pc <= pc + 1'b1;
            end
            8'hD3: begin // XRL A, #data [cite: 169, 171]
                if (!cycle_2) begin
                    pc <= pc + 1'b1;
                    acc_preop <= acc;
                    cycle_2 <= 1'b1;
                end else begin
                    acc <= acc ^ rom_data;
                    #10 display_read_status(ir,acc_preop,rom_data,acc,pc);
                    pc <= pc + 1'b1;
                    cycle_2 <= 1'b0;
                end
            end
            8'hF7: begin // RLC A [cite: 147, 148]
                acc_preop <= acc;
                acc <= {acc[6:0], psw[7]}; 
                psw[7] <= acc[7];
                #10 display_read_status(ir,acc_preop,8'hXX,acc,12'hACC);
                pc <= pc + 1'b1;
            end

            // -----------------------------------------------------------------
            // RL A  [0xE7]
            //   Rotate accumulator left without carry. Bit 7 wraps to bit 0.
            //   No flags affected. Single-cycle.
            //   Complement of RR A (0x77) which rotates right without carry.
            // -----------------------------------------------------------------
            8'hE7: begin // RL A
                acc_preop <= acc;
                acc <= {acc[6:0], acc[7]};
                #10 display_read_status(ir, acc_preop, 8'hXX, acc, 12'hACC);
                pc <= pc + 1'b1;
            end

            // --- Register & Internal RAM ---
            8'h23: begin // MOV A, #data [cite: 3, 5]
                if (!cycle_2) begin 
                    pc <= pc + 1'b1;
                    cycle_2 <= 1; 
                    acc_preop <= acc;
                end else begin 
                    acc <= rom_data; 
                    #10 display_read_status(ir,acc_preop,rom_data,acc,pc);
                    pc <= pc + 1'b1; 
                    cycle_2 <= 0; 
                end
            end
            8'h42: begin // MOV A, T [cite: 97]
                acc_preop <= acc;
                acc <= timer_val; 
                #10 display_read_status(ir,acc_preop,timer_val,acc,12'hACC);
                pc <= pc + 1'b1;
            end
            8'h62: begin // MOV T, A [cite: 96]
                timer_preop = timer_val;
                timer_val <= acc; 
                #10 display_read_status(ir,timer_preop,acc,timer_val,12'hACC);
                pc <= pc + 1'b1;
            end
            8'hA0, 8'hA1: begin // MOV @Ri, A [cite: 8]
                ram_preop <= ram[ptr_addr];
                ram[ptr_addr] <= acc;
                wmem_dat <= ram[ptr_addr];
                #10 display_read_status(ir,ram_preop,acc,wmem_dat,ptr_addr);
                pc <= pc + 1'b1;
            end
            8'hA8, 8'hA9, 8'hAA, 8'hAB, 8'hAC, 8'hAD, 8'hAE, 8'hAF: begin // MOV Rn, A [cite: 5, 6]
                ram_preop <= ram[rn_addr];
                ram[rn_addr] <= acc;
                wmem_dat <= ram[rn_addr];
                #10 display_read_status(ir,ram_preop,acc,wmem_dat,rn_addr);
                pc <= pc + 1'b1;
            end
            8'hB0, 8'hB1: begin // MOV @Ri, #data [cite: 9, 11]
                if (!cycle_2) begin 
                    pc <= pc + 1'b1;
                    cycle_2 <= 1; 
                end else begin 
                    ram_preop <= ram[ptr_addr];
                    ram[ptr_addr] <= rom_data;
                    wmem_dat <= ram[ptr_addr];
                    #10 display_read_status(ir,ram_preop,acc,wmem_dat,ptr_addr);
                    pc <= pc + 1'b1; 
                    cycle_2 <= 0;
                end
            end
            8'hF0, 8'hF1: begin // MOV A, @Ri [cite: 12]
                acc_preop <= acc;
                acc <= ram[ptr_addr];
                rmem_dat <= ram[ptr_addr];
                #10 display_read_status(ir,acc_preop,rmem_dat,acc,ptr_addr);
                pc <= pc + 1'b1;
            end
            8'hF8, 8'hF9, 8'hFA, 8'hFB, 8'hFC, 8'hFD, 8'hFE, 8'hFF: begin // MOV A, Rn [cite: 6, 7]
                acc_preop <= acc;
                acc <= ram[rn_addr];
                rmem_dat <= ram[rn_addr];
                #10 display_read_status(ir,acc_preop,rmem_dat,acc,rn_addr);
                pc <= pc + 1'b1; 
            end

            // --- Indirect & Exchange ---
            8'b0111000?: begin // ADDC A, @Ri [cite: 159, 160]
                {psw[7], acc} <= acc + ram[ptr_addr] + psw[7];
                psw[6] <= (acc[3:0] + ram[ptr_addr][3:0] + psw[7] > 4'hF);
                rmem_dat <= ram[ptr_addr];
                pc <= pc + 1'b1;
            end
            8'b0010000?: begin // XCH A, @Ri [cite: 126, 128]
                acc_preop <= acc;
                acc <= ram[ptr_addr];
                rmem_dat <= ram[ptr_addr];
                ram[ptr_addr] <= acc;
                wmem_dat <= ram[ptr_addr];
                #10 display_read_status(ir,acc_preop,rmem_dat,acc,ptr_addr);
                pc <= pc + 1'b1;
            end
            8'b00101???,8'b00111???: begin // XCH A, Rn [cite: 136, 138]
                acc_preop <= acc;
                acc <= ram[rn_addr];
                rmem_dat <= ram[rn_addr];
                ram[rn_addr] <= acc;
                wmem_dat <= ram[rn_addr];
                #10 display_read_status(ir,acc_preop,rmem_dat,acc,rn_addr);
                pc <= pc + 1'b1;
            end
            8'b0011000?: begin // XCHD A, @Ri [cite: 115]
                acc_preop <= acc;
                acc[3:0] <= ram[ri_addr][3:0];
                rmem_dat <= ram[ri_addr];
                ram[ri_addr][3:0] <= acc[3:0];
                wmem_dat <= ram[ri_addr];
                #10 display_read_status(ir,acc_preop,rmem_dat,acc,ri_addr);
                pc <= pc + 1'b1;
            end
            8'b0110000?: begin // ADD A, @Ri [cite: 132, 135]
                acc_preop <= acc;
                {psw[7], acc} <= acc + ram[ptr_addr];
                rmem_dat <= ram[ptr_addr];
                psw[6] <= (acc[3:0] + ram[ptr_addr][3:0] > 4'hF);
                #10 display_read_status(ir,acc_preop,rmem_dat,acc,ptr_addr);
                pc <= pc + 1'b1;
            end
            8'b10111???: begin // MOV Rn, #data [cite: 92, 95]
                if (!cycle_2) begin 
                    pc <= pc + 1'b1;
                    cycle_2 <= 1;
                end else begin 
                    ram_preop <= ram[rn_addr];
                    ram[rn_addr] <= rom_data;
                    #10 display_read_status(ir,ram_preop,rom_data,ram[rn_addr] ,rn_addr);
                    pc <= pc + 1'b1; 
                    cycle_2 <= 0;
                end
            end
            // -----------------------------------------------------------------
            // INC @Ri  [0x10 = @R0,  0x11 = @R1]
            //   Increment the RAM byte at the address pointed to by R0 or R1.
            //   No flags are affected. Single-cycle.
            //   Pattern 8'b0001000r covers 0x10 (@R0) and 0x11 (@R1).
            // -----------------------------------------------------------------
            8'b0001000?: begin // INC @Ri  (0x10=@R0, 0x11=@R1)
                ram_preop <= ram[ptr_addr];
                ram[ptr_addr] <= ram[ptr_addr] + 1'b1;
                wmem_dat <= ram[ptr_addr];
                #10 display_read_status(ir, ram_preop, 8'hXX, ram[ptr_addr], ptr_addr);
                pc <= pc + 1'b1;
            end
            8'b00011???: begin // INC Rn [cite: 106]
                ram_preop <= ram[rn_addr];
                ram[rn_addr] <= ram[rn_addr] + 1'b1;
                wmem_dat <= ram[rn_addr];
                #10 display_read_status(ir,ram_preop,8'hXX,ram[rn_addr],rn_addr);
                pc <= pc + 1'b1;
            end
            8'b11001???: begin // DEC Rn [cite: 107]
                ram_preop <= ram[rn_addr];
                ram[rn_addr] <= ram[rn_addr] - 1'b1;
                wmem_dat <= ram[rn_addr];
                #10 display_read_status(ir,ram_preop,8'hXX,ram[rn_addr],rn_addr);
                pc <= pc + 1'b1;
            end

            // --- External Data (MOVX) ---
            8'h80, 8'h81: begin // MOVX A, @Ri [cite: 13, 16]
                bus_preop <= bus_in;
                acc <= bus_in;
                bus_addr <= ram[(psw[4] ? 5'h18 : 5'h00) + ir[0]];
                bus_out <= bus_addr;
                #10 display_read_status(ir,bus_preop,acc,bus_out,bus_addr);
                pc <= pc + 1'b1;
            end
            8'h90, 8'h91: begin // MOVX @Ri, A [cite: 18, 25]
                if (!cycle_2) begin
                    bus_addr <= ram[(psw[4] ? 5'h18 : 5'h00) + ir[0]];
                    ale <= 1'b1;
                    wr_n <= 1'b1;
                    pc <= pc + 1'b1;
                    cycle_2 <= 1'b1;
                end else begin
                    bus_preop <= bus_out;
                    ale <= 1'b0;
                    bus_out <= acc;
                    wr_n <= 1'b0;
                    #10 display_read_status(ir,bus_preop,acc,bus_out,bus_addr);
                    pc <= pc + 1'b1;
                    cycle_2 <= 1'b0;
                end
            end
            8'hB3: begin // JMPP @A (Jump Indirect)
                if (!cycle_2) begin
                    // Cycle 1: Set up the ROM address to fetch the jump target
                    // The address is {Current_PC_Page, Accumulator}
                    pc <= {pc[11:8], acc};
                    cycle_2  <= 1'b1;
                    //pc <= pc + 1'b1;
                end else begin
                    // Cycle 2: The ROM has responded with the data at that address
                    // This data becomes the new low 8 bits of the PC
                    pc[7:0]  <= rom_data; 
                    // Note: PC[11:8] remains unchanged (it jumps within the page)
                    #10 display_read_status(ir,acc,rom_data,8'hXX,pc);
                    //pc <= pc + 1'b1;
                    cycle_2 <= 1'b0;
                end
            end

            // --- Control & Jumps ---
            8'b???00100: begin // JMP [cite: 26, 27]
                if (!cycle_2) begin 
                    pc <= pc + 1'b1;
                    cycle_2 <= 1; 
                end else begin 
                    pc[7:0] <= rom_data;
                    pc[10:8] <= ir[7:5]; 
                    pc[11] <= mb_latch; 
                    cycle_2 <= 0; 
                end
            end
            8'h12, 8'h32, 8'h52, 8'h72, 8'h92, 8'hB2, 8'hD2, 8'hF2: begin // JB0-JB7 [cite: 47, 52]
                if (!cycle_2) begin 
                    pc <= pc + 1'b1;
                    cycle_2 <= 1; 
                end else begin 
                    if (acc[ir[7:5]]) pc[7:0] <= rom_data;
                    else pc <= pc + 1'b1;
                    cycle_2 <= 0; 
                end
            end
            8'h16: begin // JTF [cite: 61, 65]
                if (!cycle_2) begin
                    pc <= pc + 1'b1;
                    cycle_2 <= 1;
                end else begin
                    if (timer_flag) begin
                        pc <= {pc[11:8], rom_data};
                        timer_flag <= 0;
                    end else begin
                        pc <= pc + 1'b1;
                    end
                    cycle_2 <= 0;
                end
            end
            8'h26: begin // JNT0 [cite: 41, 42]
                if (!cycle_2) begin pc <= pc + 1'b1; cycle_2 <= 1; end
                else begin if (!t0) pc[7:0] <= rom_data; else pc <= pc + 1'b1; cycle_2 <= 0; end
            end
            8'h36: begin // JT0 [cite: 43, 44]
                if (!cycle_2) begin pc <= pc + 1'b1; cycle_2 <= 1; end
                else begin if (t0) pc[7:0] <= rom_data; else pc <= pc + 1'b1; cycle_2 <= 0; end
            end
            8'h46: begin // JNT1 [cite: 37, 38]
                if (!cycle_2) begin pc <= pc + 1'b1; cycle_2 <= 1; end
                else begin if (!t1) pc[7:0] <= rom_data; else pc <= pc + 1'b1; cycle_2 <= 0; end
            end
            8'h56: begin // JT1 [cite: 39, 40]
                if (!cycle_2) begin pc <= pc + 1'b1; cycle_2 <= 1; end
                else begin if (t1) pc[7:0] <= rom_data; else pc <= pc + 1'b1; cycle_2 <= 0; end
            end
            8'hB6: begin // JF0 [cite: 45, 46]
                if (!cycle_2) begin pc <= pc + 1'b1; cycle_2 <= 1; end
                else begin if (psw[5]) pc[7:0] <= rom_data; else pc <= pc + 1'b1; cycle_2 <= 0; end
            end
            8'hC6: begin // JZ [cite: 53, 54]
                if (!cycle_2) begin 
                    pc <= pc + 1'b1;
                    cycle_2 <= 1; 
                end else begin 
                    if (acc == 8'h00) pc[7:0] <= rom_data;
                    else pc <= pc + 1'b1; 
                    cycle_2 <= 0; 
                end
            end
            8'h96: begin // JNZ [cite: 55, 56]
                if (!cycle_2) begin 
                    pc <= pc + 1'b1;
                    cycle_2 <= 1; 
                end else begin 
                    if (acc != 8'h00) pc[7:0] <= rom_data;
                    else pc <= pc + 1'b1; 
                    cycle_2 <= 0; 
                end
            end
            8'hF6: begin // JC [cite: 57, 58]
                if (!cycle_2) begin 
                    pc <= pc + 1'b1;
                    cycle_2 <= 1; 
                end else begin 
                    if (psw[7]) pc[7:0] <= rom_data; 
                    else pc <= pc + 1'b1;
                    cycle_2 <= 0; 
                end
            end
            8'hE6: begin // JNC [cite: 59, 60]
                if (!cycle_2) begin 
                    pc <= pc + 1'b1;
                    cycle_2 <= 1; 
                end else begin 
                    if (!psw[7]) pc[7:0] <= rom_data; 
                    else pc <= pc + 1'b1;
                    cycle_2 <= 0; 
                end
            end
            8'b11101???: begin // DJNZ Rn, address [cite: 109, 113]
                if (!cycle_2) begin
                    rmem_dat <= ram[rn_addr];
                    ram[rn_addr] <= ram[rn_addr] - 1'b1;
                    wmem_dat <= ram[rn_addr];
                    pc <= pc + 1'b1;
                    cycle_2 <= 1;
                end else begin
                    if (ram[rn_addr] != 8'h00) pc <= {pc[11:8], rom_data}; 
                    else pc <= pc + 1'b1;
                    cycle_2 <= 0;
                end
            end

            // --- Subroutine Control ---
            8'b???10100: begin // CALL [cite: 66, 74]
                if (!cycle_2) begin
                    psw[2:0] <= psw[2:0] + 1'b1;
                    pc <= pc + 1'b1;
                    next_pc <= pc + 2'b10;
                    cycle_2 <= 1'b1;
                end else begin
                    //ram[{(psw[2:0]), 1'b0} + 6'h08] <= (pc + 1'b1);
                    callmem1 <= {(psw[2:0]), 1'b0} + 6'h08;
                    wmem_dat <= next_pc[7:0];
                    callmem2 = {psw[2:0], 1'b1} + 6'h08;
                    wmem_dat2 <= {psw[7:4], next_pc[11:8]};
                    //ram[{psw[2:0], 1'b1} + 6'h08] <= {psw[7:4], (pc + 1'b1) >> 8};
                    ram[{(psw[2:0]), 1'b0} + 6'h08] <= next_pc[7:0];
                    ram[{psw[2:0], 1'b1} + 6'h08] <= {psw[7:4], next_pc[11:8]};
                    pc <= {mb_latch, ir[7:5], rom_data[7:0]};
                    #10 display_read_status(ir,wmem_dat,wmem_dat2,8'hXX,pc);
                    cycle_2 <= 1'b0;
                end
            end
            8'h83: begin // RET [cite: 75, 83]
                if (!cycle_2) begin
                    cycle_2 <= 1'b1;
                end else begin
                    pc[7:0] <= ram[{psw[2:0], 1'b0} + 6'h08];
                    retmem1 <= {psw[2:0], 1'b0} + 6'h08;
                    rmem_dat <= ram[{psw[2:0], 1'b0} + 6'h08];
                    pc[11:8] <= ram[{psw[2:0], 1'b1} + 6'h08][3:0];
                    retmem2 <= {psw[2:0], 1'b1} + 6'h08;
                    rmem_dat2 <= ram[{psw[2:0], 1'b1} + 6'h08][3:0];
                    psw[2:0] <= psw[2:0] - 1'b1;
                    #10 display_read_status(ir,rmem_dat,rmem_dat2,psw,pc);
                    cycle_2 <= 1'b0;
                end
            end
            8'h93: begin // RETR [cite: 84, 87]
                if (!cycle_2) begin
                    cycle_2 <= 1'b1;
                end else begin
                    //ram_preop <= ram[{psw[2:0], 1'b0} + 6'h08];
                    psw[2:0] <= psw[2:0] - 1'b1;
                    pc[7:0] <= ram[{psw[2:0], 1'b0} + 6'h08];
                    retmem1 <= {psw[2:0], 1'b0} + 6'h08;
                    rmem_dat <= ram[{psw[2:0], 1'b0} + 6'h08];
                    psw[7:4] <= ram[{psw[2:0], 1'b1} + 6'h08][7:4];
                    pc[11:8] <= ram[{psw[2:0], 1'b1} + 6'h08][3:0];
                    retmem2 <= {psw[2:0], 1'b1} + 6'h08;
                    rmem_dat2 <= ram[{psw[2:0], 1'b1} + 6'h08][3:0];
                    //psw[2:0] <= psw[2:0] - 1'b1;
                    #10 display_read_status(ir,rmem_dat,rmem_dat2,psw,pc);
                    //psw[2:0] <= psw[2:0] - 1'b1;
                    irq_in_progress <= 1'b0;
                    cycle_2 <= 1'b0;
                end
            end

            8'hA3: begin // MOVP A,@A — fetch from {current_page, acc} [cite: 88]
                // cycle_1: hold PC so pc[11:8] (page bits) remain valid for
                //          the mem_addr mux in cycle_2: {pc[11:8], acc}
                if (!cycle_2) begin
                    cycle_2 <= 1;
                // DO NOT increment PC here — page bits must stay intact
                end else begin
                    acc_preop <= acc;
                    acc <= rom_data;
                    #10 display_read_status(ir, acc_preop, rom_data, acc, {pc[11:8], acc});
                    pc <= pc + 1'b1;
                    cycle_2 <= 0;
                end
            end

            8'hE3: begin // MOVP3 A,@A — fetch from page 3: {4'b0011, acc} [cite: 91]
                // cycle_1: hold PC (consistent with MOVP; page is hardcoded to 3
                //          so pc[11:8] doesn't matter, but PC must not skip ahead)
                if (!cycle_2) begin
                    cycle_2 <= 1;
                    // DO NOT increment PC here
                end else begin
                    acc_preop <= acc;
                    acc <= rom_data;  // rom_data = ROM[{4'b0011, acc}] = ROM[0x300+acc]
                    #10 display_read_status(ir, acc_preop, rom_data, acc, {4'b0011, acc});
                    pc <= pc + 1'b1;
                    cycle_2 <= 0;
                end
            end

            // --- Ports & Flags ---
            8'h05: begin irq_en_ext <= 1; pc <= pc + 1'b1; end // EN I [cite: 29]

            8'h02: begin // OUTL BUS, A
                      bus_preop <= bus_out;
                      bus_out <= acc;  // Latch Accumulator to the BUS output register
                      pc <= pc + 1'b1;
                     #10 display_read_status(ir,bus_preop,acc,bus_out,12'hXXX);
                   end
            8'h3A: begin //OUTL P1,A 
                     bus_preop <= p1;
                     p1 <= acc;
                     pc <= pc + 1'b1;
                     #10 display_read_status(ir,bus_preop,acc,p1,12'hXXX);
                   end // [cite: 28]
            8'h3B: begin //OUTL P2,A 
                     bus_preop <= p2;
                     p2 <= acc;
                     pc <= pc + 1'b1;
                     #10 display_read_status(ir,bus_preop,acc,p2,12'hXXX);
                   end // [cite: 28]
            8'h15: begin irq_en_ext <= 1'b0; pc <= pc + 1'b1; end // [cite: 30, 31]
            8'h25: begin irq_en_timer <= 1'b1; pc <= pc + 1'b1; end // [cite: 124, 125]
            8'h85: begin psw[5] <= 1'b0; pc <= pc + 1'b1; end //CPL F0 [cite: 153, 154]
            8'h89: begin // ORL P1, #data [cite: 100, 101]
                     if (!cycle_2)
                     begin
                       pc <= pc + 1'b1;
                       bus_preop<=p1;
                       cycle_2 <= 1;
                     end
                     else
                     begin
                       p1 <= p1 | rom_data;
                       cycle_2 <= 0;
                       #10 display_read_status(ir,bus_preop,rom_data,p1,pc);
                       pc <= pc + 1'b1;
                     end
            end
            8'h8A: begin // ORL P2, #data [cite: 100, 101]
                     if (!cycle_2)
                     begin
                       pc <= pc + 1'b1;
                       bus_preop<=p2;
                       cycle_2 <= 1;
                     end
                     else
                     begin
                       p2 <= p2 | rom_data;
                       cycle_2 <= 0;
                       #10 display_read_status(ir,bus_preop,rom_data,p2,pc);
                       pc <= pc + 1'b1;
                     end
            end
            8'h95: begin psw[5] <= ~psw[5]; pc <= pc + 1'b1; end // CPL F0 [cite: 157, 158]
            8'h97: begin psw[7] <= 1'b0; pc <= pc + 1'b1; end // CLR C [cite: 145, 146]
            8'h99: begin // ANL P1, #data [cite: 98, 99]
                     if (!cycle_2)
                     begin
                       pc <= pc + 1'b1;
                       bus_preop<=p1;
                       cycle_2 <= 1;
                     end
                     else
                       begin
                         p1 <= p1 & rom_data;
                         cycle_2 <= 0;
                         #10 display_read_status(ir,bus_preop,rom_data,p1,pc);
                         pc <= pc + 1'b1;
                       end
                   end
            8'h9A: begin // ANL P2, #data [cite: 102, 103]
                     if (!cycle_2)
                     begin
                       pc <= pc + 1'b1;
                       bus_preop<=p2;
                       cycle_2 <= 1;
                     end
                     else
                     begin
                       p2 <= p2 & rom_data;
                       cycle_2 <= 0;
                       #10 display_read_status(ir,bus_preop,rom_data,p2,pc);
                       pc <= pc + 1'b1;
                     end
                   end
            8'hA7: begin psw[7] <= ~psw[7]; pc <= pc + 1'b1; end // [cite: 155, 156]
            8'hB5: begin f1 <= ~f1; pc <= pc + 1'b1; end //CPL F1 [cite: 151, 152]
            8'hA5: begin f1 <= 1'b0; pc <= pc + 1'b1; end //CLR F1 [cite: 151, 152]

            // --- Timer Control ---
            8'h45: begin // STRT CNT (Start CNT)
                     timer_running <= 1'b1;
                     timer_en   <= 1'b1;
                     timer_mode <= 1'b1; // 1 = External Counter mode (T1 pin)
                     pc <= pc + 1'b1;
                   end
    
            8'h55: begin // STRT T (Start Timer)
                     timer_running <= 1'b1;
                     timer_en   <= 1'b1;
                     timer_mode <= 1'b0; // 0 = Internal Timer mode 
                     pc <= pc + 1'b1;
                   end
    
            8'h65: begin // STOP TCNT
                     timer_running <= 1'b0;        timer_en   <= 1'b0;
                     pc <= pc + 1'b1;
                   end


            // --- Status Selection ---
            8'hE5: begin mb_latch <= 1'b0; pc <= pc + 1'b1; end // SEL MB0 [cite: 174, 175]
            8'hF5: begin mb_latch <= 1'b1; pc <= pc + 1'b1; end // SEL MB1[cite: 172, 173]
            8'hC5: begin psw[4] <= 1'b0;; pc <= pc + 1'b1; end // SEL RB0 [cite: 176, 177]
            8'hD5: begin psw[4] <= 1'b1; pc <= pc + 1'b1; end // SEL RB1 [cite: 178, 179]

            8'h57: begin // DA A (Decimal Adjust Accumulator)
                acc_preop <= acc;
                if ((acc[3:0] > 9) || psw[6]) begin
                        {psw[7], acc} <= acc + 6;
                end
                    
                if ((acc[7:4] > 9) || psw[7]) begin
                        acc <= acc + 8'h60;
                        psw[7] <= 1'b1; // Set Carry flag
                end
                   #10 display_read_status(ir,acc_preop,8'hXX,acc,pc);
                    
                    pc <= pc + 1'b1;
                end
            // -----------------------------------------------------------------
            // INS A, BUS  [0x08]
            //   Read the external BUS port into the accumulator.
            //   The BUS is latched via the bus_in port; rd_n is asserted by the
            //   timing engine (state machine) when ir==0x08, matching what is
            //   already done for MOVX A,@Ri (0x80/81). Single-cycle.
            // -----------------------------------------------------------------
            8'h08: begin // INS A, BUS
                acc_preop <= acc;
                acc       <= bus_in;
                #10 display_read_status(ir, acc_preop, bus_in, acc, 12'hACC);
                pc <= pc + 1'b1;
            end

            // -----------------------------------------------------------------
            // IN A, P1  [0x09]
            //   Read Port 1 into the accumulator. Single-cycle.
            // -----------------------------------------------------------------
            8'h09: begin // IN A, P1
                acc_preop <= acc;
                acc       <= p1;
                #10 display_read_status(ir, acc_preop, p1, acc, 12'hACC);
                pc <= pc + 1'b1;
            end

            // -----------------------------------------------------------------
            // IN A, P2  [0x0A]
            //   Read Port 2 into the accumulator. Single-cycle.
            // -----------------------------------------------------------------
            8'h0A: begin // IN A, P2
                acc_preop <= acc;
                acc       <= p2;
                #10 display_read_status(ir, acc_preop, p2, acc, 12'hACC);
                pc <= pc + 1'b1;
            end

            // -----------------------------------------------------------------
            // ADDC A, #data  [0x13]
            //   Add immediate byte + carry to accumulator. Two-cycle (fetches
            //   immediate operand on second cycle from rom_data).
            //   Carry (psw[7]) and Aux Carry (psw[6]) are updated.
            //   NOTE: add this opcode to the is_2_cycle wire expression too:
            //     (ir == 8'h13)  ||
            // -----------------------------------------------------------------
            8'h13: begin // ADDC A, #data
                if (!cycle_2) begin
                    pc      <= pc + 1'b1;
                    cycle_2 <= 1'b1;
                    acc_preop <= acc;
                end else begin
                    {psw[7], acc} <= {1'b0, acc} + {1'b0, rom_data} + {8'b0, psw[7]};
                    psw[6]  <= (acc[3:0] + rom_data[3:0] + psw[7] > 4'hF);
                    #10 display_read_status(ir, acc_preop, rom_data, acc, pc);
                    pc      <= pc + 1'b1;
                    cycle_2 <= 1'b0;
                end
            end

            // -----------------------------------------------------------------
            // ORL A, @Ri  [0x40 = @R0,  0x41 = @R1]
            //   OR accumulator with byte at indirect RAM address. Single-cycle.
            // -----------------------------------------------------------------
            8'b0100000?: begin // ORL A, @Ri  (0x40/@R0, 0x41/@R1)
                acc_preop <= acc;
                acc       <= acc | ram[ptr_addr];
                rmem_dat  <= ram[ptr_addr];
                #10 display_read_status(ir, acc_preop, rmem_dat, acc, ptr_addr);
                pc <= pc + 1'b1;
            end

            // -----------------------------------------------------------------
            // ORL A, Rn  [0x48..0x4F]
            //   OR accumulator with register Rn (R0..R7). Single-cycle.
            //   Pattern 8'b0100_1??? covers 0x48-0x4F.
            //   NOTE: pattern 8'b01001??? does NOT overlap 8'b0100000?
            //   because bit 3 differs (1 vs 0). Verilog casez will
            //   match the more-specific 8'b0100000? first for 0x40/0x41.
            // -----------------------------------------------------------------
            8'b01001???: begin // ORL A, Rn  (0x48..0x4F)
                acc_preop <= acc;
                acc       <= acc | ram[rn_addr];
                rmem_dat  <= ram[rn_addr];
                #10 display_read_status(ir, acc_preop, rmem_dat, acc, rn_addr);
                pc <= pc + 1'b1;
            end

            // -----------------------------------------------------------------
            // ANL A, @Ri  [0x50 = @R0,  0x51 = @R1]
            //   AND accumulator with byte at indirect RAM address. Single-cycle.
            // -----------------------------------------------------------------
            8'b0101000?: begin // ANL A, @Ri  (0x50/@R0, 0x51/@R1)
                acc_preop <= acc;
                acc       <= acc & ram[ptr_addr];
                rmem_dat  <= ram[ptr_addr];
                #10 display_read_status(ir, acc_preop, rmem_dat, acc, ptr_addr);
                pc <= pc + 1'b1;
            end

            // -----------------------------------------------------------------
            // ANL A, Rn  [0x58..0x5F]
            //   AND accumulator with register Rn (R0..R7). Single-cycle.
            //   Pattern 8'b0101_1??? covers 0x58-0x5F.
            // -----------------------------------------------------------------
            8'b01011???: begin // ANL A, Rn  (0x58..0x5F)
                acc_preop <= acc;
                acc       <= acc & ram[rn_addr];
                rmem_dat  <= ram[rn_addr];
                #10 display_read_status(ir, acc_preop, rmem_dat, acc, rn_addr);
                pc <= pc + 1'b1;
            end

            // -----------------------------------------------------------------
            // ADD A, Rn  [0x68..0x6F]
            //   Add register Rn to accumulator. Single-cycle.
            //   Carry (psw[7]) and Aux Carry (psw[6]) are updated.
            //   NOTE: 0x60/0x61 (ADD A,@Ri) are already in the file as
            //   8'b0110000? - that pattern covers 0x60/0x61 only (bit3=0).
            //   This pattern 8'b0110_1??? covers 0x68-0x6F (bit3=1).
            //   The two patterns are mutually exclusive.
            // -----------------------------------------------------------------
            8'b01101???: begin // ADD A, Rn  (0x68..0x6F)
                acc_preop <= acc;
                {psw[7], acc} <= {1'b0, acc} + {1'b0, ram[rn_addr]};
                psw[6]    <= (acc[3:0] + ram[rn_addr][3:0] > 4'hF);
                rmem_dat  <= ram[rn_addr];
                #10 display_read_status(ir, acc_preop, rmem_dat, acc, rn_addr);
                pc <= pc + 1'b1;
            end

            // -----------------------------------------------------------------
            // ADDC A, Rn  [0x78..0x7F]
            //   Add register Rn + carry to accumulator. Single-cycle.
            //   Carry (psw[7]) and Aux Carry (psw[6]) are updated.
            //   NOTE: The corrected ADDC A,@Ri (0x70/0x71) uses pattern
            //   8'b0111000? (bit3=0). This pattern 8'b0111_1??? (bit3=1)
            //   covers 0x78-0x7F. Mutually exclusive.
            // -----------------------------------------------------------------
            8'b01111???: begin // ADDC A, Rn  (0x78..0x7F)
                acc_preop <= acc;
                {psw[7], acc} <= {1'b0, acc} + {1'b0, ram[rn_addr]} + {8'b0, psw[7]};
                psw[6]    <= (acc[3:0] + ram[rn_addr][3:0] + psw[7] > 4'hF);
                rmem_dat  <= ram[rn_addr];
                #10 display_read_status(ir, acc_preop, rmem_dat, acc, rn_addr);
                pc <= pc + 1'b1;
            end

            // -----------------------------------------------------------------
            // NOP  [0x00]
            //   No operation. Advances PC only. Single-cycle.
            // -----------------------------------------------------------------
            8'h00: begin // NOP
                pc <= pc + 1'b1;
            end

            default: begin
                $display("ERROR: Unimplemented Opcode %h at PC %h", ir, pc); //[cite: 180]
            end
        endcase
    end
endtask


reg machine_cycle_pulse;


// Detect falling edge on the T1 pin for Counter Mode
reg t1_delayed;
always @(posedge clk)
   begin
     t1_delayed <= t1;
//     t1_falling_edge <= (t1_delayed && !t1);
   end;
wire t1_falling_edge = (t1_delayed && !t1);

always @(posedge clk) begin
    if (!res_n) begin
        timer_flag = 1'b0;
        timer_en = 1'b0;
        timer_running = 1'b0;
    end
    else
      if (timer_running) 
        begin
          //$display("timer running");
          if (timer_mode == 1'b0)
              // --- TIMER MODE ---
          begin
             if (machine_cycle_pulse) 
               begin
                 if (prescaler == 5'd31)
                  begin
                      prescaler <= 0;
                      {timer_flag, timer_val} <= timer_val + 1'b1;
                  end
                  else  prescaler <= prescaler + 1'b1;
               end
          end
          else
          begin
              //$display("else counter edge %h",t1_falling_edge);
              // --- COUNTER MODE ---
              if (t1_falling_edge)
                 begin
                   $display("counter edge");
                   if (timer_val == 8'hFF)
                   begin
                     $display("counter roll");
                     timer_val  <= 8'h00;
                     timer_flag <= 1'b1; // Flag sets and "sticks"
                   end
                   else
                     begin
                       timer_val  <= timer_val + 1'b1;
                       $display("count updated");
                     end
                 end
          end
        end
end



always @(posedge clk) begin
    if (!res_n)
        machine_cycle_pulse <= 0;
    else
        // If the next state is 0, it means we are finishing an instruction 
        // and will fetch a new opcode on the next rising edge.
        machine_cycle_pulse <= (next_cycle_state == 0);
end

// Create a physical address wire for the ROM
// We use the lower 11 bits of the PC, and P2[3] acts as the 12th bit (A11)
wire [11:0] rom_addr_phys = {p2[3], pc[10:0]};

endmodule
