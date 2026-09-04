`timescale 1ns/1ps

module ntt_engine_fwd (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        algo_sel,     
    output reg          busy,
    output reg          done,
    input  wire        wr_en,
    input  wire [7:0]  wr_addr,
    input  wire [22:0] wr_data,
    input  wire [7:0]  rd_addr,
    output wire [22:0] rd_data
);
    // ---- RAM ----
    reg  [7:0]  addr_a, addr_b;
    reg  [22:0] din_a,  din_b;
    reg         we_a,   we_b;
    wire [22:0] dout_a, dout_b;

    ntt_ram u_ram (
        .clk(clk),
        .addr_a(addr_a), .din_a(din_a), .we_a(we_a), .dout_a(dout_a),
        .addr_b(addr_b), .din_b(din_b), .we_b(we_b), .dout_b(dout_b),
        .rd_addr(rd_addr), .rd_data(rd_data)
    );

    // ---- twiddle ROM ----
    wire [22:0] twiddle;
    wire [7:0]  ag_kidx;

    twiddle_rom u_rom (
        .clk(clk), .algo_sel(algo_sel), .inv(1'b0),
        .kidx(ag_kidx), .twiddle(twiddle)
    );

    // ---- address generator ----
    wire [7:0] ag_length, ag_j, ag_ja, ag_jb;
    wire       ag_valid, ag_done;
    reg        ag_start, ag_adv;

    ntt_addr_gen u_addrgen (
        .clk(clk), .rst_n(rst_n),
        .start(ag_start), .algo_sel(algo_sel), .adv(ag_adv),
        .length(ag_length), .kidx(ag_kidx), .j(ag_j),
        .ja(ag_ja), .jb(ag_jb), .valid(ag_valid), .done(ag_done)
    );

    // ---- butterfly ----
    reg         bf_vin;
    reg  [22:0] bf_a, bf_b, bf_w;
    wire [22:0] bf_ao, bf_bo;
    wire        bf_vo;

    bf_unit u_bf (
        .clk(clk), .rst_n(rst_n),
        .a_in(bf_a), .b_in(bf_b), .w_in(bf_w),
        .algo_sel(algo_sel), .mode(1'b0), .valid_in(bf_vin),
        .a_out(bf_ao), .b_out(bf_bo), .valid_out(bf_vo)
    );

    // ---- control FSM ----
    localparam S_IDLE=0, S_RD=1, S_WAITMEM=2, S_FEED=3, S_WAITBF=4, S_NEXT=5, S_CHECK=6, S_DONE=7;
    reg [2:0] state;
    reg [7:0] ja_r, jb_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=S_IDLE; busy<=0; done<=0;
            we_a<=0; we_b<=0; bf_vin<=0; ag_start<=0; ag_adv<=0;
        end else begin
            done<=0; we_a<=0; we_b<=0; bf_vin<=0; ag_start<=0; ag_adv<=0;
            case (state)
            S_IDLE: begin
                busy<=0;
                if (wr_en) begin addr_a<=wr_addr; din_a<=wr_data; we_a<=1; end
                if (start) begin
                    busy<=1; ag_start<=1;
                    state<=S_RD;
                end
            end
            S_RD: begin
                ja_r<=ag_ja; jb_r<=ag_jb;
                addr_a<=ag_ja; addr_b<=ag_jb;
                state<=S_WAITMEM;
            end
            S_WAITMEM: begin
                state<=S_FEED;
            end
            S_FEED: begin
                bf_a<=dout_a; bf_b<=dout_b; bf_w<=twiddle; bf_vin<=1;
                state<=S_WAITBF;
            end
            S_WAITBF: begin
                if (bf_vo) begin
                    addr_a<=ja_r; din_a<=bf_ao; we_a<=1;
                    addr_b<=jb_r; din_b<=bf_bo; we_b<=1;
                    ag_adv<=1;
                    state<=S_NEXT;
                end
            end
            S_NEXT: begin
                
                state<=S_CHECK;
            end
            S_CHECK: begin
                if (ag_done) state<=S_DONE;
                else if (ag_valid) state<=S_RD;
            end
            S_DONE: begin
                busy<=0; done<=1; state<=S_IDLE;
            end
            endcase
        end
    end
endmodule
