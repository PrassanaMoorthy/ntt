module pram #(
    parameter N    = 8,
    parameter LOGN = 3,
    parameter W    = 8
)(
    input  wire            clk,
    input  wire            we,
    input  wire [LOGN-1:0] addr_a,
    input  wire [LOGN-1:0] addr_b,
    input  wire [W-1:0]    din_a,
    input  wire [W-1:0]    din_b,
    output reg  [W-1:0]    dout_a,
    output reg  [W-1:0]    dout_b
);
    reg [W-1:0] mem [0:N-1];

    always @(posedge clk) begin
        dout_a <= mem[addr_a];
        dout_b <= mem[addr_b];
        if (we) begin
            mem[addr_a] <= din_a;
            mem[addr_b] <= din_b;
        end
    end
endmodule