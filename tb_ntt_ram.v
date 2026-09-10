`timescale 1ns/1ps

module tb_ntt_ram;

    reg         clk;
    reg  [7:0]  addr_a, addr_b, rd_addr;
    reg  [22:0] din_a, din_b;
    reg         we_a, we_b;
    wire [22:0] dout_a, dout_b, rd_data;

    integer errors = 0;
    integer checks = 0;

    // Shadow reference memory - tracked entirely by testbench, never reads dut.mem
    reg [22:0] shadow_mem [0:255];
    integer i;

    ntt_ram dut (
        .clk     (clk),
        .addr_a  (addr_a), .din_a (din_a), .we_a (we_a), .dout_a (dout_a),
        .addr_b  (addr_b), .din_b (din_b), .we_b (we_b), .dout_b (dout_b),
        .rd_addr (rd_addr), .rd_data (rd_data)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Initialize shadow memory to known value (0) matching a would-be reset state
    
    initial begin
    for (i = 0; i < 256; i = i + 1) begin
        shadow_mem[i] = 23'd0;
        dut.mem[i]    = 23'd0;
    end
end

    initial begin
        for (i = 0; i < 256; i = i + 1)
            shadow_mem[i] = 23'd0;
    end

    task check;
        input [22:0] exp_a, exp_b, exp_r;
        input [63:0] tag;
        begin
            checks = checks + 1;
            if (dout_a !== exp_a) begin
                errors = errors + 1;
                $display("ERROR t=%0t [%0s] dout_a exp=%0d got=%0d", $time, tag, exp_a, dout_a);
            end
            if (dout_b !== exp_b) begin
                errors = errors + 1;
                $display("ERROR t=%0t [%0s] dout_b exp=%0d got=%0d", $time, tag, exp_b, dout_b);
            end
            if (rd_data !== exp_r) begin
                errors = errors + 1;
                $display("ERROR t=%0t [%0s] rd_data exp=%0d got=%0d", $time, tag, exp_r, rd_data);
            end
        end
    endtask

    // Applies stimulus, updates shadow_mem with SAME priority as DUT,
    // computes expected outputs, waits one clock, then checks.
    task step;
        input [7:0]  a_addr; input [22:0] a_din; input a_we;
        input [7:0]  b_addr; input [22:0] b_din; input b_we;
        input [7:0]  r_addr;
        input [63:0] tag;
        reg [22:0] exp_dout_a, exp_dout_b, exp_rd_data;
        begin
            addr_a = a_addr; din_a = a_din; we_a = a_we;
            addr_b = b_addr; din_b = b_din; we_b = b_we;
            rd_addr = r_addr;

            // Expected outputs computed BEFORE shadow_mem update (matches DUT's
            // non-blocking write timing: reads see pre-cycle memory content)
            if (a_we) exp_dout_a = a_din;
            else      exp_dout_a = shadow_mem[a_addr];

            if (b_we) exp_dout_b = b_din;
            else      exp_dout_b = shadow_mem[b_addr];

            if (a_we && (r_addr == a_addr))
                exp_rd_data = a_din;
            else if (b_we && (r_addr == b_addr))
                exp_rd_data = b_din;
            else
                exp_rd_data = shadow_mem[r_addr];

            // Update shadow memory, A-wins priority, same as DUT
            if (a_we)
                shadow_mem[a_addr] = a_din;
            if (b_we && !(a_we && (b_addr == a_addr)))
                shadow_mem[b_addr] = b_din;

            @(posedge clk);
            #1;
            check(exp_dout_a, exp_dout_b, exp_rd_data, tag);
        end
    endtask

    initial begin
        addr_a = 0; din_a = 0; we_a = 0;
        addr_b = 0; din_b = 0; we_b = 0;
        rd_addr = 0;
        @(negedge clk);

        // Test 1: write A, forward-read same addr via rd_data
        step(8'd5, 23'd100, 1, 8'd10, 23'd0, 0, 8'd5, "T1");

        // Test 2: write B, forward-read same addr via rd_data
        step(8'd20, 23'd0, 0, 8'd20, 23'd200, 1, 8'd20, "T2");

        // Test 3: plain read of both previously written addresses, no writes
        step(8'd5, 23'd0, 0, 8'd20, 23'd0, 0, 8'd5, "T3");

        // Test 4: same-address write collision A & B -> A must win
        step(8'd50, 23'd11, 1, 8'd50, 23'd22, 1, 8'd50, "T4");

        // Test 5: confirm mem[50] actually stored A's value
        step(8'd50, 23'd0, 0, 8'd20, 23'd0, 0, 8'd50, "T5");

        // Test 6: all-zero write
        step(8'd0, 23'd0, 1, 8'd20, 23'd0, 0, 8'd0, "T6");

        // Test 7: max value write
        step(8'd200, 23'h7FFFFF, 1, 8'd20, 23'd0, 0, 8'd200, "T7");

        // Test 8: sweep all 256 addresses - write then read back
        for (i = 0; i < 256; i = i + 1)
            step(i[7:0], i + 1, 1, 8'd0, 23'd0, 0, i[7:0], "T8W");

        for (i = 0; i < 256; i = i + 1)
            step(i[7:0], 23'd0, 0, 8'd0, 23'd0, 0, i[7:0], "T8R");

        $display("--------------------------------------");
        $display("Total checks: %0d  Errors: %0d", checks, errors);
        if (errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $display("--------------------------------------");

        $finish;
    end

endmodule
