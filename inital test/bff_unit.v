module bff_unit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [22:0] a_in,
    input  wire [22:0] b_in,
    input  wire [22:0] w_in,
    input  wire        algo_sel,  
    input  wire        mode,       
    input  wire        valid_in,
    output reg  [22:0] a_out,
    output reg  [22:0] b_out,
    output reg          valid_out
);
    localparam [22:0] Q_KEM = 23'd3329;
    localparam [22:0] Q_DSA = 23'd8380417;
    
    wire [22:0] Qsel = algo_sel ? Q_DSA : Q_KEM;
   
    wire [45:0] prod = w_in * b_in;
    wire [22:0] t    = prod % Qsel;
   
    wire [23:0] sum_a = {1'b0, a_in} + {1'b0, t};
    wire [23:0] sum_b = {1'b0, a_in} + {1'b0, Qsel} - {1'b0, t};
   
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out     <= 23'd0;
            b_out     <= 23'd0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                a_out <= sum_a % Qsel;
                b_out <= sum_b % Qsel;
            end
        end
    end
endmodule
