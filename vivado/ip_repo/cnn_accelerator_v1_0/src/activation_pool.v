// ============================================================================
// Module: activation_pool.v
// Description: Integrated ReLU Activation and 2x2 Max-Pooling Engine
//              with Stride 2 Support in Verilog-2001.
// 
// Reproduces Section 4.2 & Section 5.1 of:
// "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
// (Sensors 2026, 26, 1626)
// ============================================================================

`timescale 1ns / 1ps

module activation_pool #(
    parameter DATA_WIDTH     = 32,
    parameter MAX_LINE_WIDTH = 224
)(
    input  wire                   clk,
    input  wire                   rst,

    // Control flags
    input  wire                   pool_en,    // 1 to enable 2x2 Max-Pooling, 0 for Conv+ReLU
    input  wire [10:0]            line_width, // Feature map width W

    // Input from Accumulator Stage
    input  wire [DATA_WIDTH-1:0]  in_data,
    input  wire                   in_valid,

    // Final Activated & Pooled Output
    output reg  [DATA_WIDTH-1:0]  out_data,
    output reg                    out_valid
);

    // Combinational ReLU: Clip negative values to zero
    wire [DATA_WIDTH-1:0] relu_val = in_data[DATA_WIDTH-1] ? {DATA_WIDTH{1'b0}} : in_data;

    // Line buffer to store 1 row for vertical max-pooling comparison
    reg [DATA_WIDTH-1:0] pool_line_mem [0:MAX_LINE_WIDTH-1];

    reg [10:0] col_cnt;
    reg        row_even; // 1 for even rows, 0 for odd rows

    reg [DATA_WIDTH-1:0] prev_col_val;
    reg [DATA_WIDTH-1:0] top_prev_val;

    wire [10:0] cur_w = (line_width > 0) ? line_width : MAX_LINE_WIDTH;

    // Signed comparator function
    function [31:0] max_s;
        input signed [31:0] a;
        input signed [31:0] b;
        begin
            max_s = (a >= b) ? a : b;
        end
    endfunction

    reg signed [31:0] max_top, max_bot, max_2x2;

    always @(posedge clk) begin
        if (rst) begin
            col_cnt      <= 0;
            row_even     <= 1'b1;
            out_valid    <= 0;
            out_data     <= 0;
            prev_col_val <= 0;
            top_prev_val <= 0;
        end else if (in_valid) begin
            if (!pool_en) begin
                // Bypass pooling: Output ReLU directly
                out_data  <= relu_val;
                out_valid <= 1'b1;
            end else begin
                // 2x2 Max-Pooling with Stride 2
                if (row_even) begin
                    // Store even row into line buffer
                    pool_line_mem[col_cnt] <= relu_val;
                    out_valid <= 1'b0;
                end else begin
                    // Odd row
                    if ((col_cnt % 2) == 0) begin
                        // Left column: Latch top and bottom samples
                        prev_col_val <= relu_val;
                        top_prev_val <= pool_line_mem[col_cnt];
                        out_valid    <= 1'b0;
                    end else begin
                        // Right column: Compute Max of 2x2 window
                        max_top = max_s(top_prev_val, pool_line_mem[col_cnt]);
                        max_bot = max_s(prev_col_val, relu_val);
                        max_2x2 = max_s(max_top, max_bot);

                        out_data  <= max_2x2;
                        out_valid <= 1'b1;
                    end
                end

                // Column and row counters
                if (col_cnt == cur_w - 1) begin
                    col_cnt  <= 0;
                    row_even <= ~row_even;
                end else begin
                    col_cnt  <= col_cnt + 1'b1;
                end
            end
        end else begin
            out_valid <= 1'b0;
        end
    end

endmodule
