`timescale 1ns/1ps

module r (
    input  wire        clk,

    // -------------------------
    // Port A
    // -------------------------
    input  wire        we_a,
    input  wire [7:0]  addr_a,
    input  wire [22:0] din_a,
    output reg  [22:0] dout_a,

    // -------------------------
    // Port B
    // -------------------------
    input  wire        we_b,
    input  wire [7:0]  addr_b,
    input  wire [22:0] din_b,
    output reg  [22:0] dout_b
);

    // 256 locations × 23 bits
    reg [22:0] mem [0:255];

    always @(posedge clk) begin

        // =========================
        // PORT A
        // =========================

        if (we_a)
            mem[addr_a] <= din_a;

        dout_a <= mem[addr_a];


        // =========================
        // PORT B
        // =========================

        if (we_b)
            mem[addr_b] <= din_b;

        dout_b <= mem[addr_b];

    end

endmodule
