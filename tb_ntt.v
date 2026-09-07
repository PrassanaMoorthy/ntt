module tb_ntt;
    reg clk, rst_n, start, algo_sel, wr_en;
    reg [7:0] wr_addr, rd_addr;
    reg [22:0] wr_data;
    wire [22:0] rd_data;
    wire busy, done;

    reg [22:0] test_in [0:255];
    reg [22:0] test_exp [0:255];
    integer i, errors;

    ntt uut (
        .clk(clk), .rst_n(rst_n), .start(start), .algo_sel(algo_sel),
        .busy(busy), .done(done), .wr_en(wr_en), .wr_addr(wr_addr),
        .wr_data(wr_data), .rd_addr(rd_addr), .rd_data(rd_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0; start = 0; wr_en = 0; algo_sel = 0; errors = 0;
        $readmemh("ntt_din.hex", test_in);
        $readmemh("ntt_expected.hex", test_exp);

        #20 rst_n = 1;

        // 1. Load Data into RAM
        for (i = 0; i < 256; i = i + 1) begin
            @(posedge clk);
            wr_en <= 1; wr_addr <= i; wr_data <= test_in[i];
        end
        @(posedge clk) wr_en <= 0;

        // 2. Start NTT Process
        @(posedge clk);
        start <= 1;
        @(posedge clk);
        start <= 0;

        // 3. Wait for Completion
        wait(done);

        // 4. Verify RAM Output
        //
        // NOTE: rd_data is produced by a nonblocking assignment inside
        // ntt_ram's own posedge-clk block. Checking it immediately after
        // "@(posedge clk)" (same Active-region timestep) reads the value
        // from BEFORE this edge's NBA update lands, one cycle stale.
        // A "#1" settle delay lets the NBA region complete first, so the
        // check actually observes the freshly registered rd_data for the
        // rd_addr we just set.
        for (i = 0; i < 256; i = i + 1) begin
            rd_addr <= i;
            @(posedge clk); // Allow pipeline read latency
            #1;             // let rd_data's NBA update settle before sampling
            if (rd_data !== test_exp[i]) begin
                $display("ERROR at addr %0d: Expected %0h, Got %0h", i, test_exp[i], rd_data);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display(">>> SUCCESS: 256-point NTT passed perfectly! <<<");
        else $display(">>> FAILED: %0d mismatch errors found. <<<", errors);
        $finish;
    end
endmodule
