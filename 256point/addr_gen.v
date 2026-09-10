module addr_gen (
    input  wire        mode,    // 0 = Forward NTT (CT), 1 = Inverse NTT (GS)
    input  wire [2:0]  stage,   // Current stage index (0 to 6)
    input  wire [6:0]  bf_idx,  // Butterfly counter within current stage (0 to 127)
    output wire [7:0]  addr_a,  // Computed RAM address for coefficient A
    output wire [7:0]  addr_b,  // Computed RAM address for coefficient B
    output wire [6:0]  tw_addr  // Computed Twiddle ROM address
);

    // --- Forward NTT (Cooley-Tukey) Internal Signal Generation ---
    wire [2:0] shift_ct;
    wire [7:0] len_ct;
    wire [7:0] block_idx_ct;
    wire [7:0] offset_ct;
    wire [7:0] addr_a_ct;
    wire [7:0] addr_b_ct;
    wire [6:0] tw_addr_ct;

    assign shift_ct     = 3'd7 - stage;
    assign len_ct       = 8'd1 << shift_ct;
    assign block_idx_ct = {1'b0, bf_idx} >> shift_ct;
    assign offset_ct    = {1'b0, bf_idx} & (len_ct - 8'd1);
    
    assign addr_a_ct    = (block_idx_ct << (shift_ct + 1'b1)) | offset_ct;
    assign addr_b_ct    = addr_a_ct + len_ct;
    assign tw_addr_ct   = (7'd1 << stage) + block_idx_ct[6:0];

    // --- Inverse NTT (Gentleman-Sande) Internal Signal Generation ---
    wire [2:0] shift_gs;
    wire [7:0] len_gs;
    wire [7:0] block_idx_gs;
    wire [7:0] offset_gs;
    wire [7:0] addr_a_gs;
    wire [7:0] addr_b_gs;
    wire [6:0] tw_addr_gs;

    assign shift_gs     = stage + 3'd1;
    assign len_gs       = 8'd1 << shift_gs;
    assign block_idx_gs = {1'b0, bf_idx} >> shift_gs;
    assign offset_gs    = {1'b0, bf_idx} & (len_gs - 8'd1);

    assign addr_a_gs    = (block_idx_gs << (shift_gs + 1'b1)) | offset_gs;
    assign addr_b_gs    = addr_a_gs + len_gs;
    
    // Reverse twiddle addressing for Inverse NTT
    wire [7:0] top_tw_idx_gs = (8'd1 << (3'd7 - stage)) - 8'd1;
    assign tw_addr_gs   = top_tw_idx_gs[6:0] - block_idx_gs[6:0];

    // --- Mode Multiplexing Output Selection ---
    assign addr_a  = (mode == 1'b0) ? addr_a_ct  : addr_a_gs;
    assign addr_b  = (mode == 1'b0) ? addr_b_ct  : addr_b_gs;
    assign tw_addr = (mode == 1'b0) ? tw_addr_ct : tw_addr_gs;

endmodule
