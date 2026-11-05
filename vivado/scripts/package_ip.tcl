# Tcl script to package cnn_accelerator_top as a reusable Vivado IP Core
# Target Board: ZedBoard (xc7z020clg484-1)
# Language: Verilog

set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".." ".."]]
set ip_dir     [file normalize [file join $root_dir "vivado" "ip_repo" "cnn_accelerator_v1_0"]]
set proj_file  "C:/Users/HP PC/zedboard_cnn_verilog_prj/zedboard_cnn_verilog.xpr"

puts "=========================================================="
puts "PACKAGING CNN ACCELERATOR AS VIVADO IP CORE"
puts "IP Output Directory: $ip_dir"
puts "=========================================================="

open_project $proj_file

# Package the current project as an IP
ipx::package_project -root_dir $ip_dir -vendor usv_vision -library user -taxonomy /CNN_Acceleration -force

set core [ipx::current_core]

set_property name cnn_accelerator_top $core
set_property display_name "Zynq-7020 USV CNN Accelerator (Sensors 2026)" $core
set_property description "Streaming CNN Accelerator with Line Buffers, 9-MAC Tree (36 DSPs), Accumulator, ReLU & MaxPool" $core
set_property version 1.0 $core

# Associate Clock with AXI-Lite and AXI-Stream Interfaces
ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 $core
ipx::infer_bus_interfaces xilinx.com:interface:axis_rtl:1.0 $core

# Save IP definition
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::save_core $core

puts "=========================================================="
puts "SUCCESS: IP cnn_accelerator_top packaged at $ip_dir"
puts "=========================================================="

close_project
