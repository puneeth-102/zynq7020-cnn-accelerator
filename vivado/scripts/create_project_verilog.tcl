# Tcl script to create and synthesize the CNN Accelerator in PURE VERILOG
# Target: ZedBoard (xc7z020clg484-1)
# Target Language: Verilog (Verilog 2001)

set proj_name "zedboard_cnn_verilog"
set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".." ".."]]
set proj_dir   [file normalize [file join $root_dir "vivado" "prj"]]

puts "=========================================================="
puts "Creating Vivado Verilog Project for ZedBoard (xc7z020clg484-1)"
puts "Root Directory: $root_dir"
puts "Project Directory: $proj_dir"
puts "=========================================================="

create_project -force $proj_name $proj_dir -part xc7z020clg484-1

# Set target language to Verilog
set_property target_language Verilog [current_project]

# Target language set to Verilog (default standard is Verilog 2001)

# Add Synthesizable Verilog RTL Sources
add_files -fileset sources_1 [list \
    [file join $root_dir "rtl" "core" "line_buffer_3row.v"] \
    [file join $root_dir "rtl" "core" "mac_tree_9x.v"] \
    [file join $root_dir "rtl" "core" "accumulator.v"] \
    [file join $root_dir "rtl" "core" "activation_pool.v"] \
    [file join $root_dir "rtl" "core" "fc_engine.v"] \
    [file join $root_dir "rtl" "axi" "axi_lite_regs.v"] \
    [file join $root_dir "rtl" "axi" "axis_dwidth_64_to_32.v"] \
    [file join $root_dir "rtl" "axi" "axis_dwidth_32_to_64.v"] \
    [file join $root_dir "rtl" "top" "cnn_accelerator_top.v"] \
]

# Set Top Module
set_property top cnn_accelerator_top [current_fileset]

# Add Timing Constraints
add_files -fileset constrs_1 [list [file join $root_dir "vivado" "constraints" "timing.xdc"]]

# Add Simulation Testbenches
add_files -fileset sim_1 [list [file join $root_dir "tb" "unit" "mac_tree_tb.v"]]
set_property top mac_tree_tb [get_filesets sim_1]

# Update Compile Order
update_compile_order -fileset sources_1

puts "=========================================================="
puts "Checking Verilog Syntax..."
puts "=========================================================="
check_syntax

puts "=========================================================="
puts "Launching Synthesis for Verilog cnn_accelerator_top..."
puts "=========================================================="
launch_runs synth_1 -jobs 4
wait_on_run synth_1

open_run synth_1 -name synth_1

puts "=========================================================="
puts "VERILOG SYNTHESIS UTILIZATION REPORT:"
puts "=========================================================="
report_utilization -name util_1

close_project
puts "SUCCESS: Verilog project and synthesis completed successfully."

