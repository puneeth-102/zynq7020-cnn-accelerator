# Master Build Script: Update IP, Synthesize, Implement, Write Bitstream, and Export HDF
# Target Board: Avnet ZedBoard (xc7z020clg484-1)

set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".." ".."]]
set ip_dir     [file normalize [file join $root_dir "vivado" "ip_repo" "cnn_accelerator_v1_0"]]
set proj_file  "C:/Users/HP PC/zedboard_cnn_verilog_prj/zedboard_cnn_verilog.xpr"
set sdk_dir    [file normalize [file join $root_dir "sw" "sdk_app"]]

file mkdir $sdk_dir

puts "=========================================================="
puts "OPENING ZEDBOARD SYSTEM PROJECT"
puts "Project: $proj_file"
puts "=========================================================="

open_project $proj_file

# Update IP catalog with new packaged IP
set_property ip_repo_paths [list $ip_dir] [current_project]
update_ip_catalog -rebuild

# Check and upgrade IP in Block Design if needed
open_bd_design [get_files *zedboard_cnn_sys.bd]
catch {
    report_ip_status -name ip_status
    upgrade_ip [get_ips *cnn_accel*]
}

# Validate and Save BD
validate_bd_design
save_bd_design

# Generate output products for BD
puts "=========================================================="
puts "GENERATING BLOCK DESIGN PRODUCTS"
puts "=========================================================="
generate_target all [get_files *zedboard_cnn_sys.bd]

# Reset previous runs to guarantee clean build
puts "=========================================================="
puts "LAUNCHING IMPLEMENTATION & BITSTREAM GENERATION"
puts "=========================================================="
reset_run synth_1
reset_run impl_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Check implementation status
set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation Status: $impl_status"

if {[string match "*Complete*" $impl_status]} {
    puts "=========================================================="
    puts "SUCCESS: Bitstream generated successfully!"
    puts "=========================================================="
    
    # Locate generated bitstream
    set src_bit [file join [get_property DIRECTORY [get_runs impl_1]] "zedboard_cnn_sys_wrapper.bit"]
    if {[file exists $src_bit]} {
        set dst_bit [file join $root_dir "sw" "pynq_driver" "cnn_accelerator.bit"]
        file copy -force $src_bit $dst_bit
        file copy -force $src_bit [file join $sdk_dir "cnn_accelerator.bit"]
        puts "Copied bitstream to: $dst_bit and $sdk_dir"
    }

    # Export Hardware Definition (.hdf) for Xilinx SDK
    set hdf_file [file join $sdk_dir "zedboard_cnn_sys_wrapper.hdf"]
    file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] "zedboard_cnn_sys_wrapper.sysdef"] $hdf_file
    puts "Exported Hardware Specification (.hdf) to: $hdf_file"
} else {
    puts "ERROR: Implementation did not complete successfully. Check logs."
}

close_project
