// ============================================================================
// Module: line_buffer_3row.v
// Description: Cascaded 3-row line buffer and 3x3 sliding window extractor
//              with integrated zero-padding support in synthesizable Verilog-2001.
// 
// Reproduces Section 4.2 & 4.3 (Figure 4, Figure 6) of:
// "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
// (Sensors 2026, 26, 1626)
// Target Board: ZedBoard (xc7z020clg484-1)
// ============================================================================

`timescale 1ns / 1ps

module line_buffer_3row #(
    parameter DATA_WIDTH     = 32,
    parameter MAX_LINE_WIDTH = 224
)(
    input  wire                   clk,
    input  wire                   rst,

    // Dynamic configuration from AXI-Lite registers
    input  wire [10:0]            line_width, // Dynamic W (14 to 224)
    input  wire                   padding_en, // 1 to enable zero padding

    // Streaming input (from DMA unpacker)
    input  wire [DATA_WIDTH-1:0]  in_data,
    input  wire                   in_valid,
    output wire                   in_ready,

    // 3x3 Window Output (i1 to i9 matching Figure 4 & Figure 6)
    output wire [DATA_WIDTH-1:0]  win_i1, win_i2, win_i3,
    output wire [DATA_WIDTH-1:0]  win_i4, win_i5, win_i6,
    output wire [DATA_WIDTH-1:0]  win_i7, win_i8, win_i9,
    output reg                    win_valid
);

    assign in_ready = 1'b1; // Continuous streaming pipeline

    // Dual-Port Block RAM line buffers (inferred as RAMB18/RAMB36)
    reg [DATA_WIDTH-1:0] ram_line0 [0:MAX_LINE_WIDTH-1];
    reg [DATA_WIDTH-1:0] ram_line1 [0:MAX_LINE_WIDTH-1];

    reg [DATA_WIDTH-1:0] line0_out;
    reg [DATA_WIDTH-1:0] line1_out;

    // Pointer counters
    reg [10:0] wr_ptr;
    reg [10:0] rd_ptr;

    // 3-tap shift registers for row 0, row 1, row 2
    reg [DATA_WIDTH-1:0] r0_t0, r0_t1, r0_t2;
    reg [DATA_WIDTH-1:0] r1_t0, r1_t1, r1_t2;
    reg [DATA_WIDTH-1:0] r2_t0, r2_t1, r2_t2;

    // Tracking registers
    reg [15:0] primed_cnt;
    reg        is_primed;
    reg [10:0] col_idx;
    reg [10:0] row_idx;

    wire [10:0] cur_w = (line_width > 0) ? line_width : MAX_LINE_WIDTH;

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr     <= 0;
            rd_ptr     <= 0;
            primed_cnt <= 0;
            is_primed  <= 0;
            col_idx    <= 0;
            row_idx    <= 0;
            win_valid  <= 0;

            r0_t0 <= 0; r0_t1 <= 0; r0_t2 <= 0;
            r1_t0 <= 0; r1_t1 <= 0; r1_t2 <= 0;
            r2_t0 <= 0; r2_t1 <= 0; r2_t2 <= 0;
            line0_out <= 0;
            line1_out <= 0;
        end else if (in_valid) begin
            // 1. Synchronous BRAM reads
            line1_out <= ram_line1[rd_ptr];
            line0_out <= ram_line0[rd_ptr];

            // 2. Cascaded BRAM writes (sample leaving line 1 enters line 0)
            ram_line1[wr_ptr] <= in_data;
            ram_line0[wr_ptr] <= line1_out;

            // 3. Shift registers: Advance 3x3 window registers horizontally
            r2_t2 <= in_data;
            r2_t1 <= r2_t2;
            r2_t0 <= r2_t1;

            r1_t2 <= line1_out;
            r1_t1 <= r1_t2;
            r1_t0 <= r1_t1;

            r0_t2 <= line0_out;
            r0_t1 <= r0_t2;
            r0_t0 <= r0_t1;

            // 4. Update circular pointers
            if (wr_ptr == cur_w - 1)
                wr_ptr <= 0;
            else
                wr_ptr <= wr_ptr + 1'b1;

            if (rd_ptr == cur_w - 1)
                rd_ptr <= 0;
            else
                rd_ptr <= rd_ptr + 1'b1;

            // 5. Priming counter (2 lines + 3 pixels)
            if (!is_primed) begin
                if (primed_cnt == (2 * cur_w + 2)) begin
                    is_primed <= 1'b1;
                    win_valid <= 1'b1;
                end else begin
                    primed_cnt <= primed_cnt + 1'b1;
                    win_valid  <= 1'b0;
                end
            end else begin
                win_valid <= 1'b1;
            end

            // 6. 2D Coordinate tracking for zero-padding
            if (col_idx == cur_w - 1) begin
                col_idx <= 0;
                row_idx <= row_idx + 1'b1;
            end else begin
                col_idx <= col_idx + 1'b1;
            end
        end else begin
            win_valid <= 1'b0;
        end
    end

    // On-the-fly zero-padding multiplexers
    wire is_top = (row_idx == 0);
    wire is_bot = 1'b0; // After priming, bottom is streamed in
    wire is_lft = (col_idx == 0);
    wire is_rgt = (col_idx == cur_w - 1);

    assign win_i1 = (padding_en && (is_top || is_lft)) ? {DATA_WIDTH{1'b0}} : r0_t0;
    assign win_i2 = (padding_en && is_top)             ? {DATA_WIDTH{1'b0}} : r0_t1;
    assign win_i3 = (padding_en && (is_top || is_rgt)) ? {DATA_WIDTH{1'b0}} : r0_t2;

    assign win_i4 = (padding_en && is_lft)             ? {DATA_WIDTH{1'b0}} : r1_t0;
    assign win_i5 = r1_t1; // Center pixel always valid
    assign win_i6 = (padding_en && is_rgt)             ? {DATA_WIDTH{1'b0}} : r1_t2;

    assign win_i7 = (padding_en && is_lft)             ? {DATA_WIDTH{1'b0}} : r2_t0;
    assign win_i8 = r2_t1;
    assign win_i9 = (padding_en && is_rgt)             ? {DATA_WIDTH{1'b0}} : r2_t2;

endmodule
