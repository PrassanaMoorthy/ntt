module fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    output reg        busy,
    output reg        done,
    output reg  [2:0] stage,
    output reg  [6:0] bf_idx,
    output reg        ram_we
);

    // State Encoding
    localparam [2:0] STATE_IDLE  = 3'd0;
    localparam [2:0] STATE_READ  = 3'd1;
    localparam [2:0] STATE_CALC  = 3'd2;
    localparam [2:0] STATE_WRITE = 3'd3;
    localparam [2:0] STATE_DONE  = 3'd4;

    reg [2:0] state, next_state;

    // --- State Register ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // --- Next State Logic ---
    always @(*) begin
        case (state)
            STATE_IDLE: begin
                if (start)
                    next_state = STATE_READ;
                else
                    next_state = STATE_IDLE;
            end

            STATE_READ: begin
                next_state = STATE_CALC;
            end

            STATE_CALC: begin
                next_state = STATE_WRITE;
            end

            STATE_WRITE: begin
                if (bf_idx == 7'd127) begin
                    if (stage == 3'd6)
                        next_state = STATE_DONE;
                    else
                        next_state = STATE_READ;
                end else begin
                    next_state = STATE_READ;
                end
            end

            STATE_DONE: begin
                if (!start)
                    next_state = STATE_IDLE;
                else
                    next_state = STATE_DONE;
            end

            default: next_state = STATE_IDLE;
        endcase
    end

    // --- Stage and Butterfly Counters ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stage  <= 3'd0;
            bf_idx <= 7'd0;
        end else begin
            if (state == STATE_IDLE) begin
                stage  <= 3'd0;
                bf_idx <= 7'd0;
            end else if (state == STATE_WRITE) begin
                if (bf_idx == 7'd127) begin
                    bf_idx <= 7'd0;
                    if (stage < 3'd6) begin
                        stage <= stage + 3'd1;
                    end
                end else begin
                    bf_idx <= bf_idx + 7'd1;
                end
            end
        end
    end

    // --- Output Control Signals ---
    always @(*) begin
        case (state)
            STATE_IDLE: begin
                busy   = 1'b0;
                done   = 1'b0;
                ram_we = 1'b0;
            end

            STATE_READ: begin
                busy   = 1'b1;
                done   = 1'b0;
                ram_we = 1'b0;
            end

            STATE_CALC: begin
                busy   = 1'b1;
                done   = 1'b0;
                ram_we = 1'b0;
            end

            STATE_WRITE: begin
                busy   = 1'b1;
                done   = 1'b0;
                ram_we = 1'b1; // Trigger write to RAM
            end

            STATE_DONE: begin
                busy   = 1'b0;
                done   = 1'b1;
                ram_we = 1'b0;
            end

            default: begin
                busy   = 1'b0;
                done   = 1'b0;
                ram_we = 1'b0;
            end
        endcase
    end

endmodule
