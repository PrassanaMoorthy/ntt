// ---------------------------------------------------------------------------
// ntt_top - 8-point iterative NTT over Z_3329 (Kyber prime), single
// reusable butterfly unit, FSM-controlled, one butterfly per clock.
//
// Usage:
//   1. While idle (or done), drive ld_en=1 for 8 cycles, presenting
//      ld_addr = 0..7 (NATURAL index) and ld_data = coefficient. The
//      bit-reversal needed by the algorithm is applied internally.
//   2. Pulse start=1 for one cycle.
//   3. Wait for done=1 (12 cycles later).
//   4. Read results with rd_addr = 0..7 (NATURAL index, no reversal
//      needed on the way out) -> rd_data.
// ---------------------------------------------------------------------------
module ntt_top #(
    parameter Q  = 3329,
    parameter W  = 12,
    parameter AW = 3,
    parameter TW = 2
) (
    input               clk,
    input               rst_n,

    // load interface (natural-order index)
    input               ld_en,
    input  [AW-1:0]     ld_addr,
    input  [W-1:0]      ld_data,

    // control
    input               start,
    output              done,

    // read interface (natural-order index)
    input  [AW-1:0]     rd_addr,
    output [W-1:0]      rd_data
);
    // ---- FSM ----------------------------------------------------------
    wire init, adv, run, last_bf;
    ntt_fsm u_fsm (
        .clk(clk), .rst_n(rst_n), .start(start), .last_bf(last_bf),
        .init(init), .adv(adv), .run(run), .done(done)
    );

    // ---- address generation --------------------------------------------
    wire [AW-1:0] addr_a, addr_b;
    wire [TW-1:0] tw_addr;
    addr_gen #(.AW(AW), .TW(TW)) u_ag (
        .clk(clk), .rst_n(rst_n), .init(init), .adv(adv),
        .addr_a(addr_a), .addr_b(addr_b), .tw_addr(tw_addr), .last_bf(last_bf)
    );

    // ---- twiddle ROM ------------------------------------------------
    wire [W-1:0] zeta;
    twiddle_rom #(.Q(Q), .W(W), .TW(TW)) u_rom (.addr(tw_addr), .zeta(zeta));

    // ---- bit-reversal of the natural load address --------------------
    wire [AW-1:0] ld_addr_rev;
    bitrev3 u_brev (.addr_in(ld_addr), .addr_out(ld_addr_rev));

    // ---- memory read/write muxing -------------------------------------
    wire [AW-1:0] raddr_a = run ? addr_a : rd_addr;
    wire [AW-1:0] raddr_b = run ? addr_b : rd_addr;
    wire [W-1:0]  data_a, data_b;

    wire [W-1:0]  bfu_a_out, bfu_b_out;
    bfu #(.Q(Q), .W(W)) u_bfu (
        .a_in(data_a), .b_in(data_b), .zeta(zeta),
        .a_out(bfu_a_out), .b_out(bfu_b_out)
    );

    wire          we_a    = run ? 1'b1      : ld_en;
    wire          we_b    = run;
    wire [AW-1:0] waddr_a = run ? addr_a    : ld_addr_rev;
    wire [AW-1:0] waddr_b = addr_b;
    wire [W-1:0]  wdata_a = run ? bfu_a_out : ld_data;
    wire [W-1:0]  wdata_b = bfu_b_out;

    coeff_mem #(.W(W), .AW(AW), .DEPTH(8)) u_mem (
        .clk(clk),
        .we_a(we_a), .waddr_a(waddr_a), .wdata_a(wdata_a),
        .we_b(we_b), .waddr_b(waddr_b), .wdata_b(wdata_b),
        .raddr_a(raddr_a), .rdata_a(data_a),
        .raddr_b(raddr_b), .rdata_b(data_b)
    );

    assign rd_data = data_a;
endmodule
