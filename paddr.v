module paddr #(
    parameter N    = 8,
    parameter LOGN = 3
)(
    input  wire            clk,
    input  wire            rst_n,
    input  wire            start,
    input  wire            adv,
    output reg  [LOGN-1:0] length,
    output reg  [LOGN-1:0] start_g,
    output reg  [LOGN-1:0] j,
    output reg  [LOGN-1:0] kidx,
    output wire [LOGN-1:0] ja,
    output wire [LOGN-1:0] jb,
    output reg             valid,
    output reg             done
);
    assign ja = j;
    assign jb = j + length;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            length  <= N/2;
            start_g <= 0;
            j       <= 0;
            kidx    <= 1;
            valid   <= 0;
            done    <= 0;
        end else begin
            done <= 0;
            if (start) begin
                length  <= N/2;
                start_g <= 0;
                j       <= 0;
                kidx    <= 1;
                valid   <= 1;
            end else if (adv && valid) begin
                if (j + 1 < start_g + length) begin
                    j <= j + 1;
                end else begin
                    kidx <= kidx + 1;
                    if (start_g + 2*length < N) begin
                        start_g <= start_g + 2*length;
                        j       <= start_g + 2*length;
                    end else if (length > 1) begin
                        length  <= length >> 1;
                        start_g <= 0;
                        j       <= 0;
                    end else begin
                        valid <= 0;
                        done  <= 1;
                    end
                end
            end
        end
    end
endmodule