#!/usr/bin/env tclsh
# Synthesize d=23 dispatcher on XC7Z020 (ZedBoard)
# Includes constraint verification, synthesis & implementation, and power/timing analysis

package require Tcl 8.5

puts "=== d=23 Dispatcher Synthesis for XC7Z020 ==="

# PRE-FLIGHT: Verify constraints exist and are valid
puts "\n[1/4] Verifying constraints..."
set constraint_file "[file normalize ../constraints/dispatcher.xdc]"

if {![file exists $constraint_file]} {
    puts "❌ FATAL: Constraint file not found: $constraint_file"
    puts "ACTION: Ensure constraints/dispatcher.xdc exists with clock definition."
    exit 1
}

# Read and validate constraint content
if {[catch {
    set fd [open $constraint_file r]
    set constraint_content [read $fd]
    close $fd
} read_err]} {
    puts "❌ FATAL: Cannot read constraint file: $read_err"
    exit 1
}

if {[string first "create_clock" $constraint_content] == -1} {
    puts "⚠️  WARNING: No 'create_clock' found in XDC"
    puts "   Timing analysis may be unconstrained."
}

puts "✅ Constraint file verified: $constraint_file"

# Create new Vivado project for d=23 synthesis
puts "\n[2/4] Creating Vivado project..."
set proj_dir "/tmp/queuebit_d23_synth"
set proj_name "queuebit_d23_synth"

if {[catch {
    create_project -force $proj_name $proj_dir -part xc7z020clg484-1
} create_err]} {
    puts "❌ ERROR creating project: $create_err"
    exit 1
}

# Add RTL sources for d=23
puts "Adding RTL sources..."
add_files -norecurse [file normalize ../../rtl/dispatcher_pkg.sv]
add_files -norecurse [file normalize ../../rtl/syndrome_fifo.sv]
add_files -norecurse [file normalize ../../rtl/tracking_matrix.sv]
add_files -norecurse [file normalize ../../rtl/dispatcher_fsm.sv]
add_files -norecurse [file normalize ../../rtl/dispatcher_top_d23.sv]

# Add constraints
puts "Adding constraints..."
add_files -fileset constrs_1 -norecurse $constraint_file

# Set top module
set_property top dispatcher_top_d23 [current_fileset]

# run synthesis
puts "\n[3/4] Running synthesis and implementation..."
if {[catch {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
} synth_err]} {
    puts "❌ ERROR in synthesis: $synth_err"
    close_project
    exit 1
}

# Run implementation
if {[catch {
    launch_runs impl_1 -jobs 4
    wait_on_run impl_1
} impl_err]} {
    puts "❌ ERROR in implementation: $impl_err"
    close_project
    exit 1
}

# Generate reports
puts "\n[4/4] Generating reports..."
report_timing_summary -file [file normalize build_d23/timing_report.txt]
report_utilization -file [file normalize build_d23/utilization_report.txt]
report_power -file [file normalize build_d23/power_report.txt]

puts "✅ Power report generated (post-implementation)"

# Optional: design hierarchy for verification
report_design -file [file normalize build_d23/design_report.txt]

# Close project
close_project -force

puts "\n=== d=23 SYNTHESIS COMPLETE ==="
puts "✅ Synthesis successful"
puts "Reports saved to build_d23/"
exit 0
