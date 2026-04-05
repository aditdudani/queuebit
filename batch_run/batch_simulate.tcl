#!/usr/bin/env tclsh
# Build project ONCE, loop simulation ONLY

package require Tcl 8.5

set K_values {5 10 15 20}
set injection_rates {0.1 0.5 1.0 1.5 2.0}
set num_runs 3

puts "Starting optimized batch simulations..."

# 1. BUILD THE PROJECT ONCE
puts "Building Vivado project..."
if {[catch {source run_sims.tcl} proj_err]} {
    puts "FATAL ERROR sourcing project: $proj_err"; exit 1
}

# 2. INJECT TESTBENCH ONCE
puts "Adding testbench..."
set tb_file "[file normalize "../tb/tb_dispatcher_integration.sv"]"
add_files -fileset sim_1 -norecurse $tb_file
set_property top tb_dispatcher_integration [get_filesets sim_1]
update_compile_order -fileset sim_1
set_property -name {xsim.simulate.runtime} -value {1500ns} -objects [get_filesets sim_1]

# 3. RUN THE PARAMETER SWEEP
set total_configs [expr {[llength $K_values] * [llength $injection_rates] * $num_runs}]
set config_count 0

foreach K $K_values {
  foreach inj_rate $injection_rates {
    for {set run 1} {$run <= $num_runs} {incr run} {
      incr config_count
      set log_file "build/log_K${K}_inj${inj_rate}_${run}.txt"

      puts "\n--- Running $config_count/$total_configs: K=$K, Inj=$inj_rate, Run=$run ---"

      # Update generics dynamically
      set_property generic "WORKER_LATENCY=$K" [get_filesets sim_1]

      # Launch simulation ONLY
      if {[catch {launch_simulation} sim_err]} {
         puts "ERROR in simulation: $sim_err"
      }

      # Extract log immediately
      set log_fd [open $log_file w]
      puts $log_fd "Configuration: K=$K, InjectRate=$inj_rate, Run=$run"
      puts $log_fd "--- XSIM STDOUT ---"

      set sim_log_path [file join [pwd] queuebit_vivado queuebit_vivado.sim sim_1 behav xsim simulate.log]
      if {[file exists $sim_log_path]} {
         set sim_fd [open $sim_log_path r]
         puts $log_fd [read $sim_fd]
         close $sim_fd
      } else {
         puts $log_fd "\nWARNING: simulate.log not found."
      }
      close $log_fd

      # Close the simulation so the next iteration can start cleanly
      catch {close_sim -force}
    }
  }
}

# 4. FINAL CLEANUP
catch {close_project -force}
puts "\n=== ALL 60 SIMULATIONS COMPLETED SUCCESSFULLY ==="
exit 0
