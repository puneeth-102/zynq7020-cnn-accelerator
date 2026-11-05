// ============================================================================
// Module: cnn_accelerator_top.v
// Description: Top-Level CNN Accelerator Core for ZedBoard (xc7z020clg484-1)
//              Synthesizable in standard Verilog-2001.
// 
// Reproduces the complete system architecture of:
// "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
// (Sensors 2026, 26, 1626)
// ============================================================================

`timescale 1ns / 1ps

module cnn_accelerator_top #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 6,
    parameter AXIS_DATA_WIDTH    = 64
)(
    // Clock and Reset (100 MHz PL Clock)
    input  wire                          aclk,
    input  wire                          aresetn,

    // AXI4-Lite Slave Interface (Control Registers)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                          s_axi_awvalid,
    output wire                          s_axi_awready,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                          s_axi_wvalid,
    output wire                          s_axi_wready,
    output wire [1:0]                    s_axi_bresp,
    output wire                          s_axi_bvalid,
    input  wire                          s_axi_bready,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                          s_axi_arvalid,
    output wire                          s_axi_arready,
    output wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0]                    s_axi_rresp,
    output wire                          s_axi_rvalid,
    input  wire                          s_axi_rready,

    // AXI4-Stream Slave Interface (from DMA MM2S - 64-bit)
    input  wire [AXIS_DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire                          s_axis_tvalid,
    output wire                          s_axis_tready,
    input  wire                          s_axis_tlast,

    // AXI4-Stream Master Interface (to DMA S2MM - 64-bit)
    output wire [AXIS_DATA_WIDTH-1:0]    m_axis_tdata,
    output wire                          m_axis_tvalid,
    input  wire                          m_axis_tready,
    output wire                          m_axis_tlast,

    // Interrupt
    output wire                          interrupt
);

    wire rst_sync = (~aresetn) | reg_reset;
    wire core_done;
    assign interrupt = core_done;

    // Decoded control signals
    wire        reg_start;
    wire        reg_reset;
    wire [10:0] reg_img_w;
    wire [10:0] reg_img_h;
    wire [11:0] reg_cin;
    wire [11:0] reg_cout;
    wire        reg_pad_en;
    wire        reg_pool_en;
    wire        reg_relu_en;
    wire [1:0]  reg_mode;

    // 32-bit internal stream
    wire [31:0] stream_32_data;
    wire        stream_32_valid;
    wire        stream_32_ready;
    wire        stream_32_last;

    // Window taps
    wire [31:0] tap_i1, tap_i2, tap_i3;
    wire [31:0] tap_i4, tap_i5, tap_i6;
    wire [31:0] tap_i7, tap_i8, tap_i9;
    wire        win_valid;

    // Weight registers
    reg  [31:0] w_reg1, w_reg2, w_reg3;
    reg  [31:0] w_reg4, w_reg5, w_reg6;
    reg  [31:0] w_reg7, w_reg8, w_reg9;
    reg  [31:0] bias_reg;

    // Compute outputs
    wire [31:0] mac_sum;
    wire        mac_valid;

    wire [31:0] accum_data;
    wire        accum_valid;

    reg  [11:0] c_idx;
    reg  [15:0] px_addr;

    wire [31:0] act_pool_data;
    wire        act_pool_valid;

    wire [31:0] fc_out_data;
    wire        fc_out_valid;

    wire [31:0] final_out_data  = (reg_mode == 2'b10) ? fc_out_data : act_pool_data;
    wire        final_out_valid = (reg_mode == 2'b10) ? fc_out_valid : act_pool_valid;
    wire        final_out_ready;

    // 1. AXI-Lite Slave Registers
    axi_lite_regs #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) u_axi_lite (
        .S_AXI_ACLK(aclk),
        .S_AXI_ARESETN(aresetn),
        .S_AXI_AWADDR(s_axi_awaddr),
        .S_AXI_AWVALID(s_axi_awvalid),
        .S_AXI_AWREADY(s_axi_awready),
        .S_AXI_WDATA(s_axi_wdata),
        .S_AXI_WSTRB(s_axi_wstrb),
        .S_AXI_WVALID(s_axi_wvalid),
        .S_AXI_WREADY(s_axi_wready),
        .S_AXI_BRESP(s_axi_bresp),
        .S_AXI_BVALID(s_axi_bvalid),
        .S_AXI_BREADY(s_axi_bready),
        .S_AXI_ARADDR(s_axi_araddr),
        .S_AXI_ARVALID(s_axi_arvalid),
        .S_AXI_ARREADY(s_axi_arready),
        .S_AXI_RDATA(s_axi_rdata),
        .S_AXI_RRESP(s_axi_rresp),
        .S_AXI_RVALID(s_axi_rvalid),
        .S_AXI_RREADY(s_axi_rready),

        .reg_start(reg_start),
        .reg_reset(reg_reset),
        .reg_img_w(reg_img_w),
        .reg_img_h(reg_img_h),
        .reg_cin(reg_cin),
        .reg_cout(reg_cout),
        .reg_pad_en(reg_pad_en),
        .reg_pool_en(reg_pool_en),
        .reg_relu_en(reg_relu_en),
        .reg_mode(reg_mode),
        .core_done(core_done)
    );

    // 2. 64-bit to 32-bit DMA Unpacker
    axis_dwidth_64_to_32 u_dwidth_in (
        .clk(aclk),
        .rst(rst_sync),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(stream_32_data),
        .m_axis_tvalid(stream_32_valid),
        .m_axis_tready(stream_32_ready),
        .m_axis_tlast(stream_32_last)
    );

    // 3. 3-Row Cascaded Line Buffer
    line_buffer_3row #(
        .DATA_WIDTH(32),
        .MAX_LINE_WIDTH(224)
    ) u_line_buffer (
        .clk(aclk),
        .rst(rst_sync),
        .line_width(reg_img_w),
        .padding_en(reg_pad_en),
        .in_data(stream_32_data),
        .in_valid(stream_32_valid),
        .in_ready(stream_32_ready),
        .win_i1(tap_i1), .win_i2(tap_i2), .win_i3(tap_i3),
        .win_i4(tap_i4), .win_i5(tap_i5), .win_i6(tap_i6),
        .win_i7(tap_i7), .win_i8(tap_i8), .win_i9(tap_i9),
        .win_valid(win_valid)
    );

    // 4. Parallel 9-Multiplier MAC Tree (Strictly 36 DSPs)
    mac_tree_9x #(
        .DATA_WIDTH(32)
    ) u_mac_tree (
        .clk(aclk),
        .rst(rst_sync),
        .in_valid(win_valid),
        .i1(tap_i1), .i2(tap_i2), .i3(tap_i3),
        .i4(tap_i4), .i5(tap_i5), .i6(tap_i6),
        .i7(tap_i7), .i8(tap_i8), .i9(tap_i9),
        .w1(w_reg1), .w2(w_reg2), .w3(w_reg3),
        .w4(w_reg4), .w5(w_reg5), .w6(w_reg6),
        .w7(w_reg7), .w8(w_reg8), .w9(w_reg9),
        .sum_out(mac_sum),
        .out_valid(mac_valid)
    );

    // 5. Inter-Channel Accumulator
    accumulator #(
        .DATA_WIDTH(32),
        .MAX_SPATIAL_DIM(50176)
    ) u_accumulator (
        .clk(aclk),
        .rst(rst_sync),
        .conv_sum_in(mac_sum),
        .conv_valid_in(mac_valid),
        .c_in_idx(c_idx),
        .cin_total(reg_cin),
        .bias_in(bias_reg),
        .pixel_addr(px_addr),
        .accum_out(accum_data),
        .accum_valid(accum_valid)
    );

    // 6. ReLU and 2x2 Max-Pooling Engine
    activation_pool #(
        .DATA_WIDTH(32),
        .MAX_LINE_WIDTH(224)
    ) u_act_pool (
        .clk(aclk),
        .rst(rst_sync),
        .pool_en(reg_pool_en),
        .line_width(reg_img_w),
        .in_data(accum_data),
        .in_valid(accum_valid),
        .out_data(act_pool_data),
        .out_valid(act_pool_valid)
    );

    // 7. Fully Connected Engine
    fc_engine #(
        .DATA_WIDTH(32),
        .MAX_INPUT_NODES(4096)
    ) u_fc (
        .clk(aclk),
        .rst(rst_sync),
        .start(reg_start),
        .vec_len(13'd4096),
        .bias_in(bias_reg),
        .relu_en(reg_relu_en),
        .act_in(stream_32_data),
        .act_valid(stream_32_valid),
        .w_in(stream_32_data),
        .w_valid(stream_32_valid),
        .fc_out(fc_out_data),
        .fc_out_valid(fc_out_valid)
    );

    // 8. 32-bit to 64-bit DMA Packer
    axis_dwidth_32_to_64 u_dwidth_out (
        .clk(aclk),
        .rst(rst_sync),
        .s_axis_tdata(final_out_data),
        .s_axis_tvalid(final_out_valid),
        .s_axis_tready(final_out_ready),
        .s_axis_tlast(stream_32_last),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

endmodule
