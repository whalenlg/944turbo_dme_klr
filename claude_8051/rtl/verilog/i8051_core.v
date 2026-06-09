// ============================================================
//  CPU_DEBUG: define to enable verbose trace output.
//  Comment out (or leave undefined) for silent simulation.
//
//  Controlled displays:
//    [BIT_READ ]  [BIT_WRITE]  [SFR_WRITE]  [DIR_WRITE]  [EXEC]
//
//  Usage:
//    With tracing:   iverilog -DCPU_DEBUG ...
//    Without:        iverilog ...            (default — silent)
// `define CPU_DEBUG
// ============================================================
//  Intel 8051 Cycle-Accurate Verilog Model
//  Follows the structural style of i8048_core.v
//
//  Key differences vs 8048:
//   - 16-bit PC (64 KB program space)
//   - 128-byte internal RAM + full SFR block
//   - 4 register banks (R0-R7 each), selected by PSW[4:3]
//   - Hardware stack (SP register, grows up through iram)
//   - 16-bit DPTR
//   - 4 I/O ports (P0-P3)
//   - 2 timers with 4 modes each
//   - 5 interrupt sources
//   - MUL AB / DIV AB instructions
//   - Full CJNE / DJNZ / SJMP / LJMP / AJMP / LCALL / ACALL
//   - MOVX (external data) and MOVC (program ROM constant table)
//   - Bit-addressable RAM (0x20-0x2F) and SFRs
//   - 12-oscillator-clock machine cycle (prescaler included)
// ============================================================

module i8051_core (
    input  wire        clk,         // Oscillator (12 clocks per machine cycle)
    input  wire        res_n,       // Active-low reset
    input  wire        int0_n,      // /INT0  external interrupt 0
    input  wire        int1_n,      // /INT1  external interrupt 1
    input  wire        t0,          // T0 timer/counter external input
    input  wire        t1,          // T1 timer/counter external input
    input  wire        rxd,         // UART receive data
    input  wire [7:0]  rom_data,    // Program memory data (latched on falling /PSEN)
    input  wire [7:0]  xdata_in,    // External data RAM read bus
    output reg  [15:0] pc,          // Program Counter
    output reg  [7:0]  ir,          // Instruction Register
    output wire [15:0] addr_bus,    // Multiplexed program address (ROM or MOVC)
    output reg  [15:0] xaddr_bus,   // External data address (MOVX)
    output reg  [7:0]  xdata_out,   // External data write bus
    output reg         xrd_n,       // /RD   external data read strobe
    output reg         xwr_n,       // /WR   external data write strobe
    input  wire [7:0]  p0_in,        // Port 0 external input
    output reg  [7:0]  p0,          // Port 0 output latch
    input  wire [7:0]  p1_in,        // Port 1 external input (driven from outside)
    output reg  [7:0]  p1,          // Port 1 output latch
    input  wire [7:0]  p2_in,        // Port 2 external input
    output reg  [7:0]  p2,          // Port 2 output latch
    input  wire [7:0]  p3_in,        // Port 3 external input
    output reg  [7:0]  p3,          // Port 3 output latch
    output reg         ale,         // Address Latch Enable
    output reg         psen_n,      // /PSEN program store enable
    output reg         txd          // UART transmit data
);

    // ----------------------------------------------------------------
    //  Internal RAM  (0x00-0x7F only; upper half is indirect-only
    //  on the real 8051 / 8052, but for simplicity we use 128 bytes)
    // ----------------------------------------------------------------
    reg [7:0] iram [0:127];

    // ----------------------------------------------------------------
    //  Special Function Registers
    // ----------------------------------------------------------------
    reg [7:0]  acc;        // E0h  Accumulator
    reg [7:0]  b_reg;      // F0h  B register
    reg [7:0]  psw;        // D0h  Program Status Word
    reg [7:0]  sp;         // 81h  Stack Pointer  (reset → 0x07)
    reg [7:0]  dpl;        // 82h  DPTR low
    reg [7:0]  dph;        // 83h  DPTR high
    reg [7:0]  ie;         // A8h  Interrupt Enable
    reg [7:0]  ip;         // B8h  Interrupt Priority
    reg [7:0]  tcon;       // 88h  Timer Control
    reg [7:0]  tmod;       // 89h  Timer Mode
    reg [7:0]  tl0;        // 8Ah  Timer 0 low
    reg [7:0]  th0;        // 8Ch  Timer 0 high
    reg [7:0]  tl1;        // 8Bh  Timer 1 low
    reg [7:0]  th1;        // 8Dh  Timer 1 high
    reg [7:0]  scon;       // 98h  Serial Control
    reg [7:0]  sbuf_tx;    // 99h  Serial TX buffer
    reg        sbuf_wr;    // pulse: set by sfr_write(0x99), cleared by TX engine
    reg [7:0]  sbuf_rx;    // 99h  Serial RX buffer (read-only path)
    reg [7:0]  pcon;       // 87h  Power Control

    // ----------------------------------------------------------------
    //  PSW bit aliases
    //  [7]=CY  [6]=AC  [5]=F0  [4]=RS1  [3]=RS0  [2]=OV  [1]=UD  [0]=P
    // ----------------------------------------------------------------

    // ----------------------------------------------------------------
    //  Register-bank base (PSW[4:3] = RS1:RS0)
    //  Bank 0 → 0x00, Bank 1 → 0x08, Bank 2 → 0x10, Bank 3 → 0x18
    // ----------------------------------------------------------------
    wire [6:0] rb_base  = {2'b00, psw[4], psw[3], 3'b000};
    wire [6:0] rn_addr  = rb_base | {4'b0000, ir[2:0]};  // Rn in iram
    wire [6:0] ri_base  = rb_base | {6'b000000, ir[0]};  // R0 or R1
    wire [7:0] ri_ptr   = iram[ri_base];                  // @Ri pointer value

    // ----------------------------------------------------------------
    //  DPTR
    // ----------------------------------------------------------------
    wire [15:0] dptr = {dph, dpl};

    // ----------------------------------------------------------------
    //  Parity (auto-reflects acc)
    // ----------------------------------------------------------------
    wire parity = ^acc;

    // ----------------------------------------------------------------
    //  Cycle tracking
    //  cycle_2 : we are in the second machine cycle of a multi-cycle instr
    // ----------------------------------------------------------------
    reg  cycle_2;

    // ----------------------------------------------------------------
    //  Program address mux
    //  During cycle_2 of MOVC instructions, point ROM bus at table entry
    // ----------------------------------------------------------------
    assign addr_bus = (ir == 8'h83 && cycle_2) ? (pc + {8'h00, acc}) :
                      (ir == 8'h93 && cycle_2) ? (dptr + {8'h00, acc}) :
                       pc;

    // ----------------------------------------------------------------
    //  Internal state machine
    // ----------------------------------------------------------------
    reg [3:0] osc_cnt;    // 0-11: S1P1 through S6P2 (12 oscillator clocks)
    reg [63:0] cycle_count; // free-running clock cycle counter for profiling

    // ----------------------------------------------------------------
    //  Interrupt bookkeeping
    // ----------------------------------------------------------------
    reg irq_in_progress;
    reg irq_hi_active;     // 1 = currently servicing a high-priority ISR
    reg irq_pending_hi;    // 1 = latched pending interrupt is high-priority
    // Shadow flags: set via blocking assignment inside sfr_write so the
    // arbiter can see TF0/TF1 in the same execute phase that sets them.
    reg        irq_pending;   // interrupt latched, waiting for instruction boundary
    reg [15:0] irq_vector;    // vector address for pending interrupt
    // ── tcon write requests (timer block is sole owner of tcon) ──
    reg        tcon_clr_tf0_req;  // clear TF0 (tcon[5])
    reg        tcon_clr_tf1_req;  // clear TF1 (tcon[7])
    reg        tcon_clr_ie0_req;  // clear IE0 (tcon[1])
    reg        tcon_clr_ie1_req;  // clear IE1 (tcon[3])
    reg        tcon_wr_req;       // full-byte MOV to TCON pending
    reg [7:0]  tcon_wr_val;       // value for full-byte write
    // ── scon set requests (execute block is sole owner of scon) ──
    reg        scon_set_ti_req;   // UART TX done → set TI (scon[1])
    reg        scon_set_ri_req;   // UART RX done → set RI (scon[0])
    reg        scon_set_rb8_req;  // set RB8 (scon[2])
    reg        scon_rb8_val;      // value for RB8

    // ----------------------------------------------------------------
    //  Operand / debug temporaries
    // ----------------------------------------------------------------
    reg [7:0]  tmp1, tmp2, tmp3;
    reg [7:0]  acc_preop;
    reg [7:0]  ram_preop;
    reg [7:0]  dir_addr_latch;

    // ROM data latch -- captures rom_data when /PSEN rises so execute
    // never sees a floating bus. Latched at osc_cnt==4 (opcode) and
    // osc_cnt==10 (operand/second byte).
    reg [7:0]  rom_data_latch;

    // ----------------------------------------------------------------
    //  Opcode mnemonic table (for simulation display)
    // ----------------------------------------------------------------
    reg [255:0] opinstr [0:255];
    initial
        $readmemh("op_ins8051.hex", opinstr, 0, 255);

    // ----------------------------------------------------------------
    //  Debug display task  (same interface as 8048 version)
    // ----------------------------------------------------------------

    // ----------------------------------------------------------------
    //  SFR read helper
    // ----------------------------------------------------------------
    function [7:0] sfr_read;
        input [7:0] addr;
        begin
            case (addr)
                8'h80: sfr_read = p0 & p0_in;
                8'h81: sfr_read = sp;
                8'h82: sfr_read = dpl;
                8'h83: sfr_read = dph;
                8'h87: sfr_read = pcon;
                8'h88: sfr_read = tcon | {t1_overflow_now, 1'b0,
                                           t0_overflow_now, 3'b0,
                                           1'b0, 1'b0};
                8'h89: sfr_read = tmod;
                8'h8A: sfr_read = tl0;
                8'h8B: sfr_read = tl1;
                8'h8C: sfr_read = th0;
                8'h8D: sfr_read = th1;
                8'h90: sfr_read = p1 & p1_in;  // quasi-bidirectional: latch & external
                8'h98: sfr_read = scon;
                8'h99: sfr_read = sbuf_rx;
                8'hA0: sfr_read = p2 & p2_in;
                8'hA8: sfr_read = ie;
                // P3 read returns actual pin states for input-function bits.
                // Use registered (synchronised) versions of async inputs to
                // avoid reading a transitioning value at the clock edge.
                //  [0]=RXD      [1]=TXD(latch)  [2]=/INT0  [3]=/INT1
                //  [4]=T0       [5]=T1           [6]=p3[6]  [7]=p3[7]
                8'hB0: sfr_read = { p3[7], p3[6], t1_dly, t0_dly,
                                    int1_dly, int0_dly, txd, rxd_sync1 };
                8'hB8: sfr_read = ip;
                8'hD0: sfr_read = psw;
                8'hE0: sfr_read = acc;
                8'hF0: sfr_read = b_reg;
                default: sfr_read = 8'hFF;
            endcase
        end
    endfunction

    // ----------------------------------------------------------------
    //  Direct-space read  (addr<0x80 → iram,  addr>=0x80 → SFR)
    // ----------------------------------------------------------------
    function [7:0] direct_read;
        input [7:0] addr;
        begin
            if (!addr[7])
                direct_read = iram[addr[6:0]];
            else
                direct_read = sfr_read(addr);
        end
    endfunction

    // ----------------------------------------------------------------
    //  SFR latch read — same as sfr_read but returns the OUTPUT LATCH
    //  for port registers (P0/P1/P2/P3) without ANDing with p_in.
    //  Used by bit_write for read-modify-write so external pin values
    //  are not captured into the output latch.
    // ----------------------------------------------------------------
    function [7:0] sfr_read_latch;
        input [7:0] addr;
        reg   [7:0] sfr_read_latch_ret;
        begin
            case (addr)
                8'h80: sfr_read_latch_ret = p0;        // P0 latch (not &p0_in)
                8'h81: sfr_read_latch_ret = sp;
                8'h82: sfr_read_latch_ret = dpl;
                8'h83: sfr_read_latch_ret = dph;
                8'h87: sfr_read_latch_ret = pcon;
                // TCON: OR in TF0/TF1 if timer overflows this same clock edge.
                // t0_overflow_now / t1_overflow_now are combinatorial — no race.
                8'h88: sfr_read_latch_ret = tcon | {t1_overflow_now, 1'b0,
                                                     t0_overflow_now, 3'b0,
                                                     1'b0, 1'b0};
                8'h89: sfr_read_latch_ret = tmod;
                8'h8A: sfr_read_latch_ret = tl0;
                8'h8B: sfr_read_latch_ret = tl1;
                8'h8C: sfr_read_latch_ret = th0;
                8'h8D: sfr_read_latch_ret = th1;
                8'h90: sfr_read_latch_ret = p1;        // P1 latch (not &p1_in)
                8'h98: sfr_read_latch_ret = scon;
                8'h99: sfr_read_latch_ret = sbuf_rx;
                8'hA0: sfr_read_latch_ret = p2;        // P2 latch (not &p2_in)
                8'hA8: sfr_read_latch_ret = ie;
                8'hB0: sfr_read_latch_ret = p3;        // P3 latch (not &p3_in)
                8'hB8: sfr_read_latch_ret = ip;
                8'hD0: sfr_read_latch_ret = psw;
                8'hE0: sfr_read_latch_ret = acc;
                8'hF0: sfr_read_latch_ret = b_reg;
                default: sfr_read_latch_ret = 8'hFF;
            endcase
            sfr_read_latch = sfr_read_latch_ret;
        end
    endfunction

    // ----------------------------------------------------------------
    //  Bit read
    //  bit_addr 0x00-0x7F → iram[0x20 + bit_addr/8]  bit (bit_addr%8)
    //  bit_addr 0x80-0xFF → SFR at (bit_addr & F8h)  bit (bit_addr&7)
    // ----------------------------------------------------------------
    function bit_read;
        input [7:0] bit_addr;
        reg   [7:0] bval;
        begin
            if (!bit_addr[7])
                bval = iram[7'h20 + {1'b0, bit_addr[6:3]}];
            else
                bval = sfr_read({bit_addr[7:3], 3'b000});
            bit_read = bval[bit_addr[2:0]];
`ifdef CPU_DEEP_DEBUG
            $display("DME: [BIT_READ ] bit_addr=%02Xh  byte=%02Xh  bit=%0b",
                     bit_addr, bval, bval[bit_addr[2:0]]);
`endif
        end
    endfunction

    // ----------------------------------------------------------------
    //  Bit write
    //  bit_addr 0x00-0x7F → iram[0x20 + bit_addr/8]  bit (bit_addr%8)
    //  bit_addr 0x80-0xFF → SFR at (bit_addr & F8h)  bit (bit_addr&7)
    //  val: 0=CLR, 1=SET, 2=CPL, 3=MOV(psw[7])
    // ----------------------------------------------------------------
    task bit_write;
        input [7:0] bit_addr;
        input [1:0] op;       // 0=CLR 1=SET 2=CPL 3=MOV_C
        reg   [7:0] old_byte, new_byte;
        reg         old_bit,  new_bit;
        begin
            // Read current byte — use latch (not pin) for SFR RMW
            // so external inputs on P0/P1/P2/P3 are not captured
            if (!bit_addr[7])
                old_byte = iram[7'h20 + {1'b0, bit_addr[6:3]}];
            else
                old_byte = sfr_read_latch({bit_addr[7:3], 3'b000});
            old_bit = old_byte[bit_addr[2:0]];
            // Compute new bit value
            case (op)
                2'd0: new_bit = 1'b0;           // CLR
                2'd1: new_bit = 1'b1;           // SET
                2'd2: new_bit = ~old_bit;        // CPL
                2'd3: new_bit = psw[7];          // MOV C
            endcase
            new_byte = (old_byte & ~(8'h01 << bit_addr[2:0]))
                     | ({7'b0, new_bit} << bit_addr[2:0]);
            // Write
            if (!bit_addr[7])
                iram[7'h20 + {1'b0, bit_addr[6:3]}] <= new_byte;
            else
                sfr_write({bit_addr[7:3], 3'b000}, new_byte);
            // Trace
`ifdef CPU_DEEP_DEBUG
            $display("DME: [BIT_WRITE] bit_addr=%02Xh  op=%s  old=%0b  new=%0b  (PC=%04Xh  IR=%02Xh)",
                     bit_addr,
                     (op==0) ? "CLR" : (op==1) ? "SET" : (op==2) ? "CPL" : "MOV",
                     old_bit, new_bit, pc, ir);
`endif
        end
    endtask


    // ----------------------------------------------------------------
    task sfr_write;
        input [7:0] addr;
        input [7:0] val;
        begin
`ifdef CPU_DEEP_DEBUG
            $display("DME: [SFR_WRITE] addr=%02Xh  val=%02Xh  (PC=%04Xh  IR=%02Xh)",
                     addr, val, pc, ir);
`endif
            case (addr)
                8'h80: p0      <= val;
                8'h81: sp      <= val;
                8'h82: dpl     <= val;
                8'h83: dph     <= val;
                8'h87: pcon    <= val;
                8'h88: begin
                    // tcon is owned by the timer block; request the write there.
                    // TF preservation on same-cycle overflow handled in timer block.
                    tcon_wr_val <= val;
                    tcon_wr_req <= 1'b1;
                end
                8'h89: tmod    <= val;
                8'h8A: tl0     <= val;
                8'h8B: tl1     <= val;
                8'h8C: th0     <= val;
                8'h8D: th1     <= val;
                8'h90: p1      <= val;
                8'h98: scon    <= val;
                8'h99: begin sbuf_tx <= val; sbuf_wr <= 1'b1; end
                8'hA0: p2      <= val;
                8'hA8: ie      <= val;
                8'hB0: p3      <= val;
                8'hB8: ip      <= val;
                8'hD0: psw     <= val;
                8'hE0: acc     <= val;
                8'hF0: b_reg   <= val;
                default: begin `ifdef CPU_DEEP_DEBUG $display("DME: [SFR_WRITE] *** undefined SFR addr=%02Xh ignored ***", addr); `endif end
            endcase
        end
    endtask

    // ----------------------------------------------------------------
    //  Direct-space write
    // ----------------------------------------------------------------
    task direct_write;
        input [7:0] addr;
        input [7:0] val;
        begin
            if (!addr[7]) begin
`ifdef CPU_DEEP_DEBUG
                $display("DME: [DIR_WRITE] iram[%02Xh] <= %02Xh  (PC=%04Xh  IR=%02Xh)",
                         addr, val, pc, ir);
`endif
                iram[addr[6:0]] <= val;
            end else
                sfr_write(addr, val);   // SFR write prints its own trace
        end
    endtask

    // ----------------------------------------------------------------
    //  Stack note: push/pop are done inline in each instruction.
    //  The 8051 stack grows upward through iram[]. SP points at
    //  the last written byte. For a 2-byte push all RHS expressions
    //  are evaluated against the *old* SP (nonblocking semantics).
    // ----------------------------------------------------------------
    //  Interrupt service
    // ----------------------------------------------------------------
    task service_interrupt;
        input [15:0] vector;
        input [15:0] ret_addr;
        begin
`ifdef CPU_DEBUG
            $display("DME: [IRQ      ] vector=%04Xh  ret_addr=%04Xh  SP=%02Xh  (PC=%04Xh  IR=%02Xh)",
                     vector, ret_addr, sp, pc, ir);
`endif
            irq_in_progress <= 1'b1;
            // Push ret_addr: low byte at SP+1, high byte at SP+2.
            // All RHS expressions evaluate against old SP (NB semantics).
            iram[(sp + 8'h01) & 8'h7F] <= ret_addr[7:0];
            iram[(sp + 8'h02) & 8'h7F] <= ret_addr[15:8];
            sp <= sp + 8'h02;
            pc <= vector;
        end
    endtask

    // ----------------------------------------------------------------
    //  T0 / T1 falling-edge detector (counter mode)
    // ----------------------------------------------------------------
    reg t0_dly, t1_dly;
    wire t0_fall = (t0_dly && !t0);
    wire t1_fall = (t1_dly && !t1);
    always @(posedge clk) begin
        t0_dly <= t0;
        t1_dly <= t1;
    end

    // ----------------------------------------------------------------
    //  INT0 / INT1 falling-edge detectors
    //  IE0 (TCON[1]) and IE1 (TCON[3]) are set here; cleared by the
    //  interrupt arbiter when the interrupt is acknowledged.
    // ----------------------------------------------------------------
    reg int0_dly, int1_dly;
    wire int0_fall = (int0_dly && !int0_n);
    wire int1_fall = (int1_dly && !int1_n);

    // ----------------------------------------------------------------
    //  Timer 0 / Timer 1
    //  tcon[5]=TF0  tcon[4]=TR0  tcon[7]=TF1  tcon[6]=TR1
    //  tmod[1:0]=T0 mode  tmod[2]=T0 C/T  tmod[3]=T0 GATE
    //  tmod[5:4]=T1 mode  tmod[6]=T1 C/T  tmod[7]=T1 GATE
    //  Timers tick once per machine cycle (machine_cycle_pulse).
    //  TF0/TF1 are set-only here; cleared by interrupt service or software.
    // ----------------------------------------------------------------
    reg machine_cycle_pulse;

    // Combinatorial overflow detect — race-free alternative to blocking shadows.
    // These wires are HIGH on the exact clock edge when the timer overflows,
    // computed from registered state (before NBA updates) so they are visible
    // to sfr_read_latch in the same clock cycle without any inter-block race.
    // Used in sfr_read_latch to preserve TF0/TF1 during a same-cycle TCON RMW.
    wire t0_overflow_now = machine_cycle_pulse && tcon[4] &&   // TR0 running
         ((tmod[1:0] == 2'b00 && {th0, tl0[4:0]} == 13'h1FFF) ||  // mode 0
          (tmod[1:0] == 2'b01 && {th0, tl0}      == 16'hFFFF) ||  // mode 1
          (tmod[1:0] == 2'b10 && tl0              ==  8'hFF)  ||  // mode 2
          (tmod[1:0] == 2'b11 && tl0              ==  8'hFF));     // mode 3

    wire t1_overflow_now = machine_cycle_pulse && tcon[6] &&   // TR1 running
         ((tmod[5:4] == 2'b00 && {th1, tl1[4:0]} == 13'h1FFF) ||  // mode 0
          (tmod[5:4] == 2'b01 && {th1, tl1}      == 16'hFFFF) ||  // mode 1
          (tmod[5:4] == 2'b10 && tl1              ==  8'hFF));     // mode 2
                                                                    // mode 3: T1 halted

    always @(posedge clk) begin
        if (!res_n) begin
            tcon     <= 8'h00;  tmod <= 8'h00;
            tl0      <= 8'h00;  th0  <= 8'h00;
            tl1      <= 8'h00;  th1  <= 8'h00;
            int0_dly <= 1'b1;
            int1_dly <= 1'b1;
        end else begin
            // ---- Apply pending tcon writes from the execute block ----
            // Full-byte MOV to TCON (TF bits preserved if overflow this cycle).
            if (tcon_wr_req)
                tcon <= tcon_wr_val | {t1_overflow_now, 1'b0,
                                       t0_overflow_now, 1'b0, 4'b0000};
            // Interrupt-acknowledge bit clears (request from execute block).
            if (tcon_clr_ie0_req) tcon[1] <= 1'b0;
            if (tcon_clr_ie1_req) tcon[3] <= 1'b0;
            if (tcon_clr_tf0_req) tcon[5] <= 1'b0;
            if (tcon_clr_tf1_req) tcon[7] <= 1'b0;

            // ---- INT0/INT1 falling-edge → set IE0/IE1 (TCON[1]/TCON[3]) ----
            int0_dly <= int0_n;
            int1_dly <= int1_n;
            if (tcon[0] && int0_fall) tcon[1] <= 1'b1;  // IT0=1 edge mode
            if (tcon[2] && int1_fall) tcon[3] <= 1'b1;  // IT1=1 edge mode

            if (machine_cycle_pulse) begin

            // ---- Timer 0 ----
            if (tcon[4]) begin          // TR0 running
                if (!tmod[2] || t0_fall) begin  // timer mode or T0 edge
                    case (tmod[1:0])
                        2'b00: begin                           // Mode 0: 13-bit
                            if ({th0, tl0[4:0]} == 13'h1FFF) begin
                                th0      <= 8'h00;
                                tl0[4:0] <= 5'h00;
                                tcon[5]  <= 1'b1;              // TF0
                            end else
                                {th0, tl0[4:0]} <= {th0, tl0[4:0]} + 1'b1;
                        end
                        2'b01: begin                           // Mode 1: 16-bit
                            if ({th0, tl0} == 16'hFFFF) begin
                                th0     <= 8'h00;
                                tl0     <= 8'h00;
                                tcon[5] <= 1'b1;               // TF0
                            end else
                                {th0, tl0} <= {th0, tl0} + 1'b1;
                        end
                        2'b10: begin                           // Mode 2: 8-bit auto-reload
                            if (tl0 == 8'hFF) begin
                                tl0     <= th0;
                                tcon[5] <= 1'b1;               // TF0
                            end else
                                tl0 <= tl0 + 1'b1;
                        end
                        2'b11: begin                           // Mode 3: split — TL0 alone
                            if (tl0 == 8'hFF) begin
                                tl0     <= 8'h00;
                                tcon[5] <= 1'b1;               // TF0
                            end else
                                tl0 <= tl0 + 1'b1;
                        end
                    endcase
                end
            end

            // ---- Timer 1 ----
            if (tcon[6]) begin          // TR1 running
                if (!tmod[6] || t1_fall) begin
                    case (tmod[5:4])
                        2'b00: begin                           // Mode 0: 13-bit
                            if ({th1, tl1[4:0]} == 13'h1FFF) begin
                                th1      <= 8'h00;
                                tl1[4:0] <= 5'h00;
                                tcon[7]  <= 1'b1;              // TF1
                            end else
                                {th1, tl1[4:0]} <= {th1, tl1[4:0]} + 1'b1;
                        end
                        2'b01: begin                           // Mode 1: 16-bit
                            if ({th1, tl1} == 16'hFFFF) begin
                                th1     <= 8'h00;
                                tl1     <= 8'h00;
                                tcon[7] <= 1'b1;               // TF1
                            end else
                                {th1, tl1} <= {th1, tl1} + 1'b1;
                        end
                        2'b10: begin                           // Mode 2: 8-bit auto-reload
                            if (tl1 == 8'hFF) begin
                                tl1     <= th1;
                                tcon[7] <= 1'b1;               // TF1
                            end else
                                tl1 <= tl1 + 1'b1;
                        end
                        2'b11: ;  // Mode 3: Timer 1 halted when T0 uses Mode 3
                    endcase
                end
            end

        end  // machine_cycle_pulse
        end
    end

    // ================================================================
    //  UART — Modes 1, 2, 3
    //
    //  SCON: [7]=SM0 [6]=SM1 [5]=SM2 [4]=REN [3]=TB8 [2]=RB8 [1]=TI [0]=RI
    //  PCON: [7]=SMOD (doubles baud rate for modes 1/3 when set)
    //
    //  Mode 1 ({SM0,SM1}=01): 8-bit UART, baud = Timer 1 overflow / 16
    //  Mode 2 ({SM0,SM1}=10): 9-bit UART, baud = fosc/64 (SMOD=0) or fosc/32 (SMOD=1)
    //  Mode 3 ({SM0,SM1}=11): 9-bit UART, baud = Timer 1 overflow / 16
    //
    //  TX bits: START(0), D0-D7, [TB8 in modes 2/3], STOP(1) → sets TI
    //  RX bits: START, D0-D7, [9th→RB8 in modes 2/3], STOP      → sets RI
    // ================================================================

    // ── Baud clock: Timer 1 overflow (modes 1 & 3) ───────────────────
    // Pulse on TL1 wrap 0xFF→0x00 while TR1 runs in timer mode.
    // Independent of TF1 sticky flag.
    reg [7:0] tl1_dly;
    wire baud_t1 = (tcon[6] && !tmod[6] &&
                    tl1_dly == 8'hFF && tl1 == 8'h00);
    always @(posedge clk) tl1_dly <= tl1;

    // ── Baud clock: fixed fosc/64 or fosc/32 (mode 2) ────────────────
    reg [5:0] m2_cnt;
    wire      baud_m2_pulse;
    // SMOD=0 → divide by 64; SMOD=1 → divide by 32
    assign baud_m2_pulse = pcon[7] ? (m2_cnt == 6'd31) : (m2_cnt == 6'd63);
    always @(posedge clk or negedge res_n)
        if (!res_n) m2_cnt <= 6'd0;
        else        m2_cnt <= baud_m2_pulse ? 6'd0 : m2_cnt + 1'b1;

    // Select baud source based on mode
    wire [1:0] uart_mode = {scon[7], scon[6]};
    wire baud_tick = (uart_mode == 2'b10) ? baud_m2_pulse : baud_t1;

    // ── TX engine ─────────────────────────────────────────────────────
    // Each cnt==15 event ends the current bit period and drives the next.
    //
    // Mode 1  (8-bit):  START D0-D7 STOP           = 10 bit-periods
    //   state: 0=IDLE, 1=START, 2-9=D0-D7, STOP fires at state==9
    //
    // Mode 2/3 (9-bit): START D0-D7 TB8 STOP       = 11 bit-periods
    //   state: 0=IDLE, 1=START, 2-9=D0-D7, 9=TB8, STOP fires at state==10
    //
    // tx_stop_state: the state at which the STOP bit is driven and TI set.
    reg [3:0]  tx_state;
    reg [7:0]  tx_shift;
    reg [3:0]  tx_baud_cnt;
    reg        tx_armed;
    wire       tx_9bit = (uart_mode == 2'b10 || uart_mode == 2'b11);
    wire [3:0] tx_stop_state = tx_9bit ? 4'd10 : 4'd9;

    always @(posedge clk or negedge res_n) begin
        if (!res_n) begin
            tx_state    <= 4'd0;
            tx_shift    <= 8'hFF;
            tx_baud_cnt <= 4'd0;
            tx_armed    <= 1'b0;
            sbuf_wr     <= 1'b0;
            txd         <= 1'b1;
            scon_set_ti_req <= 1'b0;
        end else begin
            // One-shot: default-deassert TI request; re-asserted below on TX done.
            scon_set_ti_req <= 1'b0;
            // sbuf_wr is set (NB) by sfr_write; clear it one cycle later
            // so the TX engine sees exactly one high pulse per write.
            if (sbuf_wr) begin
                sbuf_wr  <= 1'b0;
                tx_armed <= 1'b1;
            end

            if (baud_tick) begin
                tx_baud_cnt <= tx_baud_cnt + 1'b1;
                if (tx_baud_cnt == 4'd15) begin
                    if (tx_state == 4'd0) begin                  // IDLE
                        if (tx_armed) begin
                            tx_shift <= sbuf_tx;
                            tx_armed <= 1'b0;
                            tx_state <= 4'd1;
                            txd      <= 1'b0;                    // START bit
                        end
                    end else if (tx_state == tx_stop_state) begin // STOP bit
                        txd      <= 1'b1;
                        scon_set_ti_req <= 1'b1;                 // request TI set
                        tx_state <= 4'd0;
                    end else if (tx_9bit && tx_state == 4'd9) begin // 9th bit (TB8)
                        txd      <= scon[3];
                        tx_state <= 4'd10;
                    end else begin                               // D0-D7 (states 1-8)
                        txd      <= tx_shift[0];
                        tx_shift <= {1'b1, tx_shift[7:1]};
                        tx_state <= tx_state + 1'b1;
                    end
                end
            end
        end
    end

    // ── RX engine ─────────────────────────────────────────────────────
    // rx_bit_cnt: 0=start  1-8=D0-D7  [9=RB8 in modes 2/3]  then stop
    //
    // Mid-bit sample at rx_baud_cnt==7.  Frame complete at end of stop
    // bit period (rx_baud_cnt==15 when rx_bit_cnt==rx_stop_bit).
    //
    // Mode 1:   rx_stop_bit=9   → START D0-D7 STOP
    // Mode 2/3: rx_stop_bit=10  → START D0-D7 RB8 STOP
    //
    // The stop-bit period (bit_cnt==rx_stop_bit) is NOT shifted into
    // rx_shift; it is only used to validate the line is high.
    reg        rxd_sync0, rxd_sync1;
    wire       rxd_s = rxd_sync1;

    reg        rx_active;
    reg [3:0]  rx_baud_cnt;
    reg [3:0]  rx_bit_cnt;
    reg [7:0]  rx_shift;
    reg        rx_9th;
    wire       rx_9bit = (uart_mode == 2'b10 || uart_mode == 2'b11);
    wire [3:0] rx_stop_bit = rx_9bit ? 4'd10 : 4'd9;

    always @(posedge clk or negedge res_n) begin
        if (!res_n) begin
            rxd_sync0   <= 1'b1;
            rxd_sync1   <= 1'b1;
            rx_active   <= 1'b0;
            rx_baud_cnt <= 4'd0;
            rx_bit_cnt  <= 4'd0;
            rx_shift    <= 8'h00;
            rx_9th      <= 1'b0;
            scon_set_ri_req  <= 1'b0;
            scon_set_rb8_req <= 1'b0;
        end else begin
            // One-shot: default-deassert RI/RB8 requests; re-asserted below on RX done.
            scon_set_ri_req  <= 1'b0;
            scon_set_rb8_req <= 1'b0;
            rxd_sync0 <= rxd;
            rxd_sync1 <= rxd_sync0;

            if (baud_tick) begin
                if (!rx_active) begin
                    if (scon[4] && !rxd_s) begin   // REN=1, start-bit edge
                        rx_active   <= 1'b1;
                        rx_baud_cnt <= 4'd0;
                        rx_bit_cnt  <= 4'd0;
                    end
                end else begin
                    rx_baud_cnt <= rx_baud_cnt + 1'b1;

                    if (rx_baud_cnt == 4'd7) begin  // mid-bit sample
                        if (rx_bit_cnt == 4'd0) begin
                            // Validate start bit; abort if already high
                            if (rxd_s) rx_active <= 1'b0;
                        end else if (rx_bit_cnt == rx_stop_bit) begin
                            // Stop bit period — do not shift; validate at cnt==15
                        end else if (rx_9bit && rx_bit_cnt == 4'd9) begin
                            rx_9th <= rxd_s;           // 9th data bit → RB8
                        end else begin
                            rx_shift <= {rxd_s, rx_shift[7:1]};  // D0-D7
                        end
                    end

                    if (rx_baud_cnt == 4'd15) begin
                        rx_bit_cnt <= rx_bit_cnt + 1'b1;
                        if (rx_bit_cnt == rx_stop_bit) begin   // end of stop bit
                            rx_active <= 1'b0;
                            if (rxd_s && !scon[0]) begin       // valid stop + RI clear
                                sbuf_rx  <= rx_shift;
                                if (rx_9bit) begin
                                    scon_set_rb8_req <= 1'b1;   // request RB8
                                    scon_rb8_val     <= rx_9th;
                                end
                                scon_set_ri_req <= 1'b1;        // request RI set
                            end
                        end
                    end
                end
            end
        end
    end

    // ================================================================
    //  12-oscillator-clock machine cycle engine
    //
    //  The Intel 8051 divides each machine cycle into 6 states (S1-S6),
    //  each state having two phases (P1 and P2), giving 12 oscillator
    //  clocks per machine cycle.  This counter (osc_cnt 0-11) directly
    //  maps to the datasheet timing diagram:
    //
    //   osc_cnt |  State/Phase  | ALE | /PSEN | Action
    //  ---------+---------------+-----+-------+----------------------------
    //      0    |    S1 P1      |  1  |   1   | ALE rises; addr bus = PC
    //      1    |    S1 P2      |  1  |   1   | Address stable
    //      2    |    S2 P1      |  0  |   0   | ALE falls; /PSEN asserts
    //      3    |    S2 P2      |  0  |   0   | ROM access in progress
    //      4    |    S3 P1      |  0  |   1   | /PSEN rises; latch IR (cy1)
    //      5    |    S3 P2      |  0  |   1   | Idle / ALU pipeline
    //      6    |    S4 P1      |  1  |   1   | ALE rises (2nd fetch window)
    //      7    |    S4 P2      |  1  |   1   | Address stable (PC+1 / dummy)
    //      8    |    S5 P1      |  0  |   0   | ALE falls; /PSEN asserts (2nd)
    //           |               |     |       | OR /RD asserts for MOVX read
    //      9    |    S5 P2      |  0  |   0   | 2nd ROM byte / MOVX data valid
    //     10    |    S6 P1      |  0  |   1   | /PSEN rises; operand available
    //           |               |     |       | OR /WR asserts for MOVX write
    //     11    |    S6 P2      |  0  |   1   | EXECUTE; interrupt check;
    //           |               |     |       | machine_cycle_pulse for timers
    //
    //  For multi-cycle instructions cycle_2 defers execute
    //  until the final machine cycle, exactly as on real hardware.
    // ================================================================

    always @(posedge clk or negedge res_n) begin
        if (!res_n) begin
            osc_cnt         <= 4'd0;
            cycle_count     <= 64'd0;
            machine_cycle_pulse <= 1'b0;
            ir              <= 8'h00;
            pc              <= 16'h0000;
            cycle_2         <= 1'b0;
            irq_in_progress <= 1'b0;
            irq_hi_active   <= 1'b0;
            irq_pending_hi  <= 1'b0;

            irq_pending     <= 1'b0;
            irq_vector      <= 16'h0000;
            tcon_clr_tf0_req <= 1'b0;
            tcon_clr_tf1_req <= 1'b0;
            tcon_clr_ie0_req <= 1'b0;
            tcon_clr_ie1_req <= 1'b0;
            tcon_wr_req      <= 1'b0;
            psw             <= 8'h00;
            sp              <= 8'h07;   // 8051 reset value
            acc             <= 8'h00;
            b_reg           <= 8'h00;
            dpl             <= 8'h00;
            dph             <= 8'h00;
            p0              <= 8'hFF;
            p1              <= 8'hFF;
            p2              <= 8'hFF;
            p3              <= 8'hFF;
            ie              <= 8'h00;
            ip              <= 8'h00;
            scon            <= 8'h00;
            pcon            <= 8'h00;
            ale             <= 1'b0;
            psen_n          <= 1'b1;
            xrd_n           <= 1'b1;
            xwr_n           <= 1'b1;
            rom_data_latch  <= 8'h00;
        end else begin

            // Free-running cycle counter for profiling
            cycle_count <= cycle_count + 64'd1;

            // Default-deassert tcon write/clear request pulses. The interrupt
            // logic or sfr_write below re-asserts them this same cycle if needed
            // (later non-blocking write in this block wins).
            tcon_clr_tf0_req <= 1'b0;
            tcon_clr_tf1_req <= 1'b0;
            tcon_clr_ie0_req <= 1'b0;
            tcon_clr_ie1_req <= 1'b0;
            tcon_wr_req      <= 1'b0;

            // Parity auto-update (PSW[0]) on every clock.
            // Guard against X-propagation from uninitialised acc bits:
            // only update when acc is fully defined.  In synthesis this
            // condition is always true and optimises away.
            if ((^acc) !== 1'bx)  // guard against X-propagation (iverilog-safe)
                psw[0] <= parity;

            // machine_cycle_pulse fires exactly at S6P2 (osc_cnt == 11)
            machine_cycle_pulse <= (osc_cnt == 4'd10); // will be 1 next clock = clk 11

            case (osc_cnt)

                // ---- S1 P1 : ALE rises, address driven ----
                4'd0: begin
                    ale    <= 1'b1;
                    psen_n <= 1'b1;
                    xrd_n  <= 1'b1;
                    xwr_n  <= 1'b1;
                    osc_cnt <= 4'd1;
                end

                // ---- S1 P2 : address stable ----
                4'd1: osc_cnt <= 4'd2;

                // ---- S2 P1 : ALE falls, /PSEN asserts ----
                4'd2: begin
                    ale    <= 1'b0;
                    psen_n <= 1'b0;
                    osc_cnt <= 4'd3;
                end

                // ---- S2 P2 : ROM access in progress ----
                4'd3: osc_cnt <= 4'd4;

                // ---- S3 P1 : /PSEN rises; capture rom_data before bus goes Z ----
                4'd4: begin
                    psen_n         <= 1'b1;
                    rom_data_latch <= rom_data;
                    osc_cnt        <= 4'd5;
                end

                // ---- S3 P2 : rom_data_latch stable; latch IR and advance PC ----
                //  PC increments here so the second fetch window (S4–S6P1)
                //  addresses PC+1 = first operand byte.
                //  Suppressed when irq_pending: the interrupt will be taken at
                //  osc_cnt==11 and needs pc to hold the correct return address,
                //  not a pre-incremented value.
                4'd5: begin
                    if (!cycle_2 && !irq_pending) begin
                        ir <= rom_data_latch;
                        pc <= pc + 1'b1;
                    end
                    osc_cnt <= 4'd6;
                end

                // ---- S4 P1 : ALE rises for second fetch window ----
                4'd6: begin
                    ale    <= 1'b1;
                    osc_cnt <= 4'd7;
                end

                // ---- S4 P2 : address stable (PC+1 for 2-byte; dummy if 1-byte) ----
                4'd7: osc_cnt <= 4'd8;

                // ---- S5 P1 : ALE falls; /PSEN asserts for 2nd byte
                //              OR /RD asserts for MOVX reads ----
                4'd8: begin
                    ale    <= 1'b0;
                    // For MOVX read, use external RD instead of PSEN
                    if (cycle_2 && ((ir == 8'hE0) ||
                                    (ir == 8'hE2) || (ir == 8'hE3))) begin
                        psen_n <= 1'b1;   // no program fetch during MOVX
                        xrd_n  <= 1'b0;
                    end else begin
                        psen_n <= 1'b0;
                    end
                    osc_cnt <= 4'd9;
                end

                // ---- S5 P2 : 2nd ROM byte valid / MOVX data valid ----
                4'd9: osc_cnt <= 4'd10;

                // ---- S6 P1 : /PSEN rises; operand available
                //              OR /WR asserts for MOVX writes ----
                4'd10: begin
                    psen_n         <= 1'b1;
                    rom_data_latch <= rom_data;   // capture operand before bus goes Z
                    if (cycle_2 && ((ir == 8'hF0) ||
                                    (ir == 8'hF2) || (ir == 8'hF3)))
                        xwr_n <= 1'b0;
                    osc_cnt <= 4'd11;
                end

                // ---- S6 P2 : EXECUTE + interrupt sampling ----
                4'd11: begin
                    osc_cnt <= 4'd0;
                    xrd_n   <= 1'b1;
                    xwr_n   <= 1'b1;

                    if (!cycle_2 && irq_pending &&
                            (!irq_in_progress ||   // normal: no ISR running
                             irq_pending_hi))       // preempt: latched irq is hi-pri
                    begin
                        // Take a previously-latched interrupt.
                        // irq_pending_hi captures whether the arbiter deemed the
                        // source high-priority at latch time, independent of the
                        // current irq_hi_active state.
                        irq_pending    <= 1'b0;
                        irq_pending_hi <= 1'b0;
                        // irq_hi_active is set by the arbiter to reflect the
                        // priority level of the ISR we are about to enter.
                        service_interrupt(irq_vector, pc);
                    end else begin
                        // Emit profiling trace on every instruction execution.
                        // cycle_2: final cycle of multi-cycle instruction.
`ifdef CPU_DEEP_DEBUG
                        if (!irq_pending)
                            $display("DME: [EXEC] cyc=%0d pc=%04Xh ir=%02Xh sp=%02Xh a=%02Xh psw=%02Xh",
                                     cycle_count, pc, ir, sp, acc, psw);
`endif
                        // Always execute the current instruction.
                        execute_instruction();

                        // ---- Interrupt priority arbiter (IP-aware) ----
                        // IP register (0xB8): bit0=PX0 bit1=PT0 bit2=PX1 bit3=PT1
                        // High-priority sources can preempt a running low-priority ISR.
                        // Low-priority sources only fire when no ISR is in progress.
                        // Within each priority level the fixed order is:
                        //   IE0 (INT0) > TF0 (T0) > IE1 (INT1) > TF1 (T1) > serial
                        // which matches the 8051 hardware daisy-chain order.
                        if (!cycle_2 && ie[7]) begin

                            // Pending flags per source
                            // (level-triggered INT0/INT1 have no latch; edge-triggered
                            //  ones use tcon[1]/tcon[3] which are already set by the
                            //  edge detector above)
                            // High-priority active requests
                            // (a high-priority ISR can interrupt a low-priority one,
                            //  but NOT another high-priority one — irq_in_progress
                            //  is kept set throughout any ISR, so we gate high-priority
                            //  preemption on ip level vs current serving level.
                            //  Simplified: allow dispatch whenever the pending source
                            //  has higher priority than current, or no ISR is running.)

                            if (ie[0] && tcon[1] && ip[0] &&
                                    (!irq_in_progress || !irq_hi_active))
                                begin tcon_clr_ie0_req <= 1'b1; irq_pending <= 1'b1;
                                      irq_pending_hi <= 1'b1;
                                      irq_vector <= 16'h0003; irq_hi_active <= 1'b1; end
                            else if (ie[1] && tcon[5] && ip[1] &&
                                    (!irq_in_progress || !irq_hi_active))
                                begin tcon_clr_tf0_req <= 1'b1; irq_pending <= 1'b1;
                                      irq_pending_hi <= 1'b1;
                                      irq_vector <= 16'h000B; irq_hi_active <= 1'b1; end
                            else if (ie[2] && tcon[3] && ip[2] &&
                                    (!irq_in_progress || !irq_hi_active))
                                begin tcon_clr_ie1_req <= 1'b1; irq_pending <= 1'b1;
                                      irq_pending_hi <= 1'b1;
                                      irq_vector <= 16'h0013; irq_hi_active <= 1'b1; end
                            else if (ie[3] && tcon[7] && ip[3] &&
                                    (!irq_in_progress || !irq_hi_active))
                                begin tcon_clr_tf1_req <= 1'b1; irq_pending <= 1'b1;
                                      irq_pending_hi <= 1'b1;
                                      irq_vector <= 16'h001B; irq_hi_active <= 1'b1; end

                            // Low-priority sources: only when no ISR is in progress
                            else if (!irq_in_progress) begin
                                if (ie[0] && tcon[1] && !ip[0])
                                    begin tcon_clr_ie0_req <= 1'b1; irq_pending <= 1'b1;
                                          irq_pending_hi <= 1'b0;
                                          irq_vector <= 16'h0003; irq_hi_active <= 1'b0; end
                                else if (ie[0] && !tcon[0] && !int0_n && !ip[0])
                                    begin irq_pending <= 1'b1;
                                          irq_pending_hi <= 1'b0;
                                          irq_vector <= 16'h0003; irq_hi_active <= 1'b0; end
                                else if (ie[1] && tcon[5] && !ip[1])
                                    begin tcon_clr_tf0_req <= 1'b1; irq_pending <= 1'b1;
                                          irq_pending_hi <= 1'b0;
                                          irq_vector <= 16'h000B; irq_hi_active <= 1'b0; end
                                else if (ie[2] && tcon[3] && !ip[2])
                                    begin tcon_clr_ie1_req <= 1'b1; irq_pending <= 1'b1;
                                          irq_pending_hi <= 1'b0;
                                          irq_vector <= 16'h0013; irq_hi_active <= 1'b0; end
                                else if (ie[2] && !tcon[2] && !int1_n && !ip[2])
                                    begin irq_pending <= 1'b1;
                                          irq_pending_hi <= 1'b0;
                                          irq_vector <= 16'h0013; irq_hi_active <= 1'b0; end
                                else if (ie[3] && tcon[7] && !ip[3])
                                    begin tcon_clr_tf1_req <= 1'b1; irq_pending <= 1'b1;
                                          irq_pending_hi <= 1'b0;
                                          irq_vector <= 16'h001B; irq_hi_active <= 1'b0; end
                                else if (ie[4] && (scon[0] | scon[1]))
                                    begin irq_pending <= 1'b1;
                                          irq_pending_hi <= 1'b0;
                                          irq_vector <= 16'h0023; irq_hi_active <= 1'b0; end
                            end
                        end
                    end
                end

            endcase

            // ── Apply UART status-bit set requests LAST (execute owns scon) ──
            // Placed after the instruction case so a UART-set TI/RI is not lost
            // when software writes SCON the same machine cycle (hardware sets
            // these status bits regardless of concurrent software writes).
            if (scon_set_ti_req)  scon[1] <= 1'b1;   // TX complete → TI
            if (scon_set_ri_req)  scon[0] <= 1'b1;   // RX complete → RI
            if (scon_set_rb8_req) scon[2] <= scon_rb8_val;
        end
    end

    // ================================================================
    //  Full Instruction-Set Decoder
    //  Follows identical task/casez style as the 8048 model.
    //  All 8051 opcodes are implemented; refer to MCS-51 datasheet.
    // ================================================================
    task execute_instruction;
        // Local combinational temporaries
        reg [7:0]  op_a, op_b;
        reg [8:0]  sum9;
        reg [15:0] prod16;
        reg [7:0]  da_acc;
        reg        da_cy;
        begin
            casez (ir)

                // ====================================================
                //  NOP  [0x00]   1 cycle
                // ====================================================
                8'h00: begin

                end

                // ====================================================
                //  AJMP addr11  [x01]  2 cycles
                //  Target = { PC[15:11], ir[7:5], imm8 }
                //  cycle 1: latch page bits, advance PC
                //  cycle 2: rom_data_latch = low8 → jump
                // ====================================================
                8'b???00001: begin
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        pc      <= {pc[15:11], ir[7:5], rom_data_latch};
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  LJMP addr16  [0x02]  3 bytes, 2 cycles
                //  cycle 1: advance PC past opcode
                //  cycle 2: rom_data_latch=addr_hi → latch, advance PC
                //  cycle 3: rom_data_latch=addr_lo → jump
                // ====================================================
                8'h02: begin
                    if (!cycle_2) begin
                        tmp1    <= rom_data_latch;   // addr_hi
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        pc      <= {tmp1, rom_data_latch};
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  RR A  [0x03]  1 cycle
                // ====================================================
                8'h03: begin
                    acc_preop <= acc;
                    acc       <= {acc[0], acc[7:1]};
                end

                // ====================================================
                //  INC A  [0x04]  1 cycle
                // ====================================================
                8'h04: begin
                    acc_preop <= acc;
                    acc       <= acc + 1'b1;
                end

                // ====================================================
                //  INC direct  [0x05]  1 cycle
                // ====================================================
                8'h05: begin
                        tmp1 = direct_read(rom_data_latch);
                        direct_write(rom_data_latch, tmp1 + 1'b1);
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  INC @Ri  [0x06, 0x07]  1 cycle
                // ====================================================
                8'b0000011?: begin
                    ram_preop         <= iram[ri_ptr[6:0]];
                    iram[ri_ptr[6:0]] <= iram[ri_ptr[6:0]] + 1'b1;
                end

                // ====================================================
                //  INC Rn  [0x08–0x0F]  1 cycle
                // ====================================================
                8'b00001???: begin
                    ram_preop            <= iram[rn_addr];
                    iram[rn_addr]        <= iram[rn_addr] + 1'b1;
                end

                // ====================================================
                //  JBC bit, rel  [0x10]  2 cycles
                //  If bit=1: clear bit, then jump by signed rel offset
                // ====================================================
                // ====================================================
                //  JBC bit, rel  [0x10]  3 bytes, 2 cycles
                //  cycle 1: latch bit_addr, advance PC
                //  cycle 2: rom_data_latch=rel → test, clear bit, branch
                // ====================================================
                8'h10: begin
                    if (!cycle_2) begin
                        tmp1    <= rom_data_latch;   // bit address
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        if (bit_read(tmp1)) begin
                            bit_write(tmp1, 2'd0);   // CLR
                            pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        end else
                            pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  ACALL addr11  [x11]  2 cycles
                //  cycle 1: latch operand byte, advance PC
                //  cycle 2: rom_data_latch = low8 → push ret addr, jump
                // ====================================================
                8'b???10001: begin
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        // Push return address = pc+1 (address after the imm8 operand).
                        // pc currently points to imm8 byte; pc+1 is the next instruction.
                        iram[(sp + 8'h01) & 8'h7F] <= (pc + 1'b1) & 8'hFF; // low byte
                        iram[(sp + 8'h02) & 8'h7F] <= (pc + 1'b1) >> 8;    // high byte
                        sp      <= sp + 8'h02;
                        pc      <= {pc[15:11], ir[7:5], rom_data_latch};
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  LCALL addr16  [0x12]  3 bytes, 2 cycles
                //  cycle 1: advance PC past opcode
                //  cycle 2: rom_data_latch=addr_hi → latch, advance PC
                //  cycle 3: rom_data_latch=addr_lo → push ret addr, jump
                // ====================================================
                8'h12: begin
                    if (!cycle_2) begin
                        tmp1    <= rom_data_latch;   // target addr_hi
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        // pc currently points one past addr_lo → that is the return address
                        iram[(sp + 8'h01) & 8'h7F] <= (pc + 1'b1) & 8'hFF; // ret_lo
                        iram[(sp + 8'h02) & 8'h7F] <= (pc + 1'b1) >> 8;    // ret_hi
                        sp      <= sp + 8'h02;
                        pc      <= {tmp1, rom_data_latch};
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  RRC A  [0x13]  1 cycle
                // ====================================================
                8'h13: begin
                    acc_preop <= acc;
                    {psw[7], acc} <= {acc[0], psw[7], acc[7:1]};
                end

                // ====================================================
                //  DEC A  [0x14]  1 cycle
                // ====================================================
                8'h14: begin
                    acc_preop <= acc;
                    acc       <= acc - 1'b1;
                end

                // ====================================================
                //  DEC direct  [0x15]  1 cycle
                // ====================================================
                8'h15: begin
                        tmp1 = direct_read(rom_data_latch);
                        direct_write(rom_data_latch, tmp1 - 1'b1);
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  DEC @Ri  [0x16, 0x17]  1 cycle
                // ====================================================
                8'b0001011?: begin
                    ram_preop         <= iram[ri_ptr[6:0]];
                    iram[ri_ptr[6:0]] <= iram[ri_ptr[6:0]] - 1'b1;
                end

                // ====================================================
                //  DEC Rn  [0x18–0x1F]  1 cycle
                // ====================================================
                8'b00011???: begin
                    ram_preop     <= iram[rn_addr];
                    iram[rn_addr] <= iram[rn_addr] - 1'b1;
                end

                // ====================================================
                //  JB bit, rel  [0x20]  3 bytes, 2 cycles
                //  cycle 1: latch bit_addr, advance PC
                //  cycle 2: rom_data_latch=rel → test bit, branch
                // ====================================================
                8'h20: begin
                    if (!cycle_2) begin
                        tmp1    <= rom_data_latch;   // bit address
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        if (bit_read(tmp1))
                            pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else
                            pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  RET  [0x22]  2 cycles
                // ====================================================
                8'h22: begin
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        pc      <= {iram[sp[6:0]], iram[(sp - 1'b1) & 8'h7F]};
                        sp      <= sp - 2'd2;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  RL A  [0x23]  1 cycle
                // ====================================================
                8'h23: begin
                    acc_preop <= acc;
                    acc       <= {acc[6:0], acc[7]};
                end

                // ====================================================
                //  ADD A, #imm  [0x24]  1 cycle
                // ====================================================
                8'h24: begin // ADD A,#imm  2-cycle
                        sum9   = {1'b0, acc} + {1'b0, rom_data_latch};
                        acc    <= sum9[7:0];
                        psw[7] <= sum9[8];
                        psw[6] <= ({1'b0,acc[3:0]} + {1'b0,rom_data_latch[3:0]} > 5'h0F);
                        psw[2] <= (acc[7] == rom_data_latch[7]) & (sum9[7] != acc[7]);
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  ADD A, direct  [0x25]  1 cycle
                // ====================================================
                8'h25: begin // ADD A,direct  2-cycle
                        op_a   = direct_read(rom_data_latch);
                        sum9   = {1'b0, acc} + {1'b0, op_a};
                        acc    <= sum9[7:0];
                        psw[7] <= sum9[8];
                        psw[6] <= ({1'b0,acc[3:0]} + {1'b0,op_a[3:0]} > 5'h0F);
                        psw[2] <= (acc[7] == op_a[7]) & (sum9[7] != acc[7]);
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  ADD A, @Ri  [0x26, 0x27]  1 cycle
                // ====================================================
                8'b0010011?: begin
                    acc_preop <= acc;
                    op_a      = iram[ri_ptr[6:0]];
                    sum9      = {1'b0, acc} + {1'b0, op_a};
                    acc       <= sum9[7:0];
                    psw[7]    <= sum9[8];
                    psw[6]    <= ({1'b0,acc[3:0]} + {1'b0,op_a[3:0]} > 5'h0F);
                    psw[2]    <= (acc[7] == op_a[7]) & (sum9[7] != acc[7]);
                end

                // ====================================================
                //  ADD A, Rn  [0x28–0x2F]  1 cycle
                // ====================================================
                8'b00101???: begin
                    acc_preop <= acc;
                    op_a      = iram[rn_addr];
                    sum9      = {1'b0, acc} + {1'b0, op_a};
                    acc       <= sum9[7:0];
                    psw[7]    <= sum9[8];
                    psw[6]    <= ({1'b0,acc[3:0]} + {1'b0,op_a[3:0]} > 5'h0F);
                    psw[2]    <= (acc[7] == op_a[7]) & (sum9[7] != acc[7]);
                end

                // ====================================================
                //  JNB bit, rel  [0x30]  3 bytes, 2 cycles
                //  cycle 1: latch bit_addr, advance PC
                //  cycle 2: rom_data_latch=rel → test bit, branch
                // ====================================================
                8'h30: begin
                    if (!cycle_2) begin
                        tmp1    <= rom_data_latch;   // bit address
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        if (!bit_read(tmp1))
                            pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else
                            pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  RETI  [0x32]  2 cycles
                // ====================================================
                8'h32: begin
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        pc              <= {iram[sp[6:0]], iram[(sp - 1'b1) & 8'h7F]};
                        sp              <= sp - 2'd2;
                        irq_in_progress <= 1'b0;
                        irq_hi_active   <= 1'b0;
                        irq_pending_hi  <= 1'b0;
                        cycle_2         <= 1'b0;
                    end
                end

                // ====================================================
                //  RLC A  [0x33]  1 cycle
                // ====================================================
                8'h33: begin
                    acc_preop <= acc;
                    {psw[7], acc} <= {acc, psw[7]};
                end

                // ====================================================
                //  ADDC A, #imm  [0x34]  1 cycle
                // ====================================================
                8'h34: begin // ADDC A,#imm  2-cycle
                        sum9   = {1'b0, acc} + {1'b0, rom_data_latch} + {8'b0, psw[7]};
                        psw[7] <= sum9[8];
                        psw[6] <= ({1'b0,acc[3:0]} + {1'b0,rom_data_latch[3:0]} + {4'b0,psw[7]} > 5'h0F);
                        psw[2] <= (acc[7] == rom_data_latch[7]) & (sum9[7] != acc[7]);
                        acc    <= sum9[7:0];
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  ADDC A, direct  [0x35]  1 cycle
                // ====================================================
                8'h35: begin // ADDC A,direct  2-cycle
                        op_a   = direct_read(rom_data_latch);
                        sum9   = {1'b0, acc} + {1'b0, op_a} + {8'b0, psw[7]};
                        psw[7] <= sum9[8];
                        psw[6] <= ({1'b0,acc[3:0]} + {1'b0,op_a[3:0]} + {4'b0,psw[7]} > 5'h0F);
                        psw[2] <= (acc[7] == op_a[7]) & (sum9[7] != acc[7]);
                        acc    <= sum9[7:0];
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  ADDC A, @Ri  [0x36, 0x37]  1 cycle
                // ====================================================
                8'b0011011?: begin
                    acc_preop <= acc;
                    op_a      = iram[ri_ptr[6:0]];
                    sum9      = {1'b0, acc} + {1'b0, op_a} + {8'b0, psw[7]};
                    psw[7]    <= sum9[8];
                    psw[6]    <= ({1'b0,acc[3:0]} + {1'b0,op_a[3:0]} + {4'b0,psw[7]} > 5'h0F);
                    psw[2]    <= (acc[7] == op_a[7]) & (sum9[7] != acc[7]);
                    acc       <= sum9[7:0];
                end

                // ====================================================
                //  ADDC A, Rn  [0x38–0x3F]  1 cycle
                // ====================================================
                8'b00111???: begin
                    acc_preop <= acc;
                    op_a      = iram[rn_addr];
                    sum9      = {1'b0, acc} + {1'b0, op_a} + {8'b0, psw[7]};
                    psw[7]    <= sum9[8];
                    psw[6]    <= ({1'b0,acc[3:0]} + {1'b0,op_a[3:0]} + {4'b0,psw[7]} > 5'h0F);
                    psw[2]    <= (acc[7] == op_a[7]) & (sum9[7] != acc[7]);
                    acc       <= sum9[7:0];
                end

                // ====================================================
                //  JC rel  [0x40]  2 cycles
                // ====================================================
                8'h40: begin // JC rel  2 cycles
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        if (psw[7]) pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else        pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  ORL direct, A  [0x42]  1 cycle
                // ====================================================
                8'h42: begin // ORL direct,A  1-cycle
                    op_a = direct_read(rom_data_latch);
                    direct_write(rom_data_latch, op_a | acc);
                    pc <= pc + 1'b1;
                end

                // ====================================================
                //  ORL direct, #imm  [0x43]  2 cycles
                // ====================================================
                8'h43: begin // ORL direct,#imm  3-byte, 2-cycle
                    if (!cycle_2) begin
                        dir_addr_latch <= rom_data_latch;            // latch direct addr
                        tmp1           <= direct_read(rom_data_latch); // read current value
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        direct_write(dir_addr_latch, tmp1 | rom_data_latch);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  ORL A, #imm  [0x44]  1 cycle
                // ====================================================
                8'h44: begin // ORL A,#imm  2-cycle
                        acc <= acc | rom_data_latch;
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  ORL A, direct  [0x45]  1 cycle
                // ====================================================
                8'h45: begin // ORL A,direct  2-cycle
                        op_a  = direct_read(rom_data_latch);
                        acc  <= acc | op_a;
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  ORL A, @Ri  [0x46, 0x47]  1 cycle
                // ====================================================
                8'b0100011?: begin
                    acc_preop <= acc;
                    op_a      = iram[ri_ptr[6:0]];
                    acc       <= acc | op_a;
                end

                // ====================================================
                //  ORL A, Rn  [0x48–0x4F]  1 cycle
                // ====================================================
                8'b01001???: begin
                    acc_preop <= acc;
                    op_a      = iram[rn_addr];
                    acc       <= acc | op_a;
                end

                // ====================================================
                //  JNC rel  [0x50]  2 cycles
                // ====================================================
                8'h50: begin // JNC rel  2 cycles
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        if (!psw[7]) pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else         pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  ANL direct, A  [0x52]  1 cycle
                // ====================================================
                8'h52: begin // ANL direct,A  2-cycle
                        op_a = direct_read(rom_data_latch);
                        direct_write(rom_data_latch, op_a & acc);
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  ANL direct, #imm  [0x53]  2 cycles
                // ====================================================
                8'h53: begin // ANL direct,#imm  3-byte, 2-cycle
                    if (!cycle_2) begin
                        dir_addr_latch <= rom_data_latch;
                        tmp1           <= direct_read(rom_data_latch);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        direct_write(dir_addr_latch, tmp1 & rom_data_latch);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  ANL A, #imm  [0x54]  1 cycle
                // ====================================================
                8'h54: begin // ANL A,#imm  2-cycle
                        acc <= acc & rom_data_latch;
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  ANL A, direct  [0x55]  1 cycle
                // ====================================================
                8'h55: begin // ANL A,direct  2-cycle
                        op_a  = direct_read(rom_data_latch);
                        acc  <= acc & op_a;
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  ANL A, @Ri  [0x56, 0x57]  1 cycle
                // ====================================================
                8'b0101011?: begin
                    acc_preop <= acc;
                    op_a      = iram[ri_ptr[6:0]];
                    acc       <= acc & op_a;
                end

                // ====================================================
                //  ANL A, Rn  [0x58–0x5F]  1 cycle
                // ====================================================
                8'b01011???: begin
                    acc_preop <= acc;
                    op_a      = iram[rn_addr];
                    acc       <= acc & op_a;
                end

                // ====================================================
                //  JZ rel  [0x60]  2 cycles
                // ====================================================
                8'h60: begin // JZ rel  2 cycles
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        if (acc == 8'h00) pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else              pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  XRL direct, A  [0x62]  1 cycle
                // ====================================================
                8'h62: begin // XRL direct,A  2-cycle
                        op_a = direct_read(rom_data_latch);
                        direct_write(rom_data_latch, op_a ^ acc);
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  XRL direct, #imm  [0x63]  2 cycles
                // ====================================================
                8'h63: begin // XRL direct,#imm  3-byte, 2-cycle
                    if (!cycle_2) begin
                        dir_addr_latch <= rom_data_latch;
                        tmp1           <= direct_read(rom_data_latch);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        direct_write(dir_addr_latch, tmp1 ^ rom_data_latch);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  XRL A, #imm  [0x64]  1 cycle
                // ====================================================
                8'h64: begin // XRL A,#imm  2-cycle
                        acc <= acc ^ rom_data_latch;
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  XRL A, direct  [0x65]  1 cycle
                // ====================================================
                8'h65: begin // XRL A,direct  2-cycle
                        op_a  = direct_read(rom_data_latch);
                        acc  <= acc ^ op_a;
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  XRL A, @Ri  [0x66, 0x67]  1 cycle
                // ====================================================
                8'b0110011?: begin
                    acc_preop <= acc;
                    op_a      = iram[ri_ptr[6:0]];
                    acc       <= acc ^ op_a;
                end

                // ====================================================
                //  XRL A, Rn  [0x68–0x6F]  1 cycle
                // ====================================================
                8'b01101???: begin
                    acc_preop <= acc;
                    op_a      = iram[rn_addr];
                    acc       <= acc ^ op_a;
                end

                // ====================================================
                //  JNZ rel  [0x70]  2 cycles
                // ====================================================
                8'h70: begin // JNZ rel  2 cycles
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        if (acc != 8'h00) pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else              pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  ORL C, bit  [0x72]  2 cycles
                // ====================================================
                8'h72: begin // ORL C, bit  2 cycles
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        psw[7]  <= psw[7] | bit_read(rom_data_latch);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  JMP @A+DPTR  [0x73]  2 cycles
                // ====================================================
                8'h73: begin
                    if (!cycle_2) begin cycle_2 <= 1'b1; end
                    else begin
                        pc      <= dptr + {8'h00, acc};
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOV A, #imm  [0x74]  1 cycle
                // ====================================================
                8'h74: begin // MOV A,#imm  2-cycle
                        acc <= rom_data_latch;
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  MOV direct, #imm  [0x75]  2 cycles
                // ====================================================
                8'h75: begin // MOV direct,#imm  3-byte, 2-cycle
                    if (!cycle_2) begin
                        dir_addr_latch <= rom_data_latch;   // latch direct addr
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        direct_write(dir_addr_latch, rom_data_latch);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOV @Ri, #imm  [0x76, 0x77]  1 cycle
                // ====================================================
                8'b0111011?: begin
                    ram_preop         <= iram[ri_ptr[6:0]];
                    iram[ri_ptr[6:0]] <= rom_data_latch;
                    pc      <= pc + 1'b1;
                end

                // ====================================================
                //  MOV Rn, #imm  [0x78-0x7F]  1 cycle
                // ====================================================
                8'b01111???: begin
                    ram_preop     <= iram[rn_addr];
                    iram[rn_addr] <= rom_data_latch;
                    pc      <= pc + 1'b1;
                end

                // ====================================================
                //  SJMP rel  [0x80]  2 cycles  (signed 8-bit offset)
                // ====================================================
                8'h80: begin // SJMP rel  2 cycles
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        pc      <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  ANL C, bit  [0x82]  2 cycles
                // ====================================================
                8'h82: begin // ANL C, bit  2 cycles
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        psw[7]  <= psw[7] & bit_read(rom_data_latch);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOVC A, @A+PC  [0x83]  2 cycles
                //  addr_bus mux (above module level) drives {PC + A}
                // ====================================================
                8'h83: begin
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                        // addr_bus mux will use (pc + acc) during cycle 2
                    end else begin
                        acc_preop <= acc;
                        acc       <= rom_data_latch;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  DIV AB  [0x84]  4 machine cycles (modelled as 2)
                //  A ← quotient,  B ← remainder
                //  CY=0 always;   OV=1 if B was 0
                // ====================================================
                8'h84: begin
                    if (!cycle_2) begin cycle_2 <= 1'b1; end
                    else begin
                        if (b_reg == 8'h00) begin
                            psw[7] <= 1'b0;
                            psw[2] <= 1'b1;   // OV: divide-by-zero
                        end else begin
                            op_a   = acc / b_reg;
                            b_reg <= acc % b_reg;
                            acc   <= op_a;
                            psw[7] <= 1'b0;
                            psw[2] <= 1'b0;
                        end
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOV direct, direct  [0x85]  3 bytes
                //  Encoded as: 0x85, src_addr, dst_addr
                // ====================================================
                8'h85: begin // 3-byte, 2-cycle
                    if (!cycle_2) begin
                        tmp1    <= direct_read(rom_data_latch);  // read src value
                        tmp2    <= rom_data_latch;               // save src addr for display
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        direct_write(rom_data_latch, tmp1);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOV direct, @Ri  [0x86, 0x87]  2 cycles
                //  cycle 1: latch direct addr + @Ri value, advance PC
                //  cycle 2: write @Ri → direct
                // ====================================================
                8'b1000011?: begin
                    if (!cycle_2) begin
                        tmp1    <= iram[ri_ptr[6:0]];  // latch @Ri value
                        cycle_2 <= 1'b1;
                    end else begin
                        direct_write(rom_data_latch, tmp1);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOV direct, Rn  [0x88–0x8F]  2 cycles
                //  cycle 1: latch direct addr, advance PC
                //  cycle 2: write Rn → direct
                // ====================================================
                8'b10001???: begin
                    if (!cycle_2) begin
                        tmp1    <= iram[rn_addr];   // latch Rn value
                        cycle_2 <= 1'b1;
                    end else begin
                        direct_write(rom_data_latch, tmp1);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOV DPTR, #imm16  [0x90]  2 cycles
                // ====================================================
                8'h90: begin // MOV DPTR,#imm16  3-byte, 2-cycle
                    if (!cycle_2) begin
                        dph     <= rom_data_latch;   // high byte
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        dpl     <= rom_data_latch;   // low byte
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOV bit, C  [0x92]  2 cycles
                //  cycle 1: latch bit_addr, advance PC
                //  cycle 2: write C → bit
                // ====================================================
                8'h92: begin
                    if (!cycle_2) begin
                        tmp1    <= rom_data_latch;  // latch bit address
                        cycle_2 <= 1'b1;
                    end else begin
                        bit_write(tmp1, 2'd3);      // MOV C → bit
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOVC A, @A+DPTR  [0x93]  2 cycles
                //  addr_bus mux (module level) drives {DPTR + A}
                // ====================================================
                8'h93: begin
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        acc_preop <= acc;
                        acc       <= rom_data_latch;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  SUBB A, #imm  [0x94]  1 cycle
                // ====================================================
                8'h94: begin // SUBB A,#imm  2-cycle
                        sum9   = {1'b0, acc} - {1'b0, rom_data_latch} - {8'b0, psw[7]};
                        // CY = borrow out of bit 7 (= sum9[8]); AC = borrow out of bit 3
                        psw[7] <= sum9[8];
                        psw[6] <= ({1'b0,acc[3:0]} < ({1'b0,rom_data_latch[3:0]} + {4'b0,psw[7]}));
                        psw[2] <= (acc[7] != rom_data_latch[7]) & (sum9[7] != acc[7]);
                        acc    <= sum9[7:0];
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  SUBB A, direct  [0x95]  1 cycle
                // ====================================================
                8'h95: begin // SUBB A,direct  2-cycle
                        op_a   = direct_read(rom_data_latch);
                        sum9   = {1'b0, acc} - {1'b0, op_a} - {8'b0, psw[7]};
                        psw[7] <= sum9[8];
                        psw[6] <= ({1'b0,acc[3:0]} < ({1'b0,op_a[3:0]} + {4'b0,psw[7]}));
                        psw[2] <= (acc[7] != op_a[7]) & (sum9[7] != acc[7]);
                        acc    <= sum9[7:0];
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  SUBB A, @Ri  [0x96, 0x97]  1 cycle
                // ====================================================
                8'b1001011?: begin
                    acc_preop <= acc;
                    op_a      = iram[ri_ptr[6:0]];
                    sum9      = {1'b0, acc} - {1'b0, op_a} - {8'b0, psw[7]};
                    psw[7]    <= sum9[8];
                    psw[6]    <= ({1'b0,acc[3:0]} < ({1'b0,op_a[3:0]} + {4'b0,psw[7]}));
                    psw[2]    <= (acc[7] != op_a[7]) & (sum9[7] != acc[7]);
                    acc       <= sum9[7:0];
                end

                // ====================================================
                //  SUBB A, Rn  [0x98–0x9F]  1 cycle
                // ====================================================
                8'b10011???: begin
                    acc_preop <= acc;
                    op_a      = iram[rn_addr];
                    sum9      = {1'b0, acc} - {1'b0, op_a} - {8'b0, psw[7]};
                    psw[7]    <= sum9[8];
                    psw[6]    <= ({1'b0,acc[3:0]} < ({1'b0,op_a[3:0]} + {4'b0,psw[7]}));
                    psw[2]    <= (acc[7] != op_a[7]) & (sum9[7] != acc[7]);
                    acc       <= sum9[7:0];
                end

                // ====================================================
                //  ORL C, /bit  [0xA0]  2 cycles
                // ====================================================
                8'hA0: begin // ORL C, /bit  2 cycles
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        psw[7]  <= psw[7] | (~bit_read(rom_data_latch));
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOV C, bit  [0xA2]  2 cycles
                // ====================================================
                8'hA2: begin // MOV C, bit  2 cycles
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        psw[7]  <= bit_read(rom_data_latch);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  INC DPTR  [0xA3]  2 cycles
                // ====================================================
                8'hA3: begin
                    if (!cycle_2) begin cycle_2 <= 1'b1; end
                    else begin
                        {dph, dpl} <= dptr + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MUL AB  [0xA4]  4 machine cycles (modelled as 2)
                //  A ← low byte,  B ← high byte
                //  CY=0;  OV=1 if B != 0
                // ====================================================
                8'hA4: begin
                    if (!cycle_2) begin cycle_2 <= 1'b1; end
                    else begin
                        prod16  = {8'h00, acc} * {8'h00, b_reg};
                        acc    <= prod16[7:0];
                        b_reg  <= prod16[15:8];
                        psw[7] <= 1'b0;
                        psw[2] <= (prod16[15:8] != 8'h00);
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOV @Ri, direct  [0xA6, 0xA7]  2 cycles
                //  cycle 1: latch direct addr + read value, advance PC
                //  cycle 2: write value → @Ri
                // ====================================================
                8'b1010011?: begin
                    if (!cycle_2) begin
                        tmp1    <= direct_read(rom_data_latch);
                        cycle_2 <= 1'b1;
                    end else begin
                        iram[ri_ptr[6:0]] <= tmp1;
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOV Rn, direct  [0xA8–0xAF]  2 cycles
                //  cycle 1: latch direct addr + read value, advance PC
                //  cycle 2: write value → Rn
                // ====================================================
                8'b10101???: begin
                    if (!cycle_2) begin
                        tmp1    <= direct_read(rom_data_latch);
                        cycle_2 <= 1'b1;
                    end else begin
                        iram[rn_addr] <= tmp1;
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  ANL C, /bit  [0xB0]  2 cycles
                // ====================================================
                8'hB0: begin // ANL C, /bit  2 cycles
                    if (!cycle_2) begin
                        cycle_2 <= 1'b1;
                    end else begin
                        psw[7]  <= psw[7] & (~bit_read(rom_data_latch));
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  CPL bit  [0xB2]  1 cycle  (iram bits)
                // ====================================================
                8'hB2: begin // CPL bit  1-cycle
                        bit_write(rom_data_latch, 2'd2);   // CPL
                        pc <= pc + 1'b1;
                    end

                // ====================================================
                //  CPL C  [0xB3]  1 cycle
                // ====================================================
                8'hB3: begin
                    psw[7] <= ~psw[7];
                end

                // ====================================================
                //  CJNE A, #imm, rel  [0xB4]  2 cycles
                // ====================================================
                // ====================================================
                //  CJNE A, #imm, rel  [0xB4]  3 bytes, 2 cycles
                //  cycle 1: advance PC past opcode
                //  cycle 2: rom_data_latch=imm → latch, advance PC past imm
                //  cycle 3: rom_data_latch=rel → compare, branch
                // ====================================================
                8'hB4: begin
                    if (!cycle_2) begin
                        tmp1    <= rom_data_latch;        // latch immediate
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        // rom_data_latch = signed rel offset
                        psw[7] <= (acc < tmp1) ? 1'b1 : 1'b0;
                        if (acc != tmp1)
                            pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else
                            pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  CJNE A, direct, rel  [0xB5]  3 bytes, 2 cycles
                //  cycle 1: advance PC past opcode
                //  cycle 2: rom_data_latch=direct addr → read value, advance PC
                //  cycle 3: rom_data_latch=rel → compare, branch
                // ====================================================
                8'hB5: begin
                    if (!cycle_2) begin
                        tmp1    <= direct_read(rom_data_latch); // read (direct) value
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        psw[7] <= (acc < tmp1) ? 1'b1 : 1'b0;
                        if (acc != tmp1)
                            pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else
                            pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  CJNE @Ri, #imm, rel  [0xB6, 0xB7]  3 bytes, 2 cycles
                //  cycle 1: advance PC past opcode
                //  cycle 2: rom_data_latch=imm → latch imm + @Ri value, advance PC
                //  cycle 3: rom_data_latch=rel → compare, branch
                // ====================================================
                8'b1011011?: begin
                    if (!cycle_2) begin
                        tmp1    <= iram[ri_ptr[6:0]];  // @Ri value
                        tmp2    <= rom_data_latch;            // immediate
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        psw[7] <= (tmp1 < tmp2) ? 1'b1 : 1'b0;
                        if (tmp1 != tmp2)
                            pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else
                            pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  CJNE Rn, #imm, rel  [0xB8–0xBF]  3 bytes, 2 cycles
                //  cycle 1: advance PC past opcode
                //  cycle 2: rom_data_latch=imm → latch imm + Rn value, advance PC
                //  cycle 3: rom_data_latch=rel → compare, branch
                // ====================================================
                8'b10111???: begin
                    if (!cycle_2) begin
                        tmp1    <= iram[rn_addr];  // Rn value
                        tmp2    <= rom_data_latch;        // immediate
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        psw[7] <= (tmp1 < tmp2) ? 1'b1 : 1'b0;
                        if (tmp1 != tmp2)
                            pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else
                            pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  PUSH direct  [0xC0]  2 cycles
                //  cycle 1: latch direct addr + read value, advance PC
                //  cycle 2: push value onto stack
                // ====================================================
                8'hC0: begin
                    if (!cycle_2) begin
                        tmp1    <= direct_read(rom_data_latch);
                        cycle_2 <= 1'b1;
                    end else begin
                        iram[(sp + 8'h01) & 8'h7F] <= tmp1;
                        sp      <= sp + 8'h01;
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  CLR bit  [0xC2]  1 cycle  (iram bits)
                // ====================================================
                8'hC2: begin // CLR bit  1-cycle
                        bit_write(rom_data_latch, 2'd0);   // CLR
                        pc <= pc + 1'b1;
                    end

                // ====================================================
                //  CLR C  [0xC3]  1 cycle
                // ====================================================
                8'hC3: begin
                    psw[7] <= 1'b0;
                end

                // ====================================================
                //  SWAP A  [0xC4]  1 cycle
                // ====================================================
                8'hC4: begin
                    acc_preop <= acc;
                    acc       <= {acc[3:0], acc[7:4]};
                end

                // ====================================================
                //  XCH A, direct  [0xC5]  1 cycle
                // ====================================================
                8'hC5: begin // XCH A,direct  2-cycle
                        op_a = direct_read(rom_data_latch);
                        acc  <= op_a;
                        direct_write(rom_data_latch, acc);
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  XCH A, @Ri  [0xC6, 0xC7]  1 cycle
                // ====================================================
                8'b1100011?: begin
                    acc_preop         <= acc;
                    op_a               = iram[ri_ptr[6:0]];
                    acc               <= op_a;
                    iram[ri_ptr[6:0]] <= acc;
                end

                // ====================================================
                //  XCH A, Rn  [0xC8–0xCF]  1 cycle
                // ====================================================
                8'b11001???: begin
                    acc_preop     <= acc;
                    op_a           = iram[rn_addr];
                    acc           <= op_a;
                    iram[rn_addr] <= acc;
                end

                // ====================================================
                //  POP direct  [0xD0]  2 cycles
                //  cycle 1: latch direct addr + pop value from stack, advance PC
                //  cycle 2: write popped value → direct
                // ====================================================
                8'hD0: begin
                    if (!cycle_2) begin
                        tmp1    <= iram[sp[6:0]];
                        sp      <= sp - 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        direct_write(rom_data_latch, tmp1);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  SETB bit  [0xD2]  1 cycle  (iram bits)
                // ====================================================
                8'hD2: begin // SETB bit  1-cycle
                        bit_write(rom_data_latch, 2'd1);   // SET
                        pc <= pc + 1'b1;
                    end

                // ====================================================
                //  SETB C  [0xD3]  1 cycle
                // ====================================================
                8'hD3: begin
                    psw[7] <= 1'b1;
                end

                // ====================================================
                //  DA A  [0xD4]  1 cycle — Decimal Adjust Accumulator
                // ====================================================
                8'hD4: begin
                    acc_preop = acc;
                    da_acc    = acc;
                    da_cy     = psw[7];
                    if ((da_acc[3:0] > 4'h9) || psw[6]) begin
                        {da_cy, da_acc} = {1'b0, da_acc} + 9'h006;
                    end
                    if ((da_acc[7:4] > 4'h9) || da_cy) begin
                        {da_cy, da_acc} = {1'b0, da_acc} + 9'h060;
                    end
                    acc    <= da_acc;
                    psw[7] <= da_cy;
                end

                // ====================================================
                //  DJNZ direct, rel  [0xD5]  2 cycles
                // ====================================================
                // ====================================================
                //  DJNZ direct, rel  [0xD5]  3 bytes, 2 cycles
                //  cycle 1: advance PC past opcode
                //  cycle 2: rom_data_latch=direct addr → decrement, advance PC
                //  cycle 3: rom_data_latch=rel → branch if not zero
                // ====================================================
                8'hD5: begin
                    if (!cycle_2) begin
                        dir_addr_latch <= rom_data_latch;
                        tmp1           <= direct_read(rom_data_latch) - 1'b1;
                        direct_write(rom_data_latch, direct_read(rom_data_latch) - 1'b1);
                        pc      <= pc + 1'b1;
                        cycle_2 <= 1'b1;
                    end else begin
                        if (tmp1 != 8'h00)
                            pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else
                            pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  XCHD A, @Ri  [0xD6, 0xD7]  1 cycle
                //  Swap low nibbles of A and (Ri)
                // ====================================================
                8'b1101011?: begin
                    acc_preop <= acc;
                    op_a       = iram[ri_ptr[6:0]];
                    acc[3:0]  <= op_a[3:0];
                    iram[ri_ptr[6:0]][3:0] <= acc[3:0];
                end

                // ====================================================
                //  DJNZ Rn, rel  [0xD8–0xDF]  2 cycles
                //  cycle 1: decrement Rn, latch result. NO pc advance —
                //           fetch re-reads rel byte so rom_data_latch valid in cycle 2.
                //  cycle 2: rom_data_latch=rel → branch if not zero
                // ====================================================
                8'b11011???: begin
                    if (!cycle_2) begin
                        iram[rn_addr] <= iram[rn_addr] - 1'b1;
                        tmp1          <= iram[rn_addr] - 1'b1;
                        cycle_2       <= 1'b1;
                    end else begin
                        if (tmp1 != 8'h00)
                            pc <= pc + {{8{rom_data_latch[7]}}, rom_data_latch} + 1'b1;
                        else
                            pc <= pc + 1'b1;
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOVX A, @DPTR  [0xE0]  2 cycles
                // ====================================================
                8'hE0: begin
                    if (!cycle_2) begin
                        xaddr_bus <= dptr;
                        xdata_out <= acc;       // P0 carries low addr byte
                        cycle_2   <= 1'b1;
                    end else begin
                        acc_preop <= acc;
                        acc       <= xdata_in;
                        cycle_2   <= 1'b0;
                    end
                end

                // ====================================================
                //  MOVX A, @Ri  [0xE2, 0xE3]  2 cycles
                //  P2 provides high byte; Ri provides low byte
                // ====================================================
                8'b1110001?: begin
                    if (!cycle_2) begin
                        xaddr_bus <= {p2, ri_ptr};
                        cycle_2   <= 1'b1;
                    end else begin
                        acc_preop <= acc;
                        acc       <= xdata_in;
                        cycle_2   <= 1'b0;
                    end
                end

                // ====================================================
                //  CLR A  [0xE4]  1 cycle
                // ====================================================
                8'hE4: begin
                    acc_preop <= acc;
                    acc       <= 8'h00;
                end

                // ====================================================
                //  MOV A, direct  [0xE5]  1 cycle
                // ====================================================
                8'hE5: begin // MOV A,direct  2-cycle
                        op_a  = direct_read(rom_data_latch);
                        acc  <= op_a;
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  MOV A, @Ri  [0xE6, 0xE7]  1 cycle
                // ====================================================
                8'b1110011?: begin
                    acc_preop <= acc;
                    acc       <= iram[ri_ptr[6:0]];
                end

                // ====================================================
                //  MOV A, Rn  [0xE8–0xEF]  1 cycle
                // ====================================================
                8'b11101???: begin
                    acc_preop <= acc;
                    acc       <= iram[rn_addr];
                end

                // ====================================================
                //  MOVX @DPTR, A  [0xF0]  2 cycles
                // ====================================================
                8'hF0: begin
                    if (!cycle_2) begin
                        xaddr_bus <= dptr;
                        xdata_out <= acc;
                        cycle_2   <= 1'b1;
                    end else begin
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  MOVX @Ri, A  [0xF2, 0xF3]  2 cycles
                // ====================================================
                8'b1111001?: begin
                    if (!cycle_2) begin
                        xaddr_bus <= {p2, ri_ptr};
                        xdata_out <= acc;
                        cycle_2   <= 1'b1;
                    end else begin
                        cycle_2 <= 1'b0;
                    end
                end

                // ====================================================
                //  CPL A  [0xF4]  1 cycle
                // ====================================================
                8'hF4: begin
                    acc_preop <= acc;
                    acc       <= ~acc;
                end

                // ====================================================
                //  MOV direct, A  [0xF5]  1 cycle
                // ====================================================
                8'hF5: begin // MOV direct,A  2-cycle
                        direct_write(rom_data_latch, acc);
                        pc      <= pc + 1'b1;
                    end

                // ====================================================
                //  MOV @Ri, A  [0xF6, 0xF7]  1 cycle
                // ====================================================
                8'b1111011?: begin
                    ram_preop         <= iram[ri_ptr[6:0]];
                    iram[ri_ptr[6:0]] <= acc;
                end

                // ====================================================
                //  MOV Rn, A  [0xF8–0xFF]  1 cycle
                // ====================================================
                8'b11111???: begin
                    ram_preop     <= iram[rn_addr];
                    iram[rn_addr] <= acc;
                end

                // ====================================================
                //  Default — unimplemented / undefined opcode
                // ====================================================
                default: begin
                    $display("ERROR: Unimplemented Opcode %h at PC %h", ir, pc);
                    pc <= pc + 1'b1;
                end

            endcase
        end
    endtask

endmodule
