module addr_gen (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire       algo_sel,
    input  wire       adv,
    output reg  [7:0] length,
    output reg  [7:0] kidx,
    output reg  [7:0] j,
    output wire [7:0] ja,
    output wire [7:0] jb,
    output reg        valid,
    output reg        done
);
    reg [7:0] start_g;
    reg       algo_r;
    wire [7:0] stop = algo_r ? 8'd1 : 8'd2;
    assign ja = j;
    assign jb = j + length;

    wire [8:0] len2 = {1'b0, length} + {1'b0, length};  // exact 2*length, no wrap

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            length  <= 8'd128;
            kidx    <= 8'd1;
            j       <= 8'd0;
            start_g <= 8'd0;
            valid   <= 1'b0;
            done    <= 1'b0;
            algo_r  <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start) begin
                algo_r  <= algo_sel;
                length  <= 8'd128;
                kidx    <= 8'd1;
                start_g <= 8'd0;
                j       <= 8'd0;
                valid   <= 1'b1;
            end else if (adv && valid) begin
                if (j + 1 < start_g + length) begin
                    j <= j + 1;
                end else begin
                    kidx <= kidx + 1;
                    if ({1'b0, start_g} + len2 < 9'd256) begin
                        start_g <= start_g + len2[7:0];
                        j       <= start_g + len2[7:0];
                    end else if ((length >> 1) >= stop) begin
                        length  <= length >> 1;
                        start_g <= 8'd0;
                        j       <= 8'd0;
                    end else begin
                        valid <= 1'b0;
                        done  <= 1'b1;
                    end
                end
            end
        end
    end
endmodule
