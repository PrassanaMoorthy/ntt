module prom #(
    parameter LOGN = 3,
    parameter W    = 8
)(
    input  wire             clk,
    input  wire [LOGN-1:0]  kidx,
    output reg  [W-1:0]     twiddle
);
    reg [W-1:0] tw [0:(1<<LOGN)-1];
    initial $readmemh("twiddle8.mem", tw);

    always @(posedge clk)
        twiddle <= tw[kidx];
endmodule