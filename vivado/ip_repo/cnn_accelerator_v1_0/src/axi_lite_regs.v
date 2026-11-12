// ============================================================================
// Module: axi_lite_regs.v
// Description: Standard AXI4-Lite Slave Register Bank for Accelerator Control
//              and Filter Weights in Verilog-2001.
// 
// Reproduces Section 4.1 & Figure 5 of:
// "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
// (Sensors 2026, 26, 1626)
// ============================================================================

`timescale 1ns / 1ps

module axi_lite_regs #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 6
)(
    input  wire                          S_AXI_ACLK,
    input  wire                          S_AXI_ARESETN,

    // Write Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire                          S_AXI_AWVALID,
    output reg                           S_AXI_AWREADY,

    // Write Data Channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                          S_AXI_WVALID,
    output reg                           S_AXI_WREADY,

    // Write Response Channel
    output wire [1:0]                    S_AXI_BRESP,
    output reg                           S_AXI_BVALID,
    input  wire                          S_AXI_BREADY,

    // Read Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire                          S_AXI_ARVALID,
    output reg                           S_AXI_ARREADY,

    // Read Data Channel
    output reg  [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output wire [1:0]                    S_AXI_RRESP,
    output reg                           S_AXI_RVALID,
    input  wire                          S_AXI_RREADY,

    // Decoded Control Signals to Accelerator Core
    output wire                          reg_start,
    output wire                          reg_reset,
    output wire [10:0]                   reg_img_w,
    output wire [10:0]                   reg_img_h,
    output wire [11:0]                   reg_cin,
    output wire [11:0]                   reg_cout,
    output wire                          reg_pad_en,
    output wire                          reg_pool_en,
    output wire                          reg_relu_en,
    output wire [1:0]                    reg_mode,

    // 3x3 Filter Weights and Bias (Q15.16 Fixed Point)
    output wire [31:0]                   reg_w1,
    output wire [31:0]                   reg_w2,
    output wire [31:0]                   reg_w3,
    output wire [31:0]                   reg_w4,
    output wire [31:0]                   reg_w5,
    output wire [31:0]                   reg_w6,
    output wire [31:0]                   reg_w7,
    output wire [31:0]                   reg_w8,
    output wire [31:0]                   reg_w9,
    output wire [31:0]                   reg_bias,

    input  wire                          core_done
);

    assign S_AXI_BRESP = 2'b00; // OKAY
    assign S_AXI_RRESP = 2'b00; // OKAY

    // Internal Registers (16 x 32-bit mapped via 6-bit byte address [5:2])
    reg [31:0] slv_reg0;  // 0x00: Control: [0]=start, [1]=done, [2]=reset
    reg [31:0] slv_reg1;  // 0x04: Dims: [15:0]=W, [31:16]=H
    reg [31:0] slv_reg2;  // 0x08: Channels: [15:0]=Cin, [31:16]=Cout
    reg [31:0] slv_reg3;  // 0x0C: Config: [0]=pad, [1]=pool, [2]=relu, [4:3]=mode
    reg [31:0] slv_reg4;  // 0x10: Status / Reserved
    reg [31:0] slv_reg5;  // 0x14: Weight w1
    reg [31:0] slv_reg6;  // 0x18: Weight w2
    reg [31:0] slv_reg7;  // 0x1C: Weight w3
    reg [31:0] slv_reg8;  // 0x20: Weight w4
    reg [31:0] slv_reg9;  // 0x24: Weight w5
    reg [31:0] slv_reg10; // 0x28: Weight w6
    reg [31:0] slv_reg11; // 0x2C: Weight w7
    reg [31:0] slv_reg12; // 0x30: Weight w8
    reg [31:0] slv_reg13; // 0x34: Weight w9
    reg [31:0] slv_reg14; // 0x38: Bias
    reg [31:0] slv_reg15; // 0x3C: Reserved

    assign reg_start   = slv_reg0[0];
    assign reg_reset   = slv_reg0[2];
    assign reg_img_w   = slv_reg1[10:0];
    assign reg_img_h   = slv_reg1[26:16];
    assign reg_cin     = slv_reg2[11:0];
    assign reg_cout    = slv_reg2[27:16];
    assign reg_pad_en  = slv_reg3[0];
    assign reg_pool_en = slv_reg3[1];
    assign reg_relu_en = slv_reg3[2];
    assign reg_mode    = slv_reg3[4:3];

    assign reg_w1      = slv_reg5;
    assign reg_w2      = slv_reg6;
    assign reg_w3      = slv_reg7;
    assign reg_w4      = slv_reg8;
    assign reg_w5      = slv_reg9;
    assign reg_w6      = slv_reg10;
    assign reg_w7      = slv_reg11;
    assign reg_w8      = slv_reg12;
    assign reg_w9      = slv_reg13;
    assign reg_bias    = slv_reg14;

    reg aw_en;

    // AXI Write Channel Logic
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            aw_en         <= 1'b1;
            slv_reg0      <= 32'd0;
            slv_reg1      <= {16'd224, 16'd224};
            slv_reg2      <= {16'd1, 16'd1};
            slv_reg3      <= 32'h00000005; // pad_en=1, pool_en=0, relu_en=1
            slv_reg4      <= 32'd0;
            slv_reg5      <= 32'd0;
            slv_reg6      <= 32'd0;
            slv_reg7      <= 32'd0;
            slv_reg8      <= 32'd0;
            slv_reg9      <= 32'd0;
            slv_reg10     <= 32'd0;
            slv_reg11     <= 32'd0;
            slv_reg12     <= 32'd0;
            slv_reg13     <= 32'd0;
            slv_reg14     <= 32'd0;
            slv_reg15     <= 32'd0;
        end else begin
            if (~S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                S_AXI_AWREADY <= 1'b1;
                S_AXI_WREADY  <= 1'b1;
                aw_en         <= 1'b0;
            end else begin
                S_AXI_AWREADY <= 1'b0;
                S_AXI_WREADY  <= 1'b0;
                if (S_AXI_BREADY && S_AXI_BVALID)
                    aw_en <= 1'b1;
            end

            if (S_AXI_WVALID && S_AXI_AWVALID && S_AXI_AWREADY && S_AXI_WREADY) begin
                case (S_AXI_AWADDR[5:2])
                    4'h0: slv_reg0  <= S_AXI_WDATA;
                    4'h1: slv_reg1  <= S_AXI_WDATA;
                    4'h2: slv_reg2  <= S_AXI_WDATA;
                    4'h3: slv_reg3  <= S_AXI_WDATA;
                    4'h4: slv_reg4  <= S_AXI_WDATA;
                    4'h5: slv_reg5  <= S_AXI_WDATA;
                    4'h6: slv_reg6  <= S_AXI_WDATA;
                    4'h7: slv_reg7  <= S_AXI_WDATA;
                    4'h8: slv_reg8  <= S_AXI_WDATA;
                    4'h9: slv_reg9  <= S_AXI_WDATA;
                    4'hA: slv_reg10 <= S_AXI_WDATA;
                    4'hB: slv_reg11 <= S_AXI_WDATA;
                    4'hC: slv_reg12 <= S_AXI_WDATA;
                    4'hD: slv_reg13 <= S_AXI_WDATA;
                    4'hE: slv_reg14 <= S_AXI_WDATA;
                    4'hF: slv_reg15 <= S_AXI_WDATA;
                endcase
            end else if (core_done) begin
                slv_reg0[1] <= 1'b1; // Done flag set
                slv_reg0[0] <= 1'b0; // Clear start
            end

            if (S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WREADY && S_AXI_WVALID && ~S_AXI_BVALID)
                S_AXI_BVALID <= 1'b1;
            else if (S_AXI_BREADY && S_AXI_BVALID)
                S_AXI_BVALID <= 1'b0;
        end
    end

    // AXI Read Channel Logic
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RDATA   <= 32'd0;
        end else begin
            if (~S_AXI_ARREADY && S_AXI_ARVALID)
                S_AXI_ARREADY <= 1'b1;
            else
                S_AXI_ARREADY <= 1'b0;

            if (S_AXI_ARREADY && S_AXI_ARVALID && ~S_AXI_RVALID) begin
                S_AXI_RVALID <= 1'b1;
                case (S_AXI_ARADDR[5:2])
                    4'h0: S_AXI_RDATA <= slv_reg0;
                    4'h1: S_AXI_RDATA <= slv_reg1;
                    4'h2: S_AXI_RDATA <= slv_reg2;
                    4'h3: S_AXI_RDATA <= slv_reg3;
                    4'h4: S_AXI_RDATA <= slv_reg4;
                    4'h5: S_AXI_RDATA <= slv_reg5;
                    4'h6: S_AXI_RDATA <= slv_reg6;
                    4'h7: S_AXI_RDATA <= slv_reg7;
                    4'h8: S_AXI_RDATA <= slv_reg8;
                    4'h9: S_AXI_RDATA <= slv_reg9;
                    4'hA: S_AXI_RDATA <= slv_reg10;
                    4'hB: S_AXI_RDATA <= slv_reg11;
                    4'hC: S_AXI_RDATA <= slv_reg12;
                    4'hD: S_AXI_RDATA <= slv_reg13;
                    4'hE: S_AXI_RDATA <= slv_reg14;
                    4'hF: S_AXI_RDATA <= slv_reg15;
                    default: S_AXI_RDATA <= 32'd0;
                endcase
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

endmodule
