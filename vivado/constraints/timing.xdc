# Timing Constraints for Zynq-7020 CNN Accelerator
# Sourced from Section 5 of:
# "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
# (Sensors 2026, 26, 1626)
# Target: ZedBoard xc7z020clg484-1 @ 100 MHz

# Note: In the full PS+PL Block Design, 100 MHz clock (10.0 ns) is automatically
# propagated from Zynq PS7 FCLK_CLK0 (clk_fpga_0).
# The constraint below is active for standalone out-of-context synthesis.

if {[llength [get_ports -quiet aclk]] > 0} {
    create_clock -period 10.000 -name aclk -waveform {0.000 5.000} [get_ports aclk]
}

if {[llength [get_ports -quiet aresetn]] > 0} {
    set_false_path -through [get_ports aresetn]
}

# Static configuration registers (written once by CPU prior to DMA streaming)
set_false_path -from [get_cells -hier -filter {NAME =~ *u_axi_lite/slv_reg* && IS_PRIMITIVE}]
