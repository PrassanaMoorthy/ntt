module ntt_ram (
    input  wire        clk,
    
    input  wire [7:0]  addr_a,
    input wire [22:0] din_a,
    input wire we_a,
    output reg [22:0] dout_a,

    input  wire [7:0]  addr_b, 
    input wire [22:0] din_b, 
    input wire we_b, 
    output reg [22:0] dout_b,

    input  wire [7:0]  rd_addr,
    output reg  [22:0] rd_data 
);
    reg [22:0] mem [0:255];

    always @(posedge clk) begin
        if (we_a) mem[addr_a] <= din_a;
        dout_a <= we_a ? din_a : mem[addr_a];
    end

    always @(posedge clk) begin
        if (we_b) mem[addr_b] <= din_b;
        dout_b <= we_b ? din_b : mem[addr_b];
    end

    always @(posedge clk)
        rd_data <= mem[rd_addr];       
endmodule
