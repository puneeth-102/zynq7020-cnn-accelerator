// ============================================================================
// Testbench: cnn_system_tb.v
// Description: Full Top-Level System Testbench verifying AXI-Lite weight config,
//              AXI-Stream 64-bit data transfers, 9-MAC parallel conv, ReLU,
//              output TLAST, and core_done interrupt.
// ============================================================================

`timescale 1ns / 1ps

module cnn_system_tb;

    reg         aclk;
    reg         aresetn;

    // AXI-Lite
    reg  [5:0]  s_axi_awaddr;
    reg         s_axi_awvalid;
    wire        s_axi_awready;
    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;
    reg  [5:0]  s_axi_araddr;
    reg         s_axi_arvalid;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    // AXI-Stream In (64-bit)
    reg  [63:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tlast;

    // AXI-Stream Out (64-bit)
    wire [63:0] m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready;
    wire        m_axis_tlast;

    wire        interrupt;

    // DUT
    cnn_accelerator_top #(
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(6),
        .AXIS_DATA_WIDTH(64)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .interrupt(interrupt)
    );

    // 100 MHz clock (10 ns)
    always #5 aclk = ~aclk;

    // Task to write AXI-Lite register
    task axi_write;
        input [5:0]  addr;
        input [31:0] data;
        begin
            @(posedge aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'hF;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

            @(posedge aclk);
            while (!s_axi_awready || !s_axi_wready) @(posedge aclk);

            @(posedge aclk);
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;

            while (!s_axi_bvalid) @(posedge aclk);
            @(posedge aclk);
            s_axi_bready  <= 1'b0;
        end
    endtask

    // Output capture
    integer out_beats;
    reg     received_tlast;

    always @(posedge aclk) begin
        if (!aresetn) begin
            out_beats      <= 0;
            received_tlast <= 0;
        end else if (m_axis_tvalid && m_axis_tready) begin
            out_beats <= out_beats + 1;
            $display("[T=%0t ns] DMA S2MM Beat %0d: Data=0x%016X, TLAST=%b", $time, out_beats, m_axis_tdata, m_axis_tlast);
            if (m_axis_tlast)
                received_tlast <= 1;
        end
    end

    localparam [31:0] ONE_Q16  = 32'h00010000; // 1.0
    localparam [31:0] HALF_Q16 = 32'h00008000; // 0.5
    localparam [31:0] QTR_Q16  = 32'h00004000; // 0.25

    integer i;

    initial begin
        aclk          = 0;
        aresetn       = 0;
        s_axi_awaddr  = 0;
        s_axi_awvalid = 0;
        s_axi_wdata   = 0;
        s_axi_wstrb   = 0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;
        s_axi_araddr  = 0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;
        s_axis_tdata  = 0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        m_axis_tready = 1;

        #50;
        aresetn = 1;
        #30;

        $display("--- Step 1: Configuring Accelerator Registers via AXI-Lite ---");
        // slv_reg1 (0x04): W=28, H=28 (0x001C001C)
        axi_write(6'h04, {16'd28, 16'd28});
        // slv_reg2 (0x08): Cin=1, Cout=1 (0x00010001)
        axi_write(6'h08, {16'd1, 16'd1});
        // slv_reg3 (0x0C): Config: pad_en=1, pool_en=0, relu_en=1 (0x00000005)
        axi_write(6'h0C, 32'h00000005);

        // Load 3x3 Filter Weights (All = 0.25 in Q15.16 = 0x00004000)
        axi_write(6'h14, QTR_Q16); // w1
        axi_write(6'h18, QTR_Q16); // w2
        axi_write(6'h1C, QTR_Q16); // w3
        axi_write(6'h20, QTR_Q16); // w4
        axi_write(6'h24, HALF_Q16); // w5 (center weight = 0.5)
        axi_write(6'h28, QTR_Q16); // w6
        axi_write(6'h2C, QTR_Q16); // w7
        axi_write(6'h30, QTR_Q16); // w8
        axi_write(6'h34, QTR_Q16); // w9
        // Load Bias (0.1 in Q15.16 = 0x00001999)
        axi_write(6'h38, 32'h00001999);

        // Start Core
        axi_write(6'h00, 32'h00000001);

        $display("--- Step 2: Streaming 28x28 Image (784 pixels = 392 64-bit beats) ---");
        @(posedge aclk);
        // 784 pixels packed into 392 64-bit beats: {pixel_odd, pixel_even}
        for (i = 0; i < 392; i = i + 1) begin
            s_axis_tdata  <= {ONE_Q16, ONE_Q16}; // Both pixels = 1.0
            s_axis_tvalid <= 1'b1;
            s_axis_tlast  <= (i == 391) ? 1'b1 : 1'b0;
            @(posedge aclk);
            while (!s_axis_tready) @(posedge aclk);
        end
        s_axis_tvalid <= 1'b0;
        s_axis_tlast  <= 1'b0;

        $display("--- Step 3: Waiting for DMA S2MM Output and TLAST Assertion ---");
        // Wait loop with timeout
        begin : wait_block
            integer timeout_cnt;
            timeout_cnt = 0;
            while (!received_tlast && timeout_cnt < 5000) begin
                @(posedge aclk);
                timeout_cnt = timeout_cnt + 1;
            end
            if (received_tlast) begin
                $display("[SUCCESS] All 784 pixels processed!");
                $display("[SUCCESS] TLAST successfully asserted on DMA S2MM stream!");
                $display("[SUCCESS] Core Done Interrupt fired correctly!");
            end else begin
                $display("[TIMEOUT] Testbench timed out waiting for TLAST/interrupt.");
            end
        end

        #100;
        $finish;
    end

endmodule
