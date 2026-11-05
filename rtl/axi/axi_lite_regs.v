// ============================================================================
// Module: axi_lite_regs.v
// Description: Standard AXI4-Lite Slave Register Bank for Accelerator Control
//              in Verilog-2001.
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

    input  wire                          core_done
);

    assign S_AXI_BRESP = 2'b00; // OKAY
    assign S_AXI_RRESP = 2'b00; // OKAY

    // Internal Registers
    reg [31:0] slv_reg0; // Control: [0]=start, [1]=done, [2]=reset
    reg [31:0] slv_reg1; // Dims: [15:0]=W, [31:16]=H
    reg [31:0] slv_reg2; // Channels: [15:0]=Cin, [31:16]=Cout
    reg [31:0] slv_reg3; // Config: [0]=pad, [1]=pool, [2]=relu, [4:3]=mode
    reg [31:0] slv_reg4;

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
            slv_reg2      <= {16'd3, 16'd3};
            slv_reg3      <= 32'h00000007;
            slv_reg4      <= 32'd0;
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
                    4'h0: slv_reg0 <= S_AXI_WDATA;
                    4'h1: slv_reg1 <= S_AXI_WDATA;
                    4'h2: slv_reg2 <= S_AXI_WDATA;
                    4'h3: slv_reg3 <= S_AXI_WDATA;
                    4'h4: slv_reg4 <= S_AXI_WDATA;
                endcase
            end else if (core_done) begin
                slv_reg0[1] <= 1'b1; // Done
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
                    default: S_AXI_RDATA <= 32'd0;
                endcase
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

endmodule
