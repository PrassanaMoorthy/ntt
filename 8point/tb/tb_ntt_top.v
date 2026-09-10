`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// tb_ntt_top - loads a vector, runs the NTT, checks the natural-order result
// against a golden value computed offline (Python, cross-checked against a
// naive O(N^2) DFT sum). Run with, e.g.:
//   iverilog -o sim ../rtl/*.v tb_ntt_top.v && vvp sim
// ---------------------------------------------------------------------------
module tb_ntt_top;
    localparam W = 12, AW = 3, TW = 2, Q = 3329;

    reg              clk = 0;
    reg              rst_n = 0;
    reg              ld_en = 0;
    reg  [AW-1:0]    ld_addr = 0;
    reg  [W-1:0]     ld_data = 0;
    reg              start = 0;
    wire             done;
    reg  [AW-1:0]    rd_addr = 0;
    wire [W-1:0]     rd_data;

    ntt_top #(.Q(Q), .W(W), .AW(AW), .TW(TW)) dut (
        .clk(clk), .rst_n(rst_n),
        .ld_en(ld_en), .ld_addr(ld_addr), .ld_data(ld_data),
        .start(start), .done(done),
        .rd_addr(rd_addr), .rd_data(rd_data)
    );

    always #5 clk = ~clk;

    integer i;
    integer errors = 0;
    reg [W-1:0] test_in  [0:7];
    reg [W-1:0] expected [0:7];

    task load_and_run;
        begin
            for (i = 0; i < 8; i = i+1) begin
                @(negedge clk);
                ld_en = 1; ld_addr = i[AW-1:0]; ld_data = test_in[i];
            end
            @(negedge clk);
            ld_en = 0;
            start = 1;
            @(negedge clk);
            start = 0;
            wait (done);
            @(negedge clk);
        end
    endtask

    task check_result;
        input [8*8-1:0] name; // simple label, unused formatting-wise
        begin
            for (i = 0; i < 8; i = i+1) begin
                rd_addr = i[AW-1:0];
                #1;
                if (rd_data !== expected[i]) begin
                    $display("  MISMATCH out[%0d] = %0d, expected %0d", i, rd_data, expected[i]);
                    errors = errors + 1;
                end else begin
                    $display("  out[%0d] = %0d (OK)", i, rd_data);
                end
            end
        end
    endtask

    initial begin
        rst_n = 0;
        #12 rst_n = 1;

        // ---- Test 1: all-ones input -> DC impulse -----------------------
        $display("Test 1: all-ones input, expect [8,0,0,0,0,0,0,0]");
        for (i=0;i<8;i=i+1) test_in[i] = 12'd1;
        expected[0]=12'd8; expected[1]=0; expected[2]=0; expected[3]=0;
        expected[4]=0; expected[5]=0; expected[6]=0; expected[7]=0;
        load_and_run; check_result("t1");

        // ---- Test 2: impulse input -> constant output --------------------
        $display("Test 2: impulse input [1,0,...,0], expect all-ones");
        test_in[0]=12'd1;
        for (i=1;i<8;i=i+1) test_in[i]=12'd0;
        for (i=0;i<8;i=i+1) expected[i]=12'd1;
        load_and_run; check_result("t2");

        // ---- Test 3: general vector, checked against offline naive DFT ---
        $display("Test 3: general vector vs. golden reference");
        test_in[0]=550;  test_in[1]=2331; test_in[2]=3286; test_in[3]=3128;
        test_in[4]=258;  test_in[5]=1044; test_in[6]=482;  test_in[7]=2029;
        expected[0]=3121; expected[1]=2148; expected[2]=1945; expected[3]=96;
        expected[4]=2702; expected[5]=620;  expected[6]=2122; expected[7]=1633;
        load_and_run; check_result("t3");

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d MISMATCHES -- SEE ABOVE", errors);

        $finish;
    end
endmodule
