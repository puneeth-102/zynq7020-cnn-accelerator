# ==============================================================================
# Script: run_simulation.tcl
# Description: Automated Vivado Simulation for Zynq-7020 CNN Accelerator
# ==============================================================================

set SCRIPT_PATH [file normalize [info script]]
set SCRIPT_DIR  [file dirname $SCRIPT_PATH]
set REPO_ROOT   [file normalize [file join $SCRIPT_DIR ".." ".."]]
set PROJ_FILE   [file normalize [file join $REPO_ROOT "vivado" "zedboard_cnn_sys.xpr"]]

puts "============================================================"
puts "Opening Vivado Project: $PROJ_FILE"
puts "============================================================"
open_project $PROJ_FILE

# Set top simulation module
set_property top cnn_full_demo_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "============================================================"
puts "Launching Behavioral Simulation..."
puts "============================================================"
launch_simulation

# Run for 15 microseconds (full 784-pixel execution)
run 15 us

puts "\n============================================================"
puts "Vivado Behavioral Simulation Completed Successfully!"
puts "View the waveforms in the Vivado Waveform Window."
puts "============================================================\n"
