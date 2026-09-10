module bf_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire        mode,     // 0 = CT Butterfly, 1 = GS Butterfly
    input  wire [15:0] in_a,
    input  wire [15:0] in_b,
    input  wire [15:0] tw_data,
    output reg  [15:0] out_a,
    output reg  [15:0] out_b
);

    // --- Kyber Parameters ---
    localparam [15:0] Q     = 16'd3329;
    localparam [15:0] Q_INV = 16'd62209; // -q^-1 mod 2^16

    // --- Constant-Time Montgomery Reduction Function ---
    // Computes (val * R^-1) mod Q where R = 2^16
    function [15:0] montgomery;
        input [31:0] val;
        reg   [15:0] m;
        reg   [31:0] t;
        reg   [16:0] t_sub;
        begin
            m     = val[15:0] * Q_INV;          // m = (val mod 2^16) * Q_INV mod 2^16
            t     = (val + m * Q) >> 16;        // t = (val + m * Q) / 2^16
            t_sub = t - Q;                      // Constant-time bound check
            montgomery = t_sub[16] ? t[15:0] : t_sub[15:0];
        end
    endfunction

    // --- Modular Addition: (x + y) mod Q ---
    function [15:0] mod_add;
        input [15:0] x, y;
        reg   [16:0] sum;
        reg   [16:0] sum_sub;
        begin
            sum     = x + y;
            sum_sub = sum - Q;
            mod_add = sum_sub[16] ? sum[15:0] : sum_sub[15:0];
        end
    endfunction

    // --- Modular Subtraction: (x - y) mod Q ---
    function [15:0] mod_sub;
        input [15:0] x, y;
        reg   [16:0] diff;
        begin
            diff    = (x >= y) ? (x - y) : (x + Q - y);
            mod_sub = diff[15:0];
        end
    endfunction

    // --- Combinational Butterfly Computations ---
    reg [31:0] mult_in;
    reg [15:0] mont_res;
    reg [15:0] next_out_a;
    reg [15:0] next_out_b;

    wire [15:0] diff_ab = mod_sub(in_a, in_b);

    always @(*) begin
        if (mode == 1'b0) begin
            // Cooley-Tukey (CT) Forward Butterfly:
            // A' = A + (B * W),  B' = A - (B * W)
            mult_in    = in_b * tw_data;
            mont_res   = montgomery(mult_in);
            next_out_a = mod_add(in_a, mont_res);
            next_out_b = mod_sub(in_a, mont_res);
        end else begin
            // Gentleman-Sande (GS) Inverse Butterfly:
            // A' = A + B,        B' = (A - B) * W
            mult_in    = diff_ab * tw_data;
            mont_res   = montgomery(mult_in);
            next_out_a = mod_add(in_a, in_b);
            next_out_b = mont_res;
        end
    end

    // --- Synchronous Registered Outputs ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_a <= 16'd0;
            out_b <= 16'd0;
        end else begin
            out_a <= next_out_a;
            out_b <= next_out_b;
        end
    end

endmodule
