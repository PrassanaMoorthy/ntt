// ---------------------------------------------------------------------------
// addr_gen - iterates through all butterflies of a size-8, in-place, radix-2
// DIT NTT (natural-order input via bit-reversed loading, natural-order
// output). Three nested loops, innermost first:
//
//   for stage in 0..2:                 // m = 2<<stage   (2,4,8)
//     half = 1<<stage                  // 1,2,4
//     n_groups = N/m = 4>>stage        // 4,2,1
//     for group in 0..n_groups-1:
//       k = group*m
//       for j in 0..half-1:
//         addr_a = k + j
//         addr_b = addr_a + half
//         twiddle exponent = j * (N/m) = j * (4>>stage)   // always 0..3
//
// 4 + 4 + 4 = 12 butterflies total, one per cycle (pulse 'adv').
// Counters freeze once the last butterfly (stage2, only group, j=half-1)
// has been presented, so the FSM has a full cycle to sample last_bf and
// move to DONE.
// ---------------------------------------------------------------------------
module addr_gen #(
    parameter AW   = 3,
    parameter TW   = 2
) (
    input                clk,
    input                rst_n,
    input                init,      // sync: reset counters to (0,0,0)
    input                adv,       // pulse: consume this butterfly, advance

    output     [AW-1:0]  addr_a,
    output     [AW-1:0]  addr_b,
    output     [TW-1:0]  tw_addr,   // twiddle exponent, 0..3
    output                last_bf   // high while presenting the final (12th) butterfly
);
    reg [1:0] stage;  // 0,1,2   -> m = 2,4,8 ; half = 1,2,4
    reg [1:0] group;  // 0..3    -> which block within the stage
    reg [1:0] j;      // 0..3    -> position within the block

    wire [3:0] m         = 4'd2 << stage;                 // 2,4,8
    wire [3:0] half      = 4'd1 << stage;                 // 1,2,4
    wire [3:0] n_groups  = 4'd4 >> stage;                 // 4,2,1
    wire [3:0] half_m1   = half     - 4'd1;
    wire [3:0] ngrp_m1   = n_groups - 4'd1;

    wire [6:0] addr_a_w  = ({5'b0, group} * m) + {5'b0, j};
    wire [6:0] addr_b_w  = addr_a_w + half;
    wire [3:0] tw_exp_w  = {2'b0, j} * (4'd4 >> stage);

    assign addr_a  = addr_a_w[AW-1:0];
    assign addr_b  = addr_b_w[AW-1:0];
    assign tw_addr = tw_exp_w[TW-1:0];

    assign last_bf = (stage == 2'd2) &&
                      (group == ngrp_m1[1:0]) &&
                      (j     == half_m1[1:0]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage <= 0; group <= 0; j <= 0;
        end else if (init) begin
            stage <= 0; group <= 0; j <= 0;
        end else if (adv && !last_bf) begin
            if (j == half_m1[1:0]) begin
                j <= 0;
                if (group == ngrp_m1[1:0]) begin
                    group <= 0;
                    stage <= stage + 2'd1;
                end else begin
                    group <= group + 2'd1;
                end
            end else begin
                j <= j + 2'd1;
            end
        end
    end
endmodule
