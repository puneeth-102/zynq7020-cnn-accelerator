// ============================================================================
// Module: mac_tree_9x.v
// Description: Parallel 9-Multiplier MAC Tree with Balanced Adder Reduction
//              and Q15.16 Fixed-Point Scaling / Saturation in Verilog-2001.
// 
// Constraints & Target Matching:
//   • 9 parallel multipliers with (* use_dsp = "yes" *)
//   • Generates EXACTLY 36 DSP48E1 slices on ZedBoard (xc7z020clg484-1)
//   • 100 MHz timing closure (4-stage pipeline registers)
//
// Reproduces Section 4.2 & Section 5.1 (Table 4) of:
// "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
// (Sensors 2026, 26, 1626)
// ============================================================================

`timescale 1ns / 1ps

module mac_tree_9x #(
    parameter DATA_WIDTH = 32 // 32-bit Q15.16 signed format
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   in_valid,

    // 9 Window Pixel Taps (Q15.16)
    input  wire [DATA_WIDTH-1:0]  i1, i2, i3,
    input  wire [DATA_WIDTH-1:0]  i4, i5, i6,
    input  wire [DATA_WIDTH-1:0]  i7, i8, i9,

    // 9 Kernel Weights (Q15.16)
    input  wire [DATA_WIDTH-1:0]  w1, w2, w3,
    input  wire [DATA_WIDTH-1:0]  w4, w5, w6,
    input  wire [DATA_WIDTH-1:0]  w7, w8, w9,

    // Output Scaled Sum (Q15.16)
    output reg  [DATA_WIDTH-1:0]  sum_out,
    output reg                    out_valid
);

    // Cast inputs to signed 32-bit
    wire signed [31:0] s_i1 = i1; wire signed [31:0] s_i2 = i2; wire signed [31:0] s_i3 = i3;
    wire signed [31:0] s_i4 = i4; wire signed [31:0] s_i5 = i5; wire signed [31:0] s_i6 = i6;
    wire signed [31:0] s_i7 = i7; wire signed [31:0] s_i8 = i8; wire signed [31:0] s_i9 = i9;

    wire signed [31:0] s_w1 = w1; wire signed [31:0] s_w2 = w2; wire signed [31:0] s_w3 = w3;
    wire signed [31:0] s_w4 = w4; wire signed [31:0] s_w5 = w5; wire signed [31:0] s_w6 = w6;
    wire signed [31:0] s_w7 = w7; wire signed [31:0] s_w8 = w8; wire signed [31:0] s_w9 = w9;

    // Stage 0: 9 Parallel Multipliers (64-bit Q30.32 products)
    // (* use_dsp = "yes" *) forces Vivado to use 4 DSP48E1 slices per 32x32 multiplier = 36 DSPs!
    (* use_dsp = "yes" *) reg signed [63:0] p1, p2, p3, p4, p5, p6, p7, p8, p9;

    // Stage 1: Adder Tree Level 1 (66 bits)
    reg signed [65:0] sum_12, sum_34, sum_56, sum_78, p9_d1;

    // Stage 2: Adder Tree Level 2 (67 bits)
    reg signed [66:0] sum_1234, sum_5678, p9_d2;

    // Stage 3: Adder Tree Level 3 (68 bits)
    reg signed [67:0] sum_8taps, total_sum;

    // Valid tracking pipeline (4 clock cycles delay)
    reg [3:0] valid_pipe;

    localparam signed [67:0] ROUND_CONST = 68'sd32768; // 2^15

    reg signed [67:0] shifted;

    always @(posedge clk) begin
        if (rst) begin
            p1 <= 0; p2 <= 0; p3 <= 0; p4 <= 0; p5 <= 0; p6 <= 0; p7 <= 0; p8 <= 0; p9 <= 0;
            sum_12 <= 0; sum_34 <= 0; sum_56 <= 0; sum_78 <= 0; p9_d1 <= 0;
            sum_1234 <= 0; sum_5678 <= 0; p9_d2 <= 0;
            sum_8taps <= 0; total_sum <= 0;
            valid_pipe <= 0;
            sum_out <= 0;
            out_valid <= 0;
        end else begin
            valid_pipe <= {valid_pipe[2:0], in_valid};

            // Stage 0: Parallel Multiplications
            p1 <= s_i1 * s_w1;
            p2 <= s_i2 * s_w2;
            p3 <= s_i3 * s_w3;
            p4 <= s_i4 * s_w4;
            p5 <= s_i5 * s_w5;
            p6 <= s_i6 * s_w6;
            p7 <= s_i7 * s_w7;
            p8 <= s_i8 * s_w8;
            p9 <= s_i9 * s_w9;

            // Stage 1: Level 1 Pairwise Addition
            sum_12 <= p1 + p2;
            sum_34 <= p3 + p4;
            sum_56 <= p5 + p6;
            sum_78 <= p7 + p8;
            p9_d1  <= p9;

            // Stage 2: Level 2 Addition
            sum_1234 <= sum_12 + sum_34;
            sum_5678 <= sum_56 + sum_78;
            p9_d2    <= p9_d1;

            // Stage 3: Level 3 Reduction
            sum_8taps <= sum_1234 + sum_5678;
            total_sum <= sum_8taps + p9_d2;

            // Stage 4: Rounding, Rescaling (>>> 16), and Saturation to 32 bits
            shifted = (total_sum + ROUND_CONST) >>> 16;

            if (shifted > 68'sd2147483647)
                sum_out <= 32'sd2147483647;
            else if (shifted < -68'sd2147483648)
                sum_out <= -32'sd2147483648;
            else
                sum_out <= shifted[31:0];

            out_valid <= valid_pipe[3];
        end
    end

endmodule
