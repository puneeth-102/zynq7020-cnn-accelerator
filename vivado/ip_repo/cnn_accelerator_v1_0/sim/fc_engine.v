// ============================================================================
// Module: fc_engine.v
// Description: Fully Connected (FC) Matrix-Vector MAC Acceleration Engine
//              with On-Chip Activation Vector Buffering in Verilog-2001.
// 
// Reproduces Section 4.1 & Table 6 of:
// "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
// (Sensors 2026, 26, 1626)
// ============================================================================

`timescale 1ns / 1ps

module fc_engine #(
    parameter DATA_WIDTH      = 32,
    parameter MAX_INPUT_NODES = 4096
)(
    input  wire                   clk,
    input  wire                   rst,

    // Control signals
    input  wire                   start,
    input  wire [12:0]            vec_len, // Total nodes Nin
    input  wire [DATA_WIDTH-1:0]  bias_in, // Neuron bias bj
    input  wire                   relu_en,

    // Input activation loading
    input  wire [DATA_WIDTH-1:0]  act_in,
    input  wire                   act_valid,

    // Streaming weights from DMA
    input  wire [DATA_WIDTH-1:0]  w_in,
    input  wire                   w_valid,

    // Output neuron score
    output reg  [DATA_WIDTH-1:0]  fc_out,
    output reg                    fc_out_valid
);

    // On-chip BRAM to store the activation vector x
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] act_ram [0:MAX_INPUT_NODES-1];

    reg [12:0] act_wr_ptr;
    reg [12:0] act_rd_ptr;
    wire [12:0] target_len = (vec_len > 0) ? vec_len : MAX_INPUT_NODES;

    // Dot product registers
    wire signed [31:0] s_bias = bias_in;
    reg signed [63:0]  accum_64;
    reg signed [63:0]  prod_64;
    reg                is_accumulating;
    reg                w_valid_d;
    reg                is_last_node;
    reg                is_last_node_d;

    localparam signed [63:0] ROUND_HALF = 64'sd32768;
    reg signed [63:0] shifted;

    // Activation loading process
    always @(posedge clk) begin
        if (rst) begin
            act_wr_ptr <= 0;
        end else if (act_valid) begin
            act_ram[act_wr_ptr] <= act_in;
            if (act_wr_ptr == target_len - 1)
                act_wr_ptr <= 0;
            else
                act_wr_ptr <= act_wr_ptr + 1'b1;
        end
    end

    // MAC Dot-Product process
    always @(posedge clk) begin
        if (rst) begin
            act_rd_ptr      <= 0;
            accum_64        <= 0;
            prod_64         <= 0;
            is_accumulating <= 0;
            w_valid_d       <= 0;
            is_last_node    <= 0;
            is_last_node_d  <= 0;
            fc_out          <= 0;
            fc_out_valid    <= 0;
        end else begin
            w_valid_d      <= w_valid;
            is_last_node_d <= is_last_node;

            if (start) begin
                act_rd_ptr      <= 0;
                accum_64        <= { {16{s_bias[31]}}, s_bias, 16'd0 }; // Load bias shifted left 16 (Q30.32)
                is_accumulating <= 1'b1;
            end

            if (w_valid && is_accumulating) begin
                prod_64 <= $signed(act_ram[act_rd_ptr]) * $signed(w_in);
                if (act_rd_ptr == target_len - 1) begin
                    is_last_node <= 1'b1;
                    act_rd_ptr   <= 0;
                end else begin
                    is_last_node <= 1'b0;
                    act_rd_ptr   <= act_rd_ptr + 1'b1;
                end
            end

            // Pipelined Accumulation
            if (w_valid_d) begin
                accum_64 <= accum_64 + prod_64;

                if (is_last_node_d) begin
                    shifted = (accum_64 + prod_64 + ROUND_HALF) >>> 16;

                    // Saturation
                    if (shifted > 64'sd2147483647)
                        shifted = 64'sd2147483647;
                    else if (shifted < -64'sd2147483648)
                        shifted = -64'sd2147483648;

                    // ReLU check
                    if (relu_en && (shifted < 0))
                        fc_out <= 32'd0;
                    else
                        fc_out <= shifted[31:0];

                    fc_out_valid    <= 1'b1;
                    is_accumulating <= 1'b0;
                end else begin
                    fc_out_valid <= 1'b0;
                end
            end else begin
                fc_out_valid <= 1'b0;
            end
        end
    end

endmodule
