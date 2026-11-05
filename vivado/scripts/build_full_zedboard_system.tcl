# Master Tcl script: Complete PS + PL Block Design for ZedBoard
# Target Device: xc7z020clg484-1 (ZedBoard)
# Interfaces:
#   â€¢ AXI GP0 (32-bit): PS ARM -> AXI-Lite Regs (DMA & CNN Accel)
#   â€¢ AXI HP0 (64-bit): AXI DMA (MM2S & S2MM) -> DDR3 Controller
#   â€¢ AXI-Stream: DMA MM2S -> CNN Core -> DMA S2MM (64-bit wide)

set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".." ".."]]
set ip_dir     [file normalize [file join $root_dir "vivado" "ip_repo" "cnn_accelerator_v1_0"]]
set proj_file  [file normalize [file join $root_dir "vivado" "zedboard_cnn_sys.xpr"]]
if {![file exists $proj_file]} {
    set proj_file "C:/Users/HP PC/zedboard_cnn_verilog_prj/zedboard_cnn_verilog.xpr"
}

puts "=========================================================="
puts "BUILDING FULL ZEDBOARD SYSTEM BLOCK DESIGN & BITSTREAM"
puts "Target: xc7z020clg484-1"
puts "=========================================================="

open_project $proj_file

# Add custom IP repository to project
set_property ip_repo_paths [list $ip_dir] [current_project]
update_ip_catalog

# Check if Block Design already exists
set bd_files [get_files *zedboard_cnn_sys.bd]
if {[llength $bd_files] > 0} {
    puts "Opening existing Block Design 'zedboard_cnn_sys.bd'..."
    open_bd_design [lindex $bd_files 0]
} else {
    # Create Block Design
    create_bd_design "zedboard_cnn_sys"

    # 1. Processing System 7 (Zynq PS)
    create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7_0
    set_property -dict [list \
        CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
        CONFIG.PCW_USE_S_AXI_HP0 {1} \
        CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
        CONFIG.PCW_USE_M_AXI_GP0 {1} \
        CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
        CONFIG.PCW_IRQ_F2P_INTR {1} \
    ] [get_bd_cells ps7_0]

    # Apply ZedBoard board preset for PS7
    catch {
        apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" } [get_bd_cells ps7_0]
    }

    # 2. AXI Direct Memory Access (AXI DMA)
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
    set_property -dict [list \
        CONFIG.c_include_sg {0} \
        CONFIG.c_sg_include_stscntrl_strm {0} \
        CONFIG.c_m_axi_mm2s_data_width {64} \
        CONFIG.c_m_axi_s2mm_data_width {64} \
        CONFIG.c_mm2s_burst_size {16} \
        CONFIG.c_s2mm_burst_size {16} \
    ] [get_bd_cells axi_dma_0]

    # 3. Custom CNN Accelerator IP (Packaged Core)
    create_bd_cell -type ip -vlnv usv_vision:user:cnn_accelerator_top:1.0 cnn_accel_0

    # 4. Processor System Reset
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_100M

    # 5. AXI Interconnect for GP0 (Control Path - 32-bit)
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_ic_gp0
    set_property -dict [list CONFIG.NUM_MI {2}] [get_bd_cells axi_ic_gp0]

    # 6. AXI SmartConnect for HP0 (Data Path - 64-bit)
    create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_hp0
    set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1}] [get_bd_cells axi_smc_hp0]

    # ================= Connect Clocks and Resets (100 MHz) =================
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

    # ================= Connect Control Path (GP0 -> AXI-Lite) =================
    connect_bd_intf_net [get_bd_intf_pins ps7_0/M_AXI_GP0]     [get_bd_intf_pins axi_ic_gp0/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins axi_ic_gp0/M00_AXI] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
    connect_bd_intf_net [get_bd_intf_pins axi_ic_gp0/M01_AXI] [get_bd_intf_pins cnn_accel_0/s_axi]

    # ================= Connect Streaming Data Path (AXI-Stream) =================
    connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins cnn_accel_0/s_axis]
    connect_bd_intf_net [get_bd_intf_pins cnn_accel_0/m_axis]    [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

    # ================= Connect High Performance Port (HP0) =================
    connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins axi_smc_hp0/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins axi_smc_hp0/S01_AXI]
    connect_bd_intf_net [get_bd_intf_pins axi_smc_hp0/M00_AXI]  [get_bd_intf_pins ps7_0/S_AXI_HP0]

    # Connect Interrupt
    connect_bd_net [get_bd_pins cnn_accel_0/interrupt] [get_bd_pins ps7_0/IRQ_F2P]

    # Auto-assign Memory Addresses
    assign_bd_address

    # Validate Block Design
    validate_bd_design
    save_bd_design
}

puts "=========================================================="
puts "SUCCESS: Block design 'zedboard_cnn_sys' created and validated."
puts "=========================================================="

# Create Top HDL Wrapper
set bd_file [get_files *zedboard_cnn_sys.bd]
set wrapper_file [make_wrapper -files $bd_file -top]
add_files -norecurse [list $wrapper_file]
set_property top zedboard_cnn_sys_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Launch Synthesis and Implementation to generate Bitstream
puts "=========================================================="
puts "LAUNCHING FULL IMPLEMENTATION & BITSTREAM GENERATION"
puts "=========================================================="
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "=========================================================="
puts "BITSTREAM GENERATION COMPLETED!"
puts "=========================================================="

close_project

