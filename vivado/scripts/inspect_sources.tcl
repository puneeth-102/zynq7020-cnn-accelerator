set proj_file "C:/Users/HP PC/zedboard_cnn_verilog_prj/zedboard_cnn_verilog.xpr"
open_project $proj_file

puts "=== FILES IN SOURCES_1 ==="
foreach f [get_files -of_objects [get_filesets sources_1]] {
    puts "File: $f"
}

set bd_file [get_files *zedboard_cnn_sys.bd]
puts "BD file: $bd_file"

set wrapper_file [get_files *zedboard_cnn_sys_wrapper.v]
puts "Wrapper file: $wrapper_file"

close_project
