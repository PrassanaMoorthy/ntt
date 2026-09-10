`timescale 1ns/1ps
//------------------------------------------------------------------
// Testbench for: bf_unit (NTT Cooley-Tukey butterfly, dual modulus
//                 for ML-KEM / ML-DSA, 1-cycle registered pipeline)
//
// Run:
//   iverilog -o sim.out bf_unit.v bf_unit_tb.v
//   vvp sim.out
//   (optional) gtkwave bf_unit_tb.vcd
//------------------------------------------------------------------
module tb_bff_unit;

    localparam [22:0] TB_Q_KEM = 23'd3329;
    localparam [22:0] TB_Q_DSA = 23'd8380417;

    reg         clk, rst_n;
    reg  [22:0] a_in, b_in, w_in;
    reg         algo_sel, mode, valid_in;
    wire [22:0] a_out, b_out;
    wire        valid_out;

    integer checks = 0;
    integer errors = 0;

    bf_unit dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .a_in      (a_in),
        .b_in      (b_in),
        .w_in      (w_in),
        .algo_sel  (algo_sel),
        .mode      (mode),
        .valid_in  (valid_in),
        .a_out     (a_out),
        .b_out     (b_out),
        .valid_out (valid_out)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    //------------------------------------------------------------
    // Reference model: CT butterfly, mirrors the DUT's arithmetic
    //   a' = (a + w*b)      mod Q
    //   b' = (a + Q - w*b)  mod Q
    //------------------------------------------------------------
    task calc_exp(input [22:0] a, input [22:0] b, input [22:0] w, input alg,
                  output [22:0] exp_a, output [22:0] exp_b);
        reg [22:0] Q;
        reg [45:0] prod;
        reg [22:0] tt;
        reg [23:0] sa, sb;
        begin
            Q    = alg ? TB_Q_DSA : TB_Q_KEM;
            prod = w * b;
            tt   = prod % Q;
            sa   = a + tt;
            sb   = a + Q - tt;
            exp_a = sa % Q;
            exp_b = sb % Q;
        end
    endtask

    // Drives one butterfly op, waits for its 1-cycle latency, checks result.
    task run_bf(input [22:0] a, input [22:0] b, input [22:0] w,
                input alg, input md, input [8*56-1:0] name);
        reg [22:0] exp_a, exp_b;
        begin
            calc_exp(a, b, w, alg, exp_a, exp_b);

            @(negedge clk);
            a_in = a; b_in = b; w_in = w; algo_sel = alg; mode = md; valid_in = 1;
            @(negedge clk);
            valid_in = 0;

            checks = checks + 1;
            if (a_out !== exp_a || b_out !== exp_b || valid_out !== 1'b1) begin
                errors = errors + 1;
                $display("[FAIL] %0t ns  %0s : exp(a=%0d,b=%0d) got(a=%0d,b=%0d) valid_out=%b",
                          $time, name, exp_a, exp_b, a_out, b_out, valid_out);
            end else begin
                $display("[PASS] %0t ns  %0s : a_out=%0d b_out=%0d", $time, name, a_out, b_out);
            end
        end
    endtask

    task check_bit(input got, input exp, input [8*56-1:0] name);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("[FAIL] %0t ns  %0s : expected=%b got=%b", $time, name, exp, got);
            end else begin
                $display("[PASS] %0t ns  %0s : got=%b", $time, name, got);
            end
        end
    endtask

    task check23(input [22:0] got, input [22:0] exp, input [8*56-1:0] name);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("[FAIL] %0t ns  %0s : expected=%0d got=%0d", $time, name, exp, got);
            end else begin
                $display("[PASS] %0t ns  %0s : got=%0d", $time, name, got);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_bff_unit.vcd");
        $dumpvars(0, tb_bff_unit);

        clk      = 0;
        rst_n    = 0;
        a_in     = 0; b_in = 0; w_in = 0;
        algo_sel = 0; mode = 0; valid_in = 0;

        //----------------------------------------------------------
        // R1: reset holds outputs at 0
        //----------------------------------------------------------
        repeat (2) @(negedge clk);
        check23(a_out, 23'd0, "R1 reset a_out");
        check23(b_out, 23'd0, "R1 reset b_out");
        check_bit(valid_out, 1'b0, "R1 reset valid_out");

        @(negedge clk);
        rst_n = 1;

        //----------------------------------------------------------
        // T1-T4: basic CT butterfly, Q_KEM (algo_sel=0), varied data
        //----------------------------------------------------------
        run_bf(23'd0,    23'd0,    23'd0,    1'b0, 1'b0, "T1 KEM all-zero");
        run_bf(23'd100,  23'd7,    23'd13,   1'b0, 1'b0, "T2 KEM small values");
        run_bf(23'd3328, 23'd3328, 23'd3328, 1'b0, 1'b0, "T3 KEM boundary (Q-1)");
        run_bf(23'd1,    23'd3328, 23'd3327, 1'b0, 1'b0, "T4 KEM near-boundary mix");

        //----------------------------------------------------------
        // T5-T8: basic CT butterfly, Q_DSA (algo_sel=1), varied data
        //----------------------------------------------------------
        run_bf(23'd0,       23'd0,       23'd0,       1'b1, 1'b0, "T5 DSA all-zero");
        run_bf(23'd123456,  23'd54321,   23'd999999,  1'b1, 1'b0, "T6 DSA mid-range values");
        run_bf(23'd8380416, 23'd8380416, 23'd8380416, 1'b1, 1'b0, "T7 DSA boundary (Q-1)");
        run_bf(23'd1,       23'd8380416, 23'd8380415, 1'b1, 1'b0, "T8 DSA near-boundary mix");

        //----------------------------------------------------------
        // T9: algo_sel toggling back-to-back (modulus switches cycle
        //     to cycle) must not leak state between the two moduli
        //----------------------------------------------------------
        run_bf(23'd3000, 23'd3000, 23'd3000, 1'b0, 1'b0, "T9a KEM before switch");
        run_bf(23'd8000000, 23'd8000000, 23'd8000000, 1'b1, 1'b0, "T9b DSA after switch");
        run_bf(23'd3000, 23'd3000, 23'd3000, 1'b0, 1'b0, "T9c KEM after switch-back");

        //----------------------------------------------------------
        // T10: mode==1 (GS) currently falls back to CT per the RTL
        // comment ("mode==1 (GS) not implemented yet"). This check
        // pins down that documented behavior so a future partial/
        // incorrect GS implementation gets caught as a regression.
        // >>> Update/remove this test once GS mode is implemented. <<<
        //----------------------------------------------------------
        run_bf(23'd222, 23'd333, 23'd444, 1'b0, 1'b1, "T10a mode=1 KEM still computes CT");
        run_bf(23'd222222, 23'd333333, 23'd444444, 1'b1, 1'b1, "T10b mode=1 DSA still computes CT");

        //----------------------------------------------------------
        // T11: async reset asserted mid-transaction (valid_in high)
        // must clear outputs regardless of in-flight operation
        //----------------------------------------------------------
        @(negedge clk);
        a_in = 23'd50; b_in = 23'd60; w_in = 23'd70; algo_sel = 0; mode = 0; valid_in = 1;
        # 2 rst_n = 0;          // async reset mid-cycle
        @(negedge clk);
        rst_n = 0; valid_in = 0;
        check23(a_out, 23'd0, "T11 async reset clears a_out");
        check23(b_out, 23'd0, "T11 async reset clears b_out");
        check_bit(valid_out, 1'b0, "T11 async reset clears valid_out");
        @(negedge clk);
        rst_n = 1;

        //----------------------------------------------------------
        // T12: single pulse then a bubble - a_out/b_out must HOLD
        // their last value while valid_out drops, since the DUT
        // only updates a_out/b_out when valid_in was asserted
        //----------------------------------------------------------
        begin : bubble_test
            reg [22:0] exp_a12, exp_b12;
            calc_exp(23'd10, 23'd20, 23'd30, 1'b0, exp_a12, exp_b12);
            @(negedge clk);
            a_in = 23'd10; b_in = 23'd20; w_in = 23'd30; algo_sel = 0; mode = 0; valid_in = 1;
            @(negedge clk);
            valid_in = 0;                 // bubble starts
            check23(a_out, exp_a12, "T12 pulse result a_out");
            check23(b_out, exp_b12, "T12 pulse result b_out");
            check_bit(valid_out, 1'b1, "T12 pulse result valid_out");
            @(negedge clk);
            check23(a_out, exp_a12, "T12 bubble holds a_out");
            check23(b_out, exp_b12, "T12 bubble holds b_out");
            check_bit(valid_out, 1'b0, "T12 bubble valid_out drops");
        end

        //----------------------------------------------------------
        // T13: back-to-back valid_in for 3 cycles (pipeline burst) -
        // each cycle's result must line up with its own inputs, not
        // a neighbor's
        //----------------------------------------------------------
        begin : burst_test
            reg [22:0] e1a, e1b, e2a, e2b, e3a, e3b;
            calc_exp(23'd1, 23'd2,  23'd3,  1'b0, e1a, e1b);
            calc_exp(23'd4, 23'd5,  23'd6,  1'b0, e2a, e2b);
            calc_exp(23'd7, 23'd8,  23'd9,  1'b1, e3a, e3b);

            @(negedge clk);
            a_in = 23'd1; b_in = 23'd2; w_in = 23'd3; algo_sel = 1'b0; mode = 0; valid_in = 1;
            @(negedge clk);
            a_in = 23'd4; b_in = 23'd5; w_in = 23'd6; algo_sel = 1'b0; mode = 0; valid_in = 1;
            check23(a_out, e1a, "T13 burst cyc1 a_out");
            check23(b_out, e1b, "T13 burst cyc1 b_out");
            check_bit(valid_out, 1'b1, "T13 burst cyc1 valid_out");
            @(negedge clk);
            a_in = 23'd7; b_in = 23'd8; w_in = 23'd9; algo_sel = 1'b1; mode = 0; valid_in = 1;
            check23(a_out, e2a, "T13 burst cyc2 a_out");
            check23(b_out, e2b, "T13 burst cyc2 b_out");
            check_bit(valid_out, 1'b1, "T13 burst cyc2 valid_out");
            @(negedge clk);
            valid_in = 0;
            check23(a_out, e3a, "T13 burst cyc3 a_out");
            check23(b_out, e3b, "T13 burst cyc3 b_out");
            check_bit(valid_out, 1'b1, "T13 burst cyc3 valid_out");
            @(negedge clk);
            check_bit(valid_out, 1'b0, "T13 burst drain valid_out");
        end

        //----------------------------------------------------------
        // T14 (informational only): a_in/b_in given >= Q_DSA. The
        // RTL doesn't range-check inputs; results are only
        // meaningful if callers pre-reduce a_in/b_in mod Q. Flagged
        // for awareness, not a spec violation.
        //----------------------------------------------------------
        @(negedge clk);
        a_in = 23'd8388607; b_in = 23'd8388607; w_in = 23'd1; algo_sel = 1; mode = 0; valid_in = 1;
        @(negedge clk);
        valid_in = 0;
        $display("[INFO] %0t ns  T14 out-of-range (a_in,b_in >= Q_DSA) -> a_out=%0d b_out=%0d (inputs must be pre-reduced mod Q for meaningful results)",
                  $time, a_out, b_out);

        //----------------------------------------------------------
        @(negedge clk);
        $display("----------------------------------------------------");
        $display("TOTAL CHECKS = %0d   ERRORS = %0d", checks, errors);
        if (errors == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: %0d TEST(S) FAILED", errors);
        $display("----------------------------------------------------");

        $finish;
    end

endmodule
