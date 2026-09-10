module pntt (
    input  wire        clk, rst_n, start,
    input  wire        load_we,
    input  wire [2:0]  load_addr,
    input  wire [7:0]  load_data,
    output wire         busy, done,
    output wire [7:0]   rd_data_a, rd_data_b
);
    localparam N=8, LOGN=3, W=8, Q=17;
    wire [LOGN-1:0] ja, jb, kidx;
    wire ag_done, ag_start, ag_adv;
    wire [W-1:0] ram_dout_a, ram_dout_b, tw, bf_a_out, bf_b_out;
    wire bf_valid_in, ram_we_fsm;

    wire [LOGN-1:0] ram_addr_a = load_we ? load_addr : ja;
    wire [LOGN-1:0] ram_addr_b = load_we ? load_addr : jb;
    wire [W-1:0]    ram_din_a  = load_we ? load_data : bf_a_out;
    wire [W-1:0]    ram_din_b  = load_we ? load_data : bf_b_out;
    wire            ram_we     = load_we | ram_we_fsm;

    paddr #(.N(N), .LOGN(LOGN)) u_ag (
        .clk(clk), .rst_n(rst_n), .start(ag_start), .adv(ag_adv),
        .length(), .start_g(), .j(), .kidx(kidx), .ja(ja), .jb(jb),
        .valid(), .done(ag_done));

    pram #(.N(N), .LOGN(LOGN), .W(W)) u_ram (
        .clk(clk), .we(ram_we), .addr_a(ram_addr_a), .addr_b(ram_addr_b),
        .din_a(ram_din_a), .din_b(ram_din_b), .dout_a(ram_dout_a), .dout_b(ram_dout_b));

    prom #(.LOGN(LOGN), .W(W)) u_tw (.clk(clk), .kidx(kidx), .twiddle(tw));

    pbf #(.W(W), .Q(Q)) u_bf (
        .clk(clk), .rst_n(rst_n), .a_in(ram_dout_a), .b_in(ram_dout_b), .w_in(tw),
        .valid_in(bf_valid_in), .a_out(bf_a_out), .b_out(bf_b_out), .valid_out());

    pfsm u_fsm (
        .clk(clk), .rst_n(rst_n), .start(start), .ag_done(ag_done),
        .ag_start(ag_start), .ag_adv(ag_adv), .bf_valid_in(bf_valid_in),
        .ram_we(ram_we_fsm), .busy(busy), .done(done));

    assign rd_data_a = ram_dout_a;
    assign rd_data_b = ram_dout_b;
endmodule