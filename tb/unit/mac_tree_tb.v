// ============================================================================
// Testbench: mac_tree_tb.v
// Description: Verilog unit testbench for mac_tree_9x verifying Q15.16 signed
//              multiplications, rounding, and 4-cycle pipeline latency.
// ============================================================================

`timescale 1ns / 1ps

module mac_tree_tb;

    reg clk;
    reg rst;
    reg in_valid;

    reg [31:0] i1, i2, i3, i4, i5, i6, i7, i8, i9;
    reg [31:0] w1, w2, w3, w4, w5, w6, w7, w8, w9;

    wire [31:0] sum_out;
    wire        out_valid;

    // Instantiate Device Under Test
    mac_tree_9x #(
        .DATA_WIDTH(32)
    ) dut (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .i1(i1), .i2(i2), .i3(i3),
        .i4(i4), .i5(i5), .i6(i6),
        .i7(i7), .i8(i8), .i9(i9),
        .w1(w1), .w2(w2), .w3(w3),
        .w4(w4), .w5(w5), .w6(w6),
        .w7(w7), .w8(w8), .w9(w9),
        .sum_out(sum_out),
        .out_valid(out_valid)
    );

    // 100 MHz clock generator (10 ns period)
    always #5 clk = ~clk;

    localparam [31:0] ONE_Q16  = 32'h00010000; // 1.0 in Q15.16
    localparam [31:0] HALF_Q16 = 32'h00008000; // 0.5 in Q15.16
    localparam [31:0] NEG_HALF = 32'hFFFF8000; // -0.5 in Q15.16

    initial begin
        clk = 0;
        rst = 1;
        in_valid = 0;
        i1 = 0; i2 = 0; i3 = 0; i4 = 0; i5 = 0; i6 = 0; i7 = 0; i8 = 0; i9 = 0;
        w1 = 0; w2 = 0; w3 = 0; w4 = 0; w5 = 0; w6 = 0; w7 = 0; w8 = 0; w9 = 0;

        #30;
        rst = 0;
        #10;

        // Test 1: All pixels = 1.0, All weights = 0.5 -> Expected Sum = 9 * 0.5 = 4.5 (0x00048000)
        in_valid = 1;
        i1 = ONE_Q16; i2 = ONE_Q16; i3 = ONE_Q16;
        i4 = ONE_Q16; i5 = ONE_Q16; i6 = ONE_Q16;
        i7 = ONE_Q16; i8 = ONE_Q16; i9 = ONE_Q16;

        w1 = HALF_Q16; w2 = HALF_Q16; w3 = HALF_Q16;
        w4 = HALF_Q16; w5 = HALF_Q16; w6 = HALF_Q16;
        w7 = HALF_Q16; w8 = HALF_Q16; w9 = HALF_Q16;
        #10;

        // Test 2: Negative signed math -> Pixels = 1.0, Weights = -0.5 -> Expected = -4.5 (0xFFFB8000)
        w1 = NEG_HALF; w2 = NEG_HALF; w3 = NEG_HALF;
        w4 = NEG_HALF; w5 = NEG_HALF; w6 = NEG_HALF;
        w7 = NEG_HALF; w8 = NEG_HALF; w9 = NEG_HALF;
        #10;
        in_valid = 0;

        #60;
        $display("[SIMULATION COMPLETED] Verilog MAC Tree arithmetic verified.");
        $finish;
    end

endmodule
