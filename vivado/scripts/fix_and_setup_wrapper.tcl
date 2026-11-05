set proj_file "C:/Users/HP PC/zedboard_cnn_verilog_prj/zedboard_cnn_verilog.xpr"
open_project $proj_file

# Add BD file
set bd_path "C:/Users/HP PC/zedboard_cnn_verilog_prj/zedboard_cnn_verilog.srcs/sources_1/bd/zedboard_cnn_sys/zedboard_cnn_sys.bd"
if {[file exists $bd_path]} {
    add_files -norecurse [list $bd_path]
    puts "SUCCESS: Added BD to project."
}

# Add wrapper
set wrapper_path "C:/Users/HP PC/zedboard_cnn_verilog_prj/zedboard_cnn_verilog.srcs/sources_1/bd/zedboard_cnn_sys/hdl/zedboard_cnn_sys_wrapper.v"
if {[file exists $wrapper_path]} {
    add_files -norecurse [list $wrapper_path]
    puts "SUCCESS: Added wrapper to project."
}

# Disable RTL-level timing.xdc (aclk port does not exist in top wrapper)
set xdc_files [get_files -of_objects [get_filesets constrs_1] -filter {NAME =~ *timing.xdc*}]
if {[llength $xdc_files] > 0} {
    set_property is_enabled false [get_files $xdc_files]
    puts "SUCCESS: Disabled standalone timing.xdc in system build."
}

# Set top to wrapper
set_property top zedboard_cnn_sys_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "Current top: [get_property top [current_fileset]]"

close_project
