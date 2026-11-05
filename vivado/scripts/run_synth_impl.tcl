# Master Implementation and Bitstream Generation Tcl script for ZedBoard CNN System
set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".." ".."]]
set proj_file  [file normalize [file join $root_dir "vivado" "zedboard_cnn_sys.xpr"]]
if {![file exists $proj_file]} {
    set proj_file "C:/Users/HP PC/zedboard_cnn_verilog_prj/zedboard_cnn_verilog.xpr"
}
set ip_repo    [file normalize [file join $root_dir "vivado" "ip_repo" "cnn_accelerator_v1_0"]]
set pynq_out   [file normalize [file join $root_dir "sw" "pynq_driver"]]
set doc_dir    [file normalize [file join $root_dir "doc"]]

puts "=========================================================="
puts "OPENING ZEDBOARD SYSTEM PROJECT"
puts "=========================================================="
open_project $proj_file

# Set IP Repository path and refresh
set_property ip_repo_paths [list $ip_repo] [current_project]
update_ip_catalog

# Ensure top is wrapper
set_property top zedboard_cnn_sys_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Check top and synthesis status
puts "Current Fileset Top: [get_property top [current_fileset]]"
set synth_status [get_property STATUS [get_runs synth_1]]
puts "synth_1 Status: $synth_status"

if {$synth_status != "synth_design Complete!"} {
    puts "Launching Top Synthesis (synth_1)..."
    reset_run synth_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    puts "synth_1 Completed: [get_property STATUS [get_runs synth_1]]"
}

# Reset and Launch Implementation & Bitstream
puts "=========================================================="
puts "Launching Implementation & Bitstream (impl_1)..."
puts "=========================================================="
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "=========================================================="
puts "impl_1 Final Status: $impl_status"
puts "=========================================================="

# Check if bitstream generated
set bit_file "C:/Users/HP PC/zedboard_cnn_verilog_prj/zedboard_cnn_verilog.runs/impl_1/zedboard_cnn_sys_wrapper.bit"

if {[file exists $bit_file]} {
    file copy -force $bit_file [file join $pynq_out "cnn_accelerator.bit"]
    puts "SUCCESS: Bitstream generated and exported to: [file join $pynq_out cnn_accelerator.bit]"

    # Open implemented design and generate detailed reports
    open_run impl_1
    report_utilization -file [file join $doc_dir "impl_utilization.rpt"]
    report_timing_summary -file [file join $doc_dir "impl_timing.rpt"]
    report_power -file [file join $doc_dir "impl_power.rpt"]
    puts "SUCCESS: Implementation reports exported to doc/ directory."
} else {
    puts "WARNING: Bitstream file not found at $bit_file"
}

close_project

