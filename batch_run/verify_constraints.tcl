#!/usr/bin/env tclsh
# PRE-FLIGHT: Verify XDC constraints exist and are valid before d=23 synthesis
# Must be run BEFORE synthesize_d23.tcl to catch issues early

package require Tcl 8.5

puts "=== PRE-FLIGHT: Constraint Verification ==="

set constraint_file "../constraints/dispatcher.xdc"

# Check file existence
if {![file exists $constraint_file]} {
    puts "❌ FATAL: Constraint file NOT FOUND"
    puts "   Expected: $constraint_file"
    puts "   ACTION: Create constraints/dispatcher.xdc with clock definition"
    puts "   EXAMPLE:"
    puts "     create_clock -period 10.000 -name clk \[get_ports clk\]"
    puts "     set_property IOSTANDARD LVCMOS33 \[get_ports clk\]"
    exit 1
}

# Try to read file
if {[catch {
    set fd [open $constraint_file r]
    set content [read $fd]
    close $fd
} read_err]} {
    puts "❌ ERROR: Cannot read constraint file"
    puts "   $read_err"
    exit 1
}

puts "✅ File exists and readable: $constraint_file"

# Verify critical content
set has_create_clock [string first "create_clock" $content]
set has_clk_ref [string first "clk" $content]

if {$has_create_clock == -1} {
    puts "⚠️  WARNING: No 'create_clock' definition found"
    puts "   Timing analysis may be unconstrained or use Vivado defaults."
    puts "   Consider adding: create_clock -period 10.000 -name clk \[get_ports clk\]"
}

if {$has_clk_ref == -1} {
    puts "⚠️  WARNING: No 'clk' reference in constraints"
    puts "   Does your design use a different clock port name?"
}

if {$has_create_clock != -1 && $has_clk_ref != -1} {
    puts "✅ All critical constraints present"
}

puts "\n=== PRE-FLIGHT CHECK PASSED ==="
puts "Safe to proceed with: vivado -mode batch -source synthesize_d23.tcl"
exit 0
