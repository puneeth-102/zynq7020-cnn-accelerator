// ============================================================================
// Module: axis_dwidth_64_to_32.v
// Description: Unpacks 64-bit HP0 AXI-Stream DMA beats into two consecutive
//              32-bit Q15.16 samples in Verilog-2001.
// ============================================================================

`timescale 1ns / 1ps

module axis_dwidth_64_to_32 (
    input  wire        clk,
    input  wire        rst,

    // 64-bit Slave Interface (from DMA MM2S)
    input  wire [63:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output reg         s_axis_tready,
    input  wire        s_axis_tlast,

    // 32-bit Master Interface (to Accelerator Input)
    output reg  [31:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg         m_axis_tlast
);

    localparam IDLE       = 2'd0;
    localparam SEND_WORD1 = 2'd1;

    reg [1:0]  state;
    reg [31:0] latched_high;
    reg        latched_last;

    always @(posedge clk) begin
        if (rst) begin
            state         <= IDLE;
            s_axis_tready <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= 32'd0;
            m_axis_tlast  <= 1'b0;
            latched_high  <= 32'd0;
            latched_last  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    s_axis_tready <= 1'b1;
                    if (s_axis_tvalid) begin
                        latched_high  <= s_axis_tdata[63:32];
                        latched_last  <= s_axis_tlast;
                        m_axis_tdata  <= s_axis_tdata[31:0];
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= 1'b0;
                        s_axis_tready <= 1'b0;
                        state         <= SEND_WORD1;
                    end else begin
                        m_axis_tvalid <= 1'b0;
                    end
                end

                SEND_WORD1: begin
                    if (m_axis_tready) begin
                        m_axis_tdata  <= latched_high;
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= latched_last;
                        s_axis_tready <= 1'b1;
                        state         <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
