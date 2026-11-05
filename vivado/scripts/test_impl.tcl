set proj_file "C:/Users/HP PC/zedboard_cnn_verilog_prj/zedboard_cnn_verilog.xpr"
open_project $proj_file

puts "=== PROJECT CURRENT SETTINGS ==="
puts "Top: [get_property top [current_fileset]]"
puts "Synth top: [get_property top [get_runs synth_1]]"
puts "Synth status: [get_property status [get_runs synth_1]]"
puts "Impl status: [get_property status [get_runs impl_1]]"

# Ensure top is set properly
set_property top zedboard_cnn_sys_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Check if impl_1 parent is synth_1
puts "Impl parent: [get_property parent_run [get_runs impl_1]]"

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "Impl 1 final status: [get_property status [get_runs impl_1]]"

close_project
