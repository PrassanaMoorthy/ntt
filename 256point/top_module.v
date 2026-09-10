module top_module (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        mode,     // 0 = Forward NTT, 1 = Inverse NTT
    input  wire        ext_we,   // External write enable to load RAM
    input  wire [7:0]  ext_addr, // External host memory address
    input  wire [15:0] ext_din,  // External input coefficient data
    output wire [15:0] ext_dout, // External output coefficient data
    output wire        busy,     // NTT execution active flag
    output wire        done      // NTT execution complete flag
);

    // --- Mode Register (Latched on start) ---
    reg mode_reg;
    always @(posedge clk or posedge rst) begin
        if (rst)
            mode_reg <= 1'b0;
        else if (start && !busy)
            mode_reg <= mode;
    end

    // --- Internal Control Signals ---
    wire       fsm_ram_we;
    wire [2:0] stage;
    wire [6:0] bf_idx;

    // --- Memory & Generator Interconnects ---
    wire [7:0]  int_addr_a;
    wire [7:0]  int_addr_b;
    wire [6:0]  tw_addr;
    wire [15:0] tw_data;

    wire        ram_we_a;
    wire        ram_we_b;
    wire [7:0]  ram_addr_a;
    wire [7:0]  ram_addr_b;
    wire [15:0] ram_din_a;
    wire [15:0] ram_din_b;
    wire [15:0] ram_dout_a;
    wire [15:0] ram_dout_b;

    wire [15:0] bf_out_a;
    wire [15:0] bf_out_b;

    // --- Host / NTT Memory Multiplexing Logic ---
    assign ram_we_a   = busy ? fsm_ram_we : ext_we;
    assign ram_we_b   = busy ? fsm_ram_we : 1'b0;

    assign ram_addr_a = busy ? int_addr_a : ext_addr;
    assign ram_addr_b = busy ? int_addr_b : 8'd0;

    assign ram_din_a  = busy ? bf_out_a : ext_din;
    assign ram_din_b  = busy ? bf_out_b : 16'd0;

    assign ext_dout   = ram_dout_a;

    // --- Module Instantiations ---

    // 1. Controller FSM
    fsm u_fsm (
        .clk    (clk),
        .rst    (rst),
        .start  (start),
        .busy   (busy),
        .done   (done),
        .stage  (stage),
        .bf_idx (bf_idx),
        .ram_we (fsm_ram_we)
    );

    // 2. Address Generator
    addr_gen u_addr_gen (
        .mode    (mode_reg),
        .stage   (stage),
        .bf_idx  (bf_idx),
        .addr_a  (int_addr_a),
        .addr_b  (int_addr_b),
        .tw_addr (tw_addr)
    );

    // 3. Twiddle Factor ROM
    tw_rom u_tw_rom (
        .clk     (clk),
        .addr    (tw_addr),
        .tw_data (tw_data)
    );

    // 4. Butterfly Arithmetic Unit
    bf_unit u_bf_unit (
        .clk     (clk),
        .rst     (rst),
        .mode    (mode_reg),
        .in_a    (ram_dout_a),
        .in_b    (ram_dout_b),
        .tw_data (tw_data),
        .out_a   (bf_out_a),
        .out_b   (bf_out_b)
    );

    // 5. Dual-Port Coefficient RAM
    ram u_ram (
        .clk    (clk),
        .we_a   (ram_we_a),
        .we_b   (ram_we_b),
        .addr_a (ram_addr_a),
        .addr_b (ram_addr_b),
        .din_a  (ram_din_a),
        .din_b  (ram_din_b),
        .dout_a (ram_dout_a),
        .dout_b (ram_dout_b)
    );

endmodule
