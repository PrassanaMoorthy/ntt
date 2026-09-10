`timescale 1ns / 1ps

module tb_top_module;

    // Inputs
    reg        clk;
    reg        rst;
    reg        start;
    reg        mode;
    reg        ext_we;
    reg  [7:0] ext_addr;
    reg [15:0] ext_din;

    // Outputs
    wire [15:0] ext_dout;
    wire        busy;
    wire        done;

    // Loop Variables & Errors
    integer i;
    integer errors;

    // Instantiate Unit Under Test (UUT)
    top_module uut (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .mode     (mode),
        .ext_we   (ext_we),
        .ext_addr (ext_addr),
        .ext_din  (ext_din),
        .ext_dout (ext_dout),
        .busy     (busy),
        .done     (done)
    );

    // Clock Generation (100 MHz -> 10ns period)
    always #5 clk = ~clk;

    initial begin
    
    
    $dumpfile("wave.vcd");
$dumpvars(0, tb_top_module);


        // Initialize Inputs
        clk      = 0;
        rst      = 1;
        start    = 0;
        mode     = 0;
        ext_we   = 0;
        ext_addr = 0;
        ext_din  = 0;
        errors   = 0;

        #20;
        rst = 0;
        #10;

        // ====================================================================
        // TEST CASE 1: Impulse Input Polynomial (Forward NTT)
        // Input: P(X) = 1 (a[0]=1, all other a[i]=0)
        // Expected Forward NTT: Alternating [1, 0, 1, 0, 1, 0, ...]
        // ====================================================================
        $display("--------------------------------------------------");
        $display("RUNNING TEST CASE 1: Impulse Response Forward NTT");
        $display("--------------------------------------------------");

        // Load RAM with Impulse Polynomial
        for (i = 0; i < 256; i = i + 1) begin
            @(posedge clk);
            ext_we   = 1;
            ext_addr = i[7:0];
            ext_din  = (i == 0) ? 16'd1 : 16'd0;
        end
        @(posedge clk);
        ext_we = 0;

        // Trigger Forward NTT (mode = 0)
        @(posedge clk);
        mode  = 1'b0;
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Wait for NTT completion
        wait(done == 1'b1);
        @(posedge clk);

        // Verify Results with 1-cycle Synchronous Read Latency
        for (i = 0; i < 256; i = i + 1) begin
            ext_addr = i[7:0];
            @(posedge clk); // Allow RAM to sample address & update output
            #1;
            if (i % 2 == 0) begin
                if (ext_dout !== 16'd1) begin
                    $display("ERROR TC1: Index %0d: Expected 1, Got %0d", i, ext_dout);
                    errors = errors + 1;
                end
            end else begin
                if (ext_dout !== 16'd0) begin
                    $display("ERROR TC1: Index %0d: Expected 0, Got %0d", i, ext_dout);
                    errors = errors + 1;
                end
            end
        end

        if (errors == 0)
            $display("-> TEST CASE 1 PASSED!");
        else
            $display("-> TEST CASE 1 FAILED with %0d errors.", errors);

        #50;

        // ====================================================================
        // TEST CASE 2: Ramp Input Polynomial (Forward NTT)
        // Input: P(X) = 0, 1, 2, ..., 255
        // Expected First 4: [1665, 867, 1431, 1629]
        // ====================================================================
        $display("\n--------------------------------------------------");
        $display("RUNNING TEST CASE 2: Ramp Polynomial Forward NTT");
        $display("--------------------------------------------------");
        errors = 0;

        // Load RAM with Ramp Data
        for (i = 0; i < 256; i = i + 1) begin
            @(posedge clk);
            ext_we   = 1;
            ext_addr = i[7:0];
            ext_din  = i[15:0];
        end
        @(posedge clk);
        ext_we = 0;

        // Trigger Forward NTT
        @(posedge clk);
        mode  = 1'b0;
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait(done == 1'b1);
        @(posedge clk);

        // Read and Print First 8 Coefficients
        $display("Forward NTT First 8 Output Coefficients:");
        for (i = 0; i < 8; i = i + 1) begin
            ext_addr = i[7:0];
            @(posedge clk);
            #1;
            $display("  Out[%0d] = %0d", i, ext_dout);
        end

        // Verify known reference values
        ext_addr = 8'd0; @(posedge clk); #1; if (ext_dout !== 16'd1665) errors = errors + 1;
        ext_addr = 8'd1; @(posedge clk); #1; if (ext_dout !== 16'd867)  errors = errors + 1;
        ext_addr = 8'd2; @(posedge clk); #1; if (ext_dout !== 16'd1431) errors = errors + 1;
        ext_addr = 8'd3; @(posedge clk); #1; if (ext_dout !== 16'd1629) errors = errors + 1;

        if (errors == 0)
            $display("-> TEST CASE 2 PASSED!");
        else
            $display("-> TEST CASE 2 FAILED!");

        #50;

        // ====================================================================
        // TEST CASE 3: Round-Trip Integrity (Inverse NTT on TC1 output)
        // Expected INTT Output: [128, 0, 0, ..., 0]
        // ====================================================================
        $display("\n--------------------------------------------------");
        $display("RUNNING TEST CASE 3: Inverse NTT Round-Trip Test");
        $display("--------------------------------------------------");
        errors = 0;

        // Re-run TC1 Forward NTT first to ensure clean state in RAM
        for (i = 0; i < 256; i = i + 1) begin
            @(posedge clk);
            ext_we   = 1;
            ext_addr = i[7:0];
            ext_din  = (i == 0) ? 16'd1 : 16'd0;
        end
        @(posedge clk);
        ext_we = 0;

        @(posedge clk);
        mode  = 1'b0; start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        wait(done == 1'b1);
        @(posedge clk);

        // Trigger Inverse NTT (mode = 1)
        @(posedge clk);
        mode  = 1'b1;
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait(done == 1'b1);
        @(posedge clk);

        // Verify Output: a[0] = 128, all other a[i] = 0
        for (i = 0; i < 256; i = i + 1) begin
            ext_addr = i[7:0];
            @(posedge clk);
            #1;
            if (i == 0) begin
                if (ext_dout !== 16'd128) begin
                    $display("ERROR TC3: Index 0 Expected 128, Got %0d", ext_dout);
                    errors = errors + 1;
                end
            end else begin
                if (ext_dout !== 16'd0) begin
                    $display("ERROR TC3: Index %0d Expected 0, Got %0d", i, ext_dout);
                    errors = errors + 1;
                end
            end
        end

        if (errors == 0)
            $display("-> TEST CASE 3 PASSED! Round-trip mathematically verified.");
        else
            $display("-> TEST CASE 3 FAILED with %0d errors.", errors);

        $display("\n==================================================");
        $display("ALL TESTBENCH EXECUTIONS FINISHED.");
        $display("==================================================");
        $finish;
    end

endmodule
