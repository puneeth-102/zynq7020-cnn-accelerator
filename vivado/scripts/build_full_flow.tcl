# Master Vivado Tcl script: Complete Build Flow
# From RTL -> Block Design -> Synthesis -> Place & Route -> Timing Check -> Bitstream
# Target: Xilinx Zynq-7020 (ZedBoard)

set script_dir [file dirname [info script]]

puts "=========================================================="
puts "STARTING MASTER VIVADO BUILD FLOW FOR CNN ACCELERATOR"
puts "Target: Zynq-7020 (XC7Z020CLG484-1)"
puts "=========================================================="

# 1. Create Project and Add Sources
source [file join $script_dir "create_project.tcl"]

# 2. Build PS + PL Block Design
source [file join $script_dir "build_block_design.tcl"]

# 3. Create HDL Wrapper for Block Design
set bd_file [get_files *zynq_cnn_sys.bd]
make_wrapper -files $bd_file -top
add_files -norecurse [file rootname $bd_file]_wrapper.vhd
set_property top zynq_cnn_sys_wrapper [current_fileset]
update_compile_order -fileset sources_1

# 4. Run Synthesis
puts "=========================================================="
puts "[STEP 1/3] Running Synthesis (Checking 36 DSPs & Resource Target)..."
puts "=========================================================="
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check Synthesis Utilization
open_run synth_1 -name synth_1
report_utilization -file [file join $root_dir "doc" "synth_utilization.rpt"]
puts "[OK] Synthesis Utilization written to doc/synth_utilization.rpt"

# 5. Run Implementation & Timing Closure (100 MHz target)
puts "=========================================================="
puts "[STEP 2/3] Running Implementation (Place & Route)..."
puts "=========================================================="
set_property strategy Performance_Explore [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# 6. Post-Implementation Timing and Power Reports
open_run impl_1
report_timing_summary -file [file join $root_dir "doc" "timing_summary.rpt"]
report_utilization -file [file join $root_dir "doc" "impl_utilization.rpt"]
report_power -file [file join $root_dir "doc" "power_estimate.rpt"]

puts "=========================================================="
puts "[STEP 3/3] Bitstream Generated Successfully!"
puts "           Exporting .bit and .hwh for PYNQ..."
puts "=========================================================="

# Export Hardware Files for PYNQ
set bit_src [get_property DIRECTORY [get_runs impl_1]]/zynq_cnn_sys_wrapper.bit
set hwh_src [get_property DIRECTORY [current_project]]/${proj_name}.srcs/sources_1/bd/zynq_cnn_sys/hw_handoff/zynq_cnn_sys.hwh

set pynq_out [file join $root_dir "sw" "pynq_driver"]
if {[file exists $bit_src]} {
    file copy -force $bit_src [file join $pynq_out "cnn_accelerator.bit"]
    puts "[EXPORT] cnn_accelerator.bit copied to $pynq_out"
}
if {[file exists $hwh_src]} {
    file copy -force $hwh_src [file join $pynq_out "cnn_accelerator.hwh"]
    puts "[EXPORT] cnn_accelerator.hwh copied to $pynq_out"
}

puts "=========================================================="
puts "MASTER BUILD FLOW COMPLETED SUCCESSFULLY!"
puts "=========================================================="
