// ---------------------------------------------------------------------------
// coeff_mem - 8 x 12-bit coefficient store, 2 read ports + 2 write ports.
// A radix-2 in-place butterfly touches two coefficients per cycle (read
// both, then write both back), so a single conventional 1R1W RAM can't do
// it in one cycle -- hence the 2R2W arrangement. Reads are asynchronous
// (combinational), writes are synchronous, which is standard for a small
// register-file-style memory like this.
// ---------------------------------------------------------------------------
module coeff_mem #(
    parameter W     = 12,
    parameter AW    = 3,
    parameter DEPTH = 8
) (
    input                clk,

    input                we_a,
    input      [AW-1:0]  waddr_a,
    input      [W-1:0]   wdata_a,

    input                we_b,
    input      [AW-1:0]  waddr_b,
    input      [W-1:0]   wdata_b,

    input      [AW-1:0]  raddr_a,
    output     [W-1:0]   rdata_a,

    input      [AW-1:0]  raddr_b,
    output     [W-1:0]   rdata_b
);
    reg [W-1:0] mem [0:DEPTH-1];

    assign rdata_a = mem[raddr_a];
    assign rdata_b = mem[raddr_b];

    always @(posedge clk) begin
        if (we_a) mem[waddr_a] <= wdata_a;
        if (we_b) mem[waddr_b] <= wdata_b;
    end
endmodule
