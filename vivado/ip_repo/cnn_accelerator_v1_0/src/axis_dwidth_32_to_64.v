// ============================================================================
// Module: axis_dwidth_32_to_64.v
// Description: Packs two consecutive 32-bit Q15.16 output samples into one
//              64-bit beat for AXI DMA S2MM write back in Verilog-2001.
// ============================================================================

`timescale 1ns / 1ps

module axis_dwidth_32_to_64 (
    input  wire        clk,
    input  wire        rst,

    // 32-bit Slave Interface (from Accelerator Output)
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output reg         s_axis_tready,
    input  wire        s_axis_tlast,

    // 64-bit Master Interface (to DMA S2MM)
    output reg  [63:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg         m_axis_tlast
);

    localparam WAIT_FIRST  = 2'd0;
    localparam WAIT_SECOND = 2'd1;
    localparam TRANSMIT    = 2'd2;

    reg [1:0]  state;
    reg [31:0] word0;

    always @(posedge clk) begin
        if (rst) begin
            state         <= WAIT_FIRST;
            s_axis_tready <= 1'b1;
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= 64'd0;
            m_axis_tlast  <= 1'b0;
            word0         <= 32'd0;
        end else begin
            case (state)
                WAIT_FIRST: begin
                    m_axis_tvalid <= 1'b0;
                    s_axis_tready <= 1'b1;
                    if (s_axis_tvalid) begin
                        word0 <= s_axis_tdata;
                        if (s_axis_tlast) begin
                            m_axis_tdata  <= {32'd0, s_axis_tdata};
                            m_axis_tvalid <= 1'b1;
                            m_axis_tlast  <= 1'b1;
                            s_axis_tready <= 1'b0;
                            state         <= TRANSMIT;
                        end else begin
                            state <= WAIT_SECOND;
                        end
                    end
                end

                WAIT_SECOND: begin
                    if (s_axis_tvalid) begin
                        m_axis_tdata  <= {s_axis_tdata, word0};
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= s_axis_tlast;
                        s_axis_tready <= 1'b0;
                        state         <= TRANSMIT;
                    end
                end

                TRANSMIT: begin
                    if (m_axis_tready) begin
                        m_axis_tvalid <= 1'b0;
                        s_axis_tready <= 1'b1;
                        state         <= WAIT_FIRST;
                    end
                end

                default: state <= WAIT_FIRST;
            endcase
        end
    end

endmodule
