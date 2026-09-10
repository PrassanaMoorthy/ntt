`timescale 1ns/1ps

module tb_r;

    reg        clk;

    // Port A
    reg        we_a;
    reg [7:0]  addr_a;
    reg [22:0] din_a;
    wire [22:0] dout_a;

    // Port B
    reg        we_b;
    reg [7:0]  addr_b;
    reg [22:0] din_b;
    wire [22:0] dout_b;


    // ==========================================
    // DUT
    // ==========================================

   r uut (
        .clk    (clk),

        .we_a   (we_a),
        .addr_a (addr_a),
        .din_a  (din_a),
        .dout_a (dout_a),

        .we_b   (we_b),
        .addr_b (addr_b),
        .din_b  (din_b),
        .dout_b (dout_b)
    );


    // ==========================================
    // CLOCK
    // ==========================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    // ==========================================
    // VCD DUMP
    // ==========================================

    initial begin
        $dumpfile("r.vcd");
        $dumpvars(0, tb_r);
    end


    // ==========================================
    // TEST
    // ==========================================

    initial begin

        // Initial values
        we_a   = 0;
        addr_a = 0;
        din_a  = 0;

        we_b   = 0;
        addr_b = 0;
        din_b  = 0;


        // ======================================
        // TEST 1
        // Port A writes 100 to address 10
        // ======================================

        #10;

        we_a   = 1;
        addr_a = 8'd10;
        din_a  = 23'd100;

        #10;

        we_a = 0;


        // ======================================
        // TEST 2
        // Port B writes 200 to address 20
        // ======================================

        addr_b = 8'd20;
        din_b  = 23'd200;
        we_b   = 1;

        #10;

        we_b = 0;


        // ======================================
        // TEST 3
        // Read two different addresses
        // simultaneously
        //
        // Port A → address 10 → 100
        // Port B → address 20 → 200
        // ======================================

        addr_a = 8'd10;
        addr_b = 8'd20;

        #10;

        $display("--------------------------------");
        $display("TEST 3");
        $display("Port A: Address = %d, Data = %d",
                 addr_a, dout_a);
        $display("Port B: Address = %d, Data = %d",
                 addr_b, dout_b);
        $display("--------------------------------");


        // ======================================
        // TEST 4
        // Read different addresses
        //
        // Port A → address 20
        // Port B → address 10
        // ======================================

        addr_a = 8'd20;
        addr_b = 8'd10;

        #10;

        $display("--------------------------------");
        $display("TEST 4");
        $display("Port A: Address = %d, Data = %d",
                 addr_a, dout_a);
        $display("Port B: Address = %d, Data = %d",
                 addr_b, dout_b);
        $display("--------------------------------");


        // ======================================
        // TEST 5
        // Both ports read SAME address
        // ======================================

        addr_a = 8'd10;
        addr_b = 8'd10;

        #10;

        $display("--------------------------------");
        $display("TEST 5 - SAME ADDRESS");
        $display("Port A: Address = %d, Data = %d",
                 addr_a, dout_a);
        $display("Port B: Address = %d, Data = %d",
                 addr_b, dout_b);
        $display("--------------------------------");


        // ======================================
        // TEST 6
        // Simultaneous WRITE
        //
        // Port A → RAM[30] = 300
        // Port B → RAM[40] = 400
        // ======================================

        we_a   = 1;
        addr_a = 8'd30;
        din_a  = 23'd300;

        we_b   = 1;
        addr_b = 8'd40;
        din_b  = 23'd400;

        #10;

        we_a = 0;
        we_b = 0;


        // ======================================
        // Read RAM[30] and RAM[40]
        // simultaneously
        // ======================================

        addr_a = 8'd30;
        addr_b = 8'd40;

        #10;

        $display("--------------------------------");
        $display("TEST 6 - SIMULTANEOUS WRITE/READ");
        $display("Port A: Address = %d, Data = %d",
                 addr_a, dout_a);
        $display("Port B: Address = %d, Data = %d",
                 addr_b, dout_b);
        $display("--------------------------------");


        // ======================================
        // END
        // ======================================

        #10;

        $finish;

    end

endmodule
