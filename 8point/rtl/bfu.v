// ---------------------------------------------------------------------------
// bfu - single radix-2 butterfly:
//   t      = zeta * b_in   mod Q
//   a_out  = a_in + t      mod Q
//   b_out  = a_in - t      mod Q
// Purely combinational; the FSM/RAM around it turns this into one butterfly
// per clock cycle.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// bfu - single radix-2 butterfly
//
// t      = zeta * b_in mod Q
// a_out  = a_in + t mod Q
// b_out  = a_in - t mod Q
//
// All arithmetic is contained inside this single module.
// Purely combinational.
//
// Inputs : a_in, b_in, zeta
// Outputs: a_out, b_out
// ---------------------------------------------------------------------------

module bfu #(
    parameter Q = 3329,
    parameter W = 12
) (
    input  [W-1:0] a_in,
    input  [W-1:0] b_in,
    input  [W-1:0] zeta,
    output [W-1:0] a_out,
    output [W-1:0] b_out
);

    // ============================================================
    // Intermediate values
    // ============================================================

    // Full multiplication result
    wire [(2*W)-1:0] mult;

    // t = zeta * b_in mod Q
    wire [W-1:0] t;

    // Addition/subtraction temporary values
    wire [W:0] add_temp;
    wire [W:0] sub_temp;


    // ============================================================
    // 1. Modular multiplication
    // ============================================================

    assign mult = zeta * b_in;

    assign t = mult % Q;


    // ============================================================
    // 2. Modular addition
    //
    // a_out = (a_in + t) mod Q
    // ============================================================

    assign add_temp = {1'b0, a_in} + {1'b0, t};

    assign a_out = (add_temp >= Q) ?
                   (add_temp - Q) :
                   add_temp[W-1:0];


    // ============================================================
    // 3. Modular subtraction
    //
    // b_out = (a_in - t) mod Q
    // ============================================================

    assign sub_temp = {1'b0, a_in} + Q - {1'b0, t};

    assign b_out = (a_in >= t) ?
                   (a_in - t) :
                   sub_temp[W-1:0];

endmodule