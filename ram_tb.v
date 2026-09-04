`timescale 1ns/1ps
//------------------------------------------------------------------
// Testbench for: ram (true dual-port RAM, 256 x 23-bit,
//                 registered ports A/B + combinational read port)
//
// Run:
//   iverilog -o sim.out ram.v ram_tb.v
//   vvp sim.out
//   (optional) gtkwave ram_tb.vcd
//------------------------------------------------------------------
module ram_tb;

    reg         clk;
    reg  [7:0]  addr_a, addr_b, rd_addr;
    reg  [22:0] din_a,  din_b;
    reg         we_a,   we_b;
    wire [22:0] dout_a, dout_b, rd_data;

    integer checks = 0;
    integer errors = 0;

    ram dut (
        .clk     (clk),
        .addr_a  (addr_a), .din_a (din_a), .we_a (we_a), .dout_a (dout_a),
        .addr_b  (addr_b), .din_b (din_b), .we_b (we_b), .dout_b (dout_b),
        .rd_addr (rd_addr), .rd_data (rd_data)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // self-checking task
    task check23(input [22:0] got, input [22:0] exp, input [8*48-1:0] name);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("[FAIL] %0t ns  %0s : expected=%h got=%h", $time, name, exp, got);
            end else begin
                $display("[PASS] %0t ns  %0s : got=%h", $time, name, got);
            end
        end
    endtask

    initial begin
        $dumpfile("ram_tb.vcd");
        $dumpvars(0, ram_tb);

        clk    = 0;
        we_a   = 0; we_b   = 0;
        addr_a = 0; addr_b = 0; rd_addr = 0;
        din_a  = 0; din_b  = 0;

        //--------------------------------------------------------
        // T1: Port A write, then Port A read-back
        //--------------------------------------------------------
        @(negedge clk);
        addr_a = 8'd10; din_a = 23'h1AAAAA; we_a = 1;
        @(negedge clk);
        we_a = 0; addr_a = 8'd10;
        @(negedge clk);
        check23(dout_a, 23'h1AAAAA, "T1 PortA write-then-read");

        //--------------------------------------------------------
        // T2: Port B write, then Port B read-back
        //--------------------------------------------------------
        @(negedge clk);
        addr_b = 8'd20; din_b = 23'h2BBBBB; we_b = 1;
        @(negedge clk);
        we_b = 0; addr_b = 8'd20;
        @(negedge clk);
        check23(dout_b, 23'h2BBBBB, "T2 PortB write-then-read");

        //--------------------------------------------------------
        // T3: Async rd_data reflects memory content (no clk needed)
        //--------------------------------------------------------
        rd_addr = 8'd10; #1;
        check23(rd_data, 23'h1AAAAA, "T3 AsyncRead sees PortA data");

        rd_addr = 8'd20; #1;
        check23(rd_data, 23'h2BBBBB, "T3 AsyncRead sees PortB data");

        //--------------------------------------------------------
        // T4: Cross-port visibility - A writes, B reads same addr
        //--------------------------------------------------------
        @(negedge clk);
        addr_a = 8'd30; din_a = 23'h3CCCCC; we_a = 1;
        @(negedge clk);
        we_a = 0; addr_b = 8'd30;
        @(negedge clk);
        check23(dout_b, 23'h3CCCCC, "T4 PortB reads PortA write");

        //--------------------------------------------------------
        // T5: read-old-data-on-write hazard (same port, same addr,
        //     write and read requested in the same clock)
        //--------------------------------------------------------
        @(negedge clk);
        addr_a = 8'd40; din_a = 23'h044444; we_a = 1;   // preload
        @(negedge clk);
        we_a = 0;
        @(negedge clk);
        addr_a = 8'd40; din_a = 23'h055555; we_a = 1;   // write new + read same addr
        @(negedge clk);
        we_a = 0;
        check23(dout_a, 23'h044444, "T5 PortA reads OLD data while writing NEW");
        @(negedge clk);
        addr_a = 8'd40;
        @(negedge clk);
        check23(dout_a, 23'h055555, "T5 PortA sees NEW data next cycle");

        //--------------------------------------------------------
        // T6: address boundaries 0 and 255
        //--------------------------------------------------------
        @(negedge clk);
        addr_a = 8'd0;   din_a = 23'h000001; we_a = 1;
        addr_b = 8'd255; din_b = 23'h7FFFFF; we_b = 1;
        @(negedge clk);
        we_a = 0; we_b = 0;
        addr_a = 8'd0; addr_b = 8'd255;
        @(negedge clk);
        check23(dout_a, 23'h000001, "T6 Boundary addr 0   (PortA)");
        check23(dout_b, 23'h7FFFFF, "T6 Boundary addr 255 (PortB)");

        //--------------------------------------------------------
        // T7: simultaneous same-address write from both ports.
        // Not a pass/fail check - the RTL has no arbitration for
        // this case, so the winner is simulator/tool dependent.
        // Reported for awareness only.
        //--------------------------------------------------------
        @(negedge clk);
        addr_a = 8'd50; din_a = 23'h0A0A0A; we_a = 1;
        addr_b = 8'd50; din_b = 23'h0B0B0B; we_b = 1;
        @(negedge clk);
        we_a = 0; we_b = 0;
        rd_addr = 8'd50; #1;
        $display("[INFO] %0t ns  T7 simultaneous A/B write to addr 50 -> mem=%h (undefined arbitration, flag for RTL review)", $time, rd_data);

        //--------------------------------------------------------
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
