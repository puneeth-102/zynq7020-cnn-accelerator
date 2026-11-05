// ============================================================================
// Module: accumulator.v
// Description: Multi-Channel Accumulator and Bias Addition Stage with
//              On-Chip BRAM Partial-Sum Buffering in Verilog-2001.
// 
// Reproduces Equation (1) and Section 4.2 of:
// "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
// (Sensors 2026, 26, 1626)
// ============================================================================

`timescale 1ns / 1ps

module accumulator #(
    parameter DATA_WIDTH      = 32,
    parameter MAX_SPATIAL_DIM = 50176 // 224 x 224
)(
    input  wire                   clk,
    input  wire                   rst,

    // Input from mac_tree_9x
    input  wire [DATA_WIDTH-1:0]  conv_sum_in,
    input  wire                   conv_valid_in,

    // Channel & spatial coordinates
    input  wire [11:0]            c_in_idx,     // Current channel c (0 to Cin-1)
    input  wire [11:0]            cin_total,    // Total channels Cin
    input  wire [DATA_WIDTH-1:0]  bias_in,      // Bias bo for output channel
    input  wire [15:0]            pixel_addr,   // Spatial index 0 to HxW-1

    // Final accumulated output
    output reg  [DATA_WIDTH-1:0]  accum_out,
    output reg                    accum_valid
);

    // On-chip partial-sum Block RAM (inferred into Zynq-7020 BRAM36 blocks)
    reg [DATA_WIDTH-1:0] psum_ram [0:MAX_SPATIAL_DIM-1];

    wire signed [31:0] s_conv = conv_sum_in;
    wire signed [31:0] s_bias = bias_in;

    reg signed [31:0] s_prev_psum;
    reg signed [32:0] s_new_accum; // 33-bit addition

    wire is_first_c = (c_in_idx == 12'd0);
    wire is_last_c  = (c_in_idx == cin_total - 1'b1);

    reg        conv_valid_d;
    reg        is_last_c_d;
    reg [15:0] addr_d;

    always @(posedge clk) begin
        if (rst) begin
            conv_valid_d <= 0;
            is_last_c_d  <= 0;
            addr_d       <= 0;
            accum_valid  <= 0;
            accum_out    <= 0;
        end else begin
            // Pipeline Stage 1: Fetch previous partial sum from BRAM
            conv_valid_d <= conv_valid_in;
            is_last_c_d  <= is_last_c;
            addr_d       <= pixel_addr;

            if (conv_valid_in) begin
                if (is_first_c)
                    s_prev_psum <= s_bias; // Load bias bo for first channel
                else
                    s_prev_psum <= psum_ram[pixel_addr];
            end

            // Pipeline Stage 2: Accumulate running partial sum
            if (conv_valid_d) begin
                s_new_accum = s_prev_psum + s_conv;

                // Saturation check
                if (s_new_accum > 33'sd2147483647)
                    s_new_accum = 33'sd2147483647;
                else if (s_new_accum < -33'sd2147483648)
                    s_new_accum = -33'sd2147483648;

                // Write updated partial sum back to BRAM for intermediate channels
                psum_ram[addr_d] <= s_new_accum[31:0];

                // Output valid on final channel
                if (is_last_c_d) begin
                    accum_out   <= s_new_accum[31:0];
                    accum_valid <= 1'b1;
                end else begin
                    accum_valid <= 1'b0;
                end
            end else begin
                accum_valid <= 1'b0;
            end
        end
    end

endmodule
