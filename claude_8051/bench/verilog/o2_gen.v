// ----------------------------------------------------------------
//  O2 / Lambda sensor simulator
//
//  Models a Bosch narrowband lambda sensor oscillating around
//  stoichiometry (lambda = 1.0).
//
//  Signal mapping on 89 DME 951:
//    P1.6 (o2_bottom) = sensor voltage → 1 = rich, 0 = lean
//    P1.7 (o2_top)    = sensor voltage → 1 = rich, 0 = lean
//
//  Phases:
//    Rich (0):      ~0.9V  → P1.6=1, P1.7=1  (250ms)
//    Crossover (2): ~0.5V  → P1.6=1, P1.7=0  ( 17ms, rich→lean transition)
//    Lean (1):      ~0.1V  → P1.6=0, P1.7=0  (250ms)
//
//  Total cycle ≈ 517ms.  Equal rich/lean times give balanced
//  lambda integrator correction.
//
//  At 6MHz: 1 clock = 167ns
//    250ms = 1,500,000 clocks
//     17ms =   100,000 clocks
// ----------------------------------------------------------------

module o2_generator (
    input  wire clk,
    input  wire rst,
    output reg  o2_top,     // P1.7: 1=rich, 0=lean
    output reg  o2_bottom   // P1.6: 1=rich, 0=lean (also high during crossover)
);

localparam RICH_CLKS       = 22'd1_500_000;  // 250ms
localparam CROSSOVER_CLKS  = 22'd100_000;    //  17ms
localparam LEAN_CLKS       = 22'd1_500_000;  // 250ms

localparam PHASE_RICH      = 2'd0;
localparam PHASE_CROSSOVER = 2'd2;
localparam PHASE_LEAN      = 2'd1;

reg [1:0]  lambda_phase;
reg [21:0] lambda_cnt;

always @(posedge clk) begin
    if (!rst) begin
        lambda_phase <= PHASE_RICH;
        lambda_cnt   <= 22'd0;
        o2_top       <= 1'b1;   // start rich
        o2_bottom    <= 1'b1;
    end else begin
        lambda_cnt <= lambda_cnt + 1'b1;

        case (lambda_phase)
            PHASE_RICH:
                if (lambda_cnt == RICH_CLKS - 1) begin
                    lambda_phase <= PHASE_CROSSOVER;
                    lambda_cnt   <= 22'd0;
                end
            PHASE_CROSSOVER:
                if (lambda_cnt == CROSSOVER_CLKS - 1) begin
                    lambda_phase <= PHASE_LEAN;
                    lambda_cnt   <= 22'd0;
                end
            PHASE_LEAN:
                if (lambda_cnt == LEAN_CLKS - 1) begin
                    lambda_phase <= PHASE_RICH;
                    lambda_cnt   <= 22'd0;
                end
            default:
                lambda_phase <= PHASE_RICH;
        endcase

        // Rich=1, Lean=0; crossover: bottom stays high, top goes low
        o2_bottom <= (lambda_phase == PHASE_RICH) ||
                     (lambda_phase == PHASE_CROSSOVER);
        o2_top    <= (lambda_phase == PHASE_RICH);
    end
end

endmodule
