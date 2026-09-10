module ntt_ram (
    input  wire        clk,

    input  wire [7:0]  addr_a,
    input  wire [22:0] din_a,
    input  wire        we_a,
    output reg  [22:0] dout_a,

    input  wire [7:0]  addr_b,
    input  wire [22:0] din_b,
    input  wire        we_b,
    output reg  [22:0] dout_b,

    input  wire [7:0]  rd_addr,
    output reg  [22:0] rd_data
);

    reg [22:0] mem [0:255];

    always @(posedge clk) begin

        if (we_a)
            mem[addr_a] <= din_a;

        if (we_b && !(we_a && (addr_b == addr_a)))
            mem[addr_b] <= din_b;

        if (we_a)
            dout_a <= din_a;
        else
            dout_a <= mem[addr_a];

        if (we_b)
            dout_b <= din_b;
        else
            dout_b <= mem[addr_b];

        if (we_a && (rd_addr == addr_a))
            rd_data <= din_a;
        else if (we_b && (rd_addr == addr_b))
            rd_data <= din_b;
        else
            rd_data <= mem[rd_addr];

    end

endmodule
