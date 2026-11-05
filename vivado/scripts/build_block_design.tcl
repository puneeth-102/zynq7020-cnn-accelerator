# Tcl script to build complete Zynq PS + PL Block Design (BD)
# Interconnects:
#   • Zynq PS7: FCLK_CLK0 = 100 MHz, M_AXI_GP0 (Control), S_AXI_HP0 (64-bit Data)
#   • AXI DMA: Simple Register Mode, 64-bit Stream (MM2S & S2MM)
#   • Custom CNN Accelerator: cnn_accelerator_top
#   • SmartConnect / AXI Interconnect & Processor System Reset

proc create_bd_design {} {
    create_bd_design "zynq_cnn_sys"

    # 1. Processing System 7 (PS7)
    create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7_0
    set_property -dict [list \
        CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
        CONFIG.PCW_USE_S_AXI_HP0 {1} \
        CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
        CONFIG.PCW_USE_M_AXI_GP0 {1} \
        CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
        CONFIG.PCW_IRQ_F2P_INTR {1} \
    ] [get_bd_cells ps7_0]

    # 2. AXI Direct Memory Access (AXI DMA)
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
    set_property -dict [list \
        CONFIG.c_include_sg {0} \
        CONFIG.c_sg_include_stscntrl_strm {0} \
        CONFIG.c_m_axis_mm2s_tdata_width {64} \
        CONFIG.c_s_axis_s2mm_tdata_width {64} \
        CONFIG.c_m_axi_mm2s_data_width {64} \
        CONFIG.c_m_axi_s2mm_data_width {64} \
        CONFIG.c_mm2s_burst_size {16} \
        CONFIG.c_s2mm_burst_size {16} \
    ] [get_bd_cells axi_dma_0]

    # 3. Processor System Reset
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_100M

    # 4. AXI Interconnect for GP0 (Control Path - 32-bit)
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_ic_gp0
    set_property -dict [list CONFIG.NUM_MI {2}] [get_bd_cells axi_ic_gp0]

    # 5. AXI SmartConnect for HP0 (Data Path - 64-bit)
    create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_hp0
    set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1}] [get_bd_cells axi_smc_hp0]

    # 6. Add RTL Accelerator Module
    create_bd_cell -type module -reference cnn_accelerator_top cnn_accel_0

    # ================= Clock & Reset Connections =================
    connect_bd_net [get_bd_pins ps7_0/FCLK_CLK0] \
                   [get_bd_pins ps7_0/M_AXI_GP0_ACLK] \
                   [get_bd_pins ps7_0/S_AXI_HP0_ACLK] \
                   [get_bd_pins rst_ps7_100M/slowest_sync_clk] \
                   [get_bd_pins axi_dma_0/s_axi_lite_aclk] \
                   [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] \
                   [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] \
                   [get_bd_pins axi_ic_gp0/ACLK] \
                   [get_bd_pins axi_ic_gp0/S00_ACLK] \
                   [get_bd_pins axi_ic_gp0/M00_ACLK] \
                   [get_bd_pins axi_ic_gp0/M01_ACLK] \
                   [get_bd_pins axi_smc_hp0/aclk] \
                   [get_bd_pins cnn_accel_0/aclk]

    connect_bd_net [get_bd_pins ps7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_100M/ext_reset_in]
    connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] \
                   [get_bd_pins axi_ic_gp0/ARESETN] \
                   [get_bd_pins axi_ic_gp0/S00_ARESETN] \
                   [get_bd_pins axi_ic_gp0/M00_ARESETN] \
                   [get_bd_pins axi_ic_gp0/M01_ARESETN] \
                   [get_bd_pins axi_smc_hp0/aresetn] \
                   [get_bd_pins axi_dma_0/axi_resetn] \
                   [get_bd_pins cnn_accel_0/aresetn]

    # ================= Control Path (AXI-Lite) =================
    connect_bd_intf_net [get_bd_intf_pins ps7_0/M_AXI_GP0] [get_bd_intf_pins axi_ic_gp0/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins axi_ic_gp0/M00_AXI] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
    # Connect to custom accelerator AXI-Lite
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_awaddr]  [get_bd_pins cnn_accel_0/s_axi_awaddr]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_awvalid] [get_bd_pins cnn_accel_0/s_axi_awvalid]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_awready] [get_bd_pins cnn_accel_0/s_axi_awready]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_wdata]   [get_bd_pins cnn_accel_0/s_axi_wdata]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_wvalid]  [get_bd_pins cnn_accel_0/s_axi_wvalid]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_wready]  [get_bd_pins cnn_accel_0/s_axi_wready]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_bresp]   [get_bd_pins cnn_accel_0/s_axi_bresp]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_bvalid]  [get_bd_pins cnn_accel_0/s_axi_bvalid]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_bready]  [get_bd_pins cnn_accel_0/s_axi_bready]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_araddr]  [get_bd_pins cnn_accel_0/s_axi_araddr]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_arvalid] [get_bd_pins cnn_accel_0/s_axi_arvalid]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_arready] [get_bd_pins cnn_accel_0/s_axi_arready]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_rdata]   [get_bd_pins cnn_accel_0/s_axi_rdata]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_rresp]   [get_bd_pins cnn_accel_0/s_axi_rresp]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_rvalid]  [get_bd_pins cnn_accel_0/s_axi_rvalid]
    connect_bd_net [get_bd_pins axi_ic_gp0/M01_AXI_rready]  [get_bd_pins cnn_accel_0/s_axi_rready]

    # ================= Data Path (AXI-Stream) =================
    # DMA MM2S -> Accelerator
    connect_bd_net [get_bd_pins axi_dma_0/m_axis_mm2s_tdata]  [get_bd_pins cnn_accel_0/s_axis_tdata]
    connect_bd_net [get_bd_pins axi_dma_0/m_axis_mm2s_tvalid] [get_bd_pins cnn_accel_0/s_axis_tvalid]
    connect_bd_net [get_bd_pins axi_dma_0/m_axis_mm2s_tready] [get_bd_pins cnn_accel_0/s_axis_tready]
    connect_bd_net [get_bd_pins axi_dma_0/m_axis_mm2s_tlast]  [get_bd_pins cnn_accel_0/s_axis_tlast]

    # Accelerator -> DMA S2MM
    connect_bd_net [get_bd_pins cnn_accel_0/m_axis_tdata]  [get_bd_pins axi_dma_0/s_axis_s2mm_tdata]
    connect_bd_net [get_bd_pins cnn_accel_0/m_axis_tvalid] [get_bd_pins axi_dma_0/s_axis_s2mm_tvalid]
    connect_bd_net [get_bd_pins cnn_accel_0/m_axis_tready] [get_bd_pins axi_dma_0/s_axis_s2mm_tready]
    connect_bd_net [get_bd_pins cnn_accel_0/m_axis_tlast]  [get_bd_pins axi_dma_0/s_axis_s2mm_tlast]

    # ================= High Performance Port (HP0) =================
    connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins axi_smc_hp0/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins axi_smc_hp0/S01_AXI]
    connect_bd_intf_net [get_bd_intf_pins axi_smc_hp0/M00_AXI]  [get_bd_intf_pins ps7_0/S_AXI_HP0]

    # Assign Addresses
    assign_bd_address

    puts "[OK] Block design 'zynq_cnn_sys' created and wired successfully."
}

create_bd_design
