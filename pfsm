module pfsm (
    input  wire clk, rst_n, start,
    input  wire ag_done,
    output reg  ag_start, ag_adv, bf_valid_in, ram_we,
    output reg  busy, done
);
    localparam S_IDLE=0, S_ISSUE=1, S_WAIT_MEM=2, S_WAIT_BF=3, S_WRITE=4, S_DONE=5;
    reg [2:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=S_IDLE; ag_start<=0; ag_adv<=0; bf_valid_in<=0; ram_we<=0; busy<=0; done<=0;
        end else begin
            ag_start<=0; ag_adv<=0; bf_valid_in<=0; ram_we<=0; done<=0;
            case (state)
                S_IDLE:      if (start) begin ag_start<=1; busy<=1; state<=S_ISSUE; end
                S_ISSUE:     state <= S_WAIT_MEM;             // ram/rom read latency
                S_WAIT_MEM:  begin bf_valid_in<=1; state<=S_WAIT_BF; end
                S_WAIT_BF:   state <= S_WRITE;                // bf latency
                S_WRITE:     begin
                                 ram_we <= 1;
                                 if (ag_done) state <= S_DONE;
                                 else begin ag_adv<=1; state<=S_ISSUE; end
                             end
                S_DONE:      begin busy<=0; done<=1; state<=S_IDLE; end
            endcase
        end
    end
endmodule