# ==============================================================================
# Script: program_board.tcl
# Description: 1-Click Hardware Bitstream Programmer for ZedBoard
# ==============================================================================

set SCRIPT_PATH [file normalize [info script]]
set SCRIPT_DIR  [file dirname $SCRIPT_PATH]
set REPO_ROOT   [file normalize [file join $SCRIPT_DIR ".." ".."]]
set BIT_FILE    [file normalize [file join $REPO_ROOT "sw" "sdk_app" "cnn_accelerator.bit"]]

if {![file exists $BIT_FILE]} {
    set BIT_FILE [file normalize [file join $REPO_ROOT "sw" "pynq_driver" "cnn_accelerator.bit"]]
}

if {![file exists $BIT_FILE]} {
    puts "ERROR: Bitstream file not found!"
    exit 1
}

puts "============================================================"
puts "Bitstream Found: $BIT_FILE"
puts "Connecting to ZedBoard Hardware Server..."
puts "============================================================"
open_hw
connect_hw_server -url localhost:3121

# Attempt to connect to ZedBoard JTAG target
if {[catch {open_hw_target} err]} {
    puts "\n============================================================"
    puts "ERROR: ZedBoard JTAG connection not detected!"
    puts "Please check the physical hardware setup:"
    puts "  1. 12V Power Adapter connected to J20 barrel jack (SW8 turned ON)."
    puts "  2. USB Cable connected firmly to ZedBoard J17 (PROG) and laptop."
    puts "  3. Boot Jumpers JP7 - JP11 all set to GND (0 / bottom position)."
    puts "============================================================\n"
    close_hw
    exit 1
}

set device [lindex [get_hw_devices xc7z020*] 0]
if {$device == ""} {
    puts "\n============================================================"
    puts "ERROR: No Zynq-7020 device found on the JTAG chain!"
    puts "============================================================\n"
    close_hw_target
    close_hw
    exit 1
}

puts "Target Device Detected: $device"
puts "Programming bitstream: $BIT_FILE ..."
set_property PROGRAM.FILE $BIT_FILE $device
program_hw_devices $device
refresh_hw_device $device

puts "\n============================================================"
puts "SUCCESS: ZedBoard Programmed Successfully!"
puts "The BLUE DONE LED (LD12) is now turned ON!"
puts "============================================================\n"
close_hw_target
disconnect_hw_server
close_hw
exit 0
