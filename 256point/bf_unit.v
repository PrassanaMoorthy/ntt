module bf_unit (
    input  wire        clk,
    input  wire        rst,

    input  wire        mode,       // 0 = CT Butterfly, 1 = GS Butterfly
    input  wire        scale_en,   // 1 = final inverse NTT scaling

    input  wire [15:0] in_a,
    input  wire [15:0] in_b,
    input  wire [15:0] tw_data,

    output reg  [15:0] out_a,
    output reg  [15:0] out_b
);

    // =========================================================
    // Kyber / ML-KEM Parameters
    // =========================================================

    localparam [15:0] Q          = 16'd3329;
    localparam [15:0] Q_INV      = 16'd62209;
    localparam [15:0] N_INV_MONT = 16'd512;


    // =========================================================
    // Intermediate Signals
    // =========================================================

    // Input to Montgomery multiplication
    reg [31:0] mult_in;

    // GS subtraction: (B - A) mod Q
    reg [15:0] sub_diff;

    // Montgomery reduction
    reg [31:0] mont_m_mult;
    reg [15:0] mont_m;

    reg [31:0] mont_q_mult;
    reg [31:0] mont_t;

    reg [16:0] mont_t_sub;
    reg [15:0] mont_res;


    // Modular addition
    reg [16:0] add_sum;
    reg [16:0] add_sub;


    // Next registered outputs
    reg [15:0] next_out_a;
    reg [15:0] next_out_b;


    // =========================================================
    // Combinational Butterfly Logic
    // =========================================================

    always @(*) begin

        // -----------------------------------------------------
        // Default values
        // -----------------------------------------------------

        mult_in      = 32'd0;

        sub_diff     = 16'd0;

        mont_m_mult  = 32'd0;
        mont_m       = 16'd0;

        mont_q_mult  = 32'd0;
        mont_t       = 32'd0;

        mont_t_sub   = 17'd0;
        mont_res     = 16'd0;

        add_sum      = 17'd0;
        add_sub      = 17'd0;

        next_out_a   = 16'd0;
        next_out_b   = 16'd0;


        // =====================================================
        // 1. SELECT MULTIPLICATION INPUT
        // =====================================================

        if (scale_en) begin

            // Final inverse NTT scaling
            //
            // A' = A * N_INV_MONT

            mult_in = in_a * N_INV_MONT;

        end

        else if (mode == 1'b0) begin

            // -------------------------------------------------
            // CT Forward Butterfly
            //
            // T = B * W
            // -------------------------------------------------

            mult_in = in_b * tw_data;

        end

        else begin

            // -------------------------------------------------
            // GS Inverse Butterfly
            //
            // T = (B - A) * W
            // -------------------------------------------------

            if (in_b >= in_a)
                sub_diff = in_b - in_a;
            else
                sub_diff = in_b + Q - in_a;

            mult_in = sub_diff * tw_data;

        end


        // =====================================================
        // 2. MONTGOMERY REDUCTION
        // =====================================================

        // -----------------------------------------------------
        // m = (mult_in mod 2^16) * Q_INV
        // -----------------------------------------------------

        mont_m_mult = mult_in[15:0] * Q_INV;

        mont_m = mont_m_mult[15:0];


        // -----------------------------------------------------
        // t = (mult_in + m * Q) / 2^16
        // -----------------------------------------------------

        mont_q_mult = mont_m * Q;

        mont_t = (mult_in + mont_q_mult) >> 16;


        // -----------------------------------------------------
        // If t >= Q:
        //
        //     t = t - Q
        //
        // Otherwise:
        //
        //     keep t
        // -----------------------------------------------------

        mont_t_sub = mont_t - Q;

        if (mont_t_sub[16])
            mont_res = mont_t[15:0];
        else
            mont_res = mont_t_sub[15:0];


        // =====================================================
        // 3. OUTPUT CALCULATION
        // =====================================================

        // =====================================================
        // SCALE MODE
        // =====================================================

        if (scale_en) begin

            // A' = A * N^-1

            next_out_a = mont_res;

            // B is unused during scaling
            next_out_b = 16'd0;

        end


        // =====================================================
        // CT FORWARD BUTTERFLY
        // =====================================================

        else if (mode == 1'b0) begin

            // -------------------------------------------------
            // A' = A + T
            // -------------------------------------------------

            add_sum = in_a + mont_res;

            add_sub = add_sum - Q;

            if (add_sub[16])
                next_out_a = add_sum[15:0];
            else
                next_out_a = add_sub[15:0];


            // -------------------------------------------------
            // B' = A - T
            // -------------------------------------------------

            if (in_a >= mont_res)
                next_out_b = in_a - mont_res;
            else
                next_out_b = in_a + Q - mont_res;

        end


        // =====================================================
        // GS INVERSE BUTTERFLY
        // =====================================================

        else begin

            // -------------------------------------------------
            // A' = A + B
            // -------------------------------------------------

            add_sum = in_a + in_b;

            add_sub = add_sum - Q;

            if (add_sub[16])
                next_out_a = add_sum[15:0];
            else
                next_out_a = add_sub[15:0];


            // -------------------------------------------------
            // B' = (B - A) * W
            //
            // mont_res already contains this result
            // -------------------------------------------------

            next_out_b = mont_res;

        end

    end


    // =========================================================
    // REGISTERED OUTPUTS
    // =========================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            out_a <= 16'd0;
            out_b <= 16'd0;

        end

        else begin

            out_a <= next_out_a;
            out_b <= next_out_b;

        end

    end

endmodule
