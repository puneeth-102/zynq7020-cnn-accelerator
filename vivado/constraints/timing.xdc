# Timing Constraints for Zynq-7020 CNN Accelerator
# Sourced from Section 5 of:
# "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
# (Sensors 2026, 26, 1626)

# 100 MHz PL Clock Period = 10.0 ns
create_clock -period 10.000 -name aclk -waveform {0.000 5.000} [get_ports aclk]

# Set false paths on asynchronous resets if needed
set_false_path -through [get_ports aresetn]
