module ram (
    input  wire        clk,
    input  wire        we_a,
    input  wire        we_b,
    input  wire [7:0]  addr_a,
    input  wire [7:0]  addr_b,
    input  wire [15:0] din_a,
    input  wire [15:0] din_b,
    output reg  [15:0] dout_a,
    output reg  [15:0] dout_b
);

    // 256 x 16-bit memory array
    reg [15:0] mem [0:255];

    // Port A Read/Write Operation
    always @(posedge clk) begin
        if (we_a) begin
            mem[addr_a] <= din_a;
            dout_a      <= din_a; // Write-first mode
        end else begin
            dout_a      <= mem[addr_a];
        end
    end

    // Port B Read/Write Operation
    always @(posedge clk) begin
        if (we_b) begin
            mem[addr_b] <= din_b;
            dout_b      <= din_b; // Write-first mode
        end else begin
            dout_b      <= mem[addr_b];
        end
    end

endmodule
