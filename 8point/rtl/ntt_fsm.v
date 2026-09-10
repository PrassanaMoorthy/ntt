`timescale 1ns/1ps

module ntt_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire last_bf,

    output reg init,
    output reg adv,
    output reg run,
    output reg done
);

    localparam S_IDLE = 2'd0,
               S_RUN  = 2'd1,
               S_DONE = 2'd2;

    reg [1:0] state, nstate;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= nstate;
    end

    // Next-state and output logic
    always @(*) begin

        // Defaults
        nstate = state;

        init = 1'b0;
        adv  = 1'b0;
        run  = 1'b0;
        done = 1'b0;

        case (state)

            // ------------------------------------------------
            // IDLE
            // ------------------------------------------------
            S_IDLE: begin

                if (start) begin
                    init   = 1'b1;
                    nstate = S_RUN;
                end

            end


            // ------------------------------------------------
            // RUN
            // ------------------------------------------------
            S_RUN: begin

                // Keep datapath active
                run = 1'b1;

                // Advance address generator every cycle
                adv = 1'b1;

                // Last butterfly?
                if (last_bf)
                    nstate = S_DONE;

            end


            // ------------------------------------------------
            // DONE
            // ------------------------------------------------
            S_DONE: begin

                done = 1'b1;

                // Allow a new NTT
                if (start) begin
                    init   = 1'b1;
                    nstate = S_RUN;
                end

            end


            default: begin
                nstate = S_IDLE;
            end

        endcase

    end

endmodule