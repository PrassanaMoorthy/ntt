module pbf #(
    parameter W = 8,
    parameter Q = 17
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire [W-1:0] a_in,
    input  wire [W-1:0] b_in,
    input  wire [W-1:0] w_in,
    input  wire         valid_in,
    output reg  [W-1:0] a_out,
    output reg  [W-1:0] b_out,
    output reg           valid_out
);
    wire [2*W-1:0] prod = w_in * b_in;
    wire [W-1:0]   t    = prod % Q;
    wire [W:0]     sum_a = a_in + t;
    wire [W:0]     sum_b = a_in + Q - t;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= 0; b_out <= 0; valid_out <= 0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                a_out <= sum_a % Q;
                b_out <= sum_b % Q;
            end
        end
    end
endmodule