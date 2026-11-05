# Tcl script to check syntax and run quick synthesis of CNN accelerator top
set proj_file "C:/Users/HP PC/zynq7020_cnn_prj/zynq7020_cnn_accel.xpr"

puts "Opening Vivado Project..."
open_project $proj_file

# Check syntax of all added VHDL files
puts "=========================================================="
puts "Checking RTL Syntax..."
puts "=========================================================="
check_syntax

# Update compile order
update_compile_order -fileset sources_1

# Run Synthesis (Out of Context or Top-level)
puts "=========================================================="
puts "Launching Synthesis for cnn_accelerator_top..."
puts "=========================================================="
launch_runs synth_1 -jobs 4
wait_on_run synth_1

open_run synth_1 -name synth_1

# Report Resource Utilization
puts "=========================================================="
puts "SYNTHESIS RESOURCE UTILIZATION REPORT:"
puts "=========================================================="
report_utilization -name util_1

puts "=========================================================="
puts "CHECKING DSP UTILIZATION (Target = 36 DSPs):"
puts "=========================================================="
report_utilization -cells [get_cells -hier *]

close_project
