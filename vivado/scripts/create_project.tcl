# Tcl script to automate Vivado Project Creation and Synthesis
# Target: Xilinx Zynq-7020 (ZedBoard)
# Vivado Version: 2018.2 / 2018.3 compatible

set proj_name "zynq7020_cnn_accel"
set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".." ".."]]
set proj_dir   "C:/Users/HP PC/zynq7020_cnn_prj"

puts "=========================================================="
puts "Creating Vivado Project for CNN Accelerator on Zynq-7020"
puts "Target Part: xc7z020clg484-1 (ZedBoard)"
puts "Root Directory: $root_dir"
puts "Project Directory: $proj_dir"
puts "=========================================================="

create_project -force $proj_name $proj_dir -part xc7z020clg484-1

# Set target language to VHDL
set_property target_language VHDL [current_project]

# Add Synthesizable RTL Sources (Using [list ...] for spaces in path)
add_files -fileset sources_1 [list \
    [file join $root_dir "rtl" "core" "line_buffer_3row.vhd"] \
    [file join $root_dir "rtl" "core" "mac_tree_9x.vhd"] \
    [file join $root_dir "rtl" "core" "accumulator.vhd"] \
    [file join $root_dir "rtl" "core" "activation_pool.vhd"] \
    [file join $root_dir "rtl" "core" "fc_engine.vhd"] \
    [file join $root_dir "rtl" "axi" "axi_lite_regs.vhd"] \
    [file join $root_dir "rtl" "axi" "axis_dwidth_64_to_32.vhd"] \
    [file join $root_dir "rtl" "axi" "axis_dwidth_32_to_64.vhd"] \
    [file join $root_dir "rtl" "top" "cnn_accelerator_top.vhd"] \
]

# Set Top Module
set_property top cnn_accelerator_top [current_fileset]

# Add Timing Constraints
add_files -fileset constrs_1 [list [file join $root_dir "vivado" "constraints" "timing.xdc"]]

# Add Simulation Testbenches
add_files -fileset sim_1 [list [file join $root_dir "tb" "unit" "mac_tree_tb.vhd"]]
set_property top mac_tree_tb [get_filesets sim_1]

puts "=========================================================="
puts "SUCCESS: Vivado project created successfully with all RTL sources."
puts "=========================================================="
