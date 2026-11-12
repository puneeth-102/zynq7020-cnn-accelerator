set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".."]]
set ws_dir     [file normalize [file join $root_dir "sdk_workspace"]]
set hdf_file   [file normalize [file join $root_dir "sdk_app" "zedboard_cnn_sys_wrapper.hdf"]]
set src_dir    [file normalize [file join $root_dir "sdk_app"]]

puts "=========================================================="
puts "SETTING SDK WORKSPACE: $ws_dir"
puts "=========================================================="
setws $ws_dir

puts "Creating Hardware Platform Specification from $hdf_file..."
createhw -name zedboard_cnn_hw -hwspec $hdf_file

puts "Creating Board Support Package (BSP)..."
createbsp -name zedboard_bsp -hwproject zedboard_cnn_hw -proc ps7_cortexa9_0 -os standalone

puts "Creating Application Project..."
createapp -name cnn_demo_app -hwproject zedboard_cnn_hw -bsp zedboard_bsp -proc ps7_cortexa9_0 -os standalone -lang C -template {Empty Application}

puts "Importing Source Files..."
importsources -name cnn_demo_app -path [file join $src_dir "main.c"]
importsources -name cnn_demo_app -path [file join $src_dir "test_data.h"]

puts "Building All SDK Projects..."
projects -build

puts "=========================================================="
puts "SDK BUILD COMPLETED SUCCESSFULLY"
puts "=========================================================="
