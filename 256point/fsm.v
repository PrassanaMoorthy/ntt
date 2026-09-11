module fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire       mode,        // 0 = Forward NTT, 1 = Inverse NTT (NEW: needed to gate the scale pass)
    output reg        busy,
    output reg        done,
    output reg  [2:0] stage,
    output reg  [6:0] bf_idx,
    output reg        ram_we,
    output reg        scale_active,  // NEW: high during the n^-1 normalization pass
    output reg  [7:0] scale_addr     // NEW: single RAM address for the normalization pass
);

    // State Encoding
    localparam [2:0] STATE_IDLE       = 3'd0;
    localparam [2:0] STATE_READ       = 3'd1;
    localparam [2:0] STATE_CALC       = 3'd2;
    localparam [2:0] STATE_WRITE      = 3'd3;
    localparam [2:0] STATE_SCALE_RD   = 3'd4;
    localparam [2:0] STATE_SCALE_CALC = 3'd5;
    localparam [2:0] STATE_SCALE_WR   = 3'd6;
    localparam [2:0] STATE_DONE       = 3'd7;

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
                    if (stage == 3'd6) begin
                        // NEW: inverse NTT falls through to the scale pass;
                        // forward NTT goes straight to DONE as before.
                        next_state = mode ? STATE_SCALE_RD : STATE_DONE;
                    end else begin
                        next_state = STATE_READ;
                    end
                end else begin
                    next_state = STATE_READ;
                end
            end

            // --- NEW: n^-1 mod q normalization pass (inverse NTT only) ---
            STATE_SCALE_RD: begin
                next_state = STATE_SCALE_CALC;
            end

            STATE_SCALE_CALC: begin
                next_state = STATE_SCALE_WR;
            end

            STATE_SCALE_WR: begin
                if (scale_addr == 8'd255)
                    next_state = STATE_DONE;
                else
                    next_state = STATE_SCALE_RD;
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

    // --- NEW: Scale-pass address counter ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scale_addr <= 8'd0;
        end else if (state == STATE_IDLE) begin
            scale_addr <= 8'd0;
        end else if (state == STATE_SCALE_WR) begin
            if (scale_addr != 8'd255)
                scale_addr <= scale_addr + 8'd1;
        end
    end

    // --- Output Control Signals ---
    always @(*) begin
        case (state)
            STATE_IDLE: begin
                busy         = 1'b0;
                done         = 1'b0;
                ram_we       = 1'b0;
                scale_active = 1'b0;
            end

            STATE_READ: begin
                busy         = 1'b1;
                done         = 1'b0;
                ram_we       = 1'b0;
                scale_active = 1'b0;
            end

            STATE_CALC: begin
                busy         = 1'b1;
                done         = 1'b0;
                ram_we       = 1'b0;
                scale_active = 1'b0;
            end

            STATE_WRITE: begin
                busy         = 1'b1;
                done         = 1'b0;
                ram_we       = 1'b1; // Trigger write to RAM
                scale_active = 1'b0;
            end

            STATE_SCALE_RD: begin
                busy         = 1'b1;
                done         = 1'b0;
                ram_we       = 1'b0;
                scale_active = 1'b1;
            end

            STATE_SCALE_CALC: begin
                busy         = 1'b1;
                done         = 1'b0;
                ram_we       = 1'b0;
                scale_active = 1'b1;
            end

            STATE_SCALE_WR: begin
                busy         = 1'b1;
                done         = 1'b0;
                ram_we       = 1'b1; // Trigger write to RAM
                scale_active = 1'b1;
            end

            STATE_DONE: begin
                busy         = 1'b0;
                done         = 1'b1;
                ram_we       = 1'b0;
                scale_active = 1'b0;
            end

            default: begin
                busy         = 1'b0;
                done         = 1'b0;
                ram_we       = 1'b0;
                scale_active = 1'b0;
            end
        endcase
    end

endmodule
