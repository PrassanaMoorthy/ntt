module tw_rom (
    input  wire        clk,
    input  wire        algo_sel,   // 0=KEM 1=DSA
    input  wire        inv,        // reserved for inverse support; ignored for now
    input  wire [7:0]  kidx,
    output reg  [22:0] twiddle
);
    reg [11:0] tw_kem [0:127];
    reg [22:0] tw_dsa [0:255];
    initial $readmemh("twiddle_kem.mem", tw_kem);
    initial $readmemh("twiddle_dsa.mem", tw_dsa);
 
    always @(posedge clk) begin
        twiddle <= algo_sel ? tw_dsa[kidx] : {11'b0, tw_kem[kidx[6:0]]};
    end
endmodule
