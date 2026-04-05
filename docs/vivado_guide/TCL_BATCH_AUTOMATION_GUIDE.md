# QueueBit Phase 4: TCL Batch Automation Guide
**Filtered extraction for automated simulation & metric extraction**

This guide contains exact TCL syntax and batch automation patterns from Xilinx Vivado documentation relevant to Phase 4 (6.6c–d).

---

## SECTION 1: TCL SCRIPTING FUNDAMENTALS

### 1.1 Launching Vivado in TCL/Batch Mode

**Source**: UG910 (Getting Started), Chapter 2, Section "Launching the Vivado Tools Using a Batch Tcl Script", page 8

**Interactive TCL Shell**:
```bash
vivado -mode tcl
```
Launches TCL command prompt. Use `start_gui` to switch to GUI mode.

**Batch Mode (Non-Interactive)**:
```bash
vivado -mode batch -source <your_script.tcl> -log <logfile.log>
```

**Windows Example**:
```cmd
cd D:\College\4-2\SoP2\Code\queuebit\Phase4
vivado -mode batch -source batch_simulate.tcl -log batch.log
```

**Important**: In batch mode, Vivado exits after script completes. Use file I/O to capture outputs.

---

## SECTION 2: PROJECT MANAGEMENT VIA TCL

### 2.1 Opening a Project

**Source**: UG894 (Using Tcl Scripting) — Referenced in UG893, Chapter 1, page 9

**Command**:
```tcl
open_project /path/to/dispatcher.xpr
```

**Example** (Windows):
```tcl
open_project "D:/College/4-2/SoP2/Code/queuebit/dispatcher.xpr"
```

**Verifying Success**:
```tcl
if {[catch {open_project dispatcher.xpr} err]} {
  puts "ERROR: Failed to open project: $err"
  exit 1
}
```

### 2.2 Sourcing an Exported Project Snapshot

**Source**: UG893, Chapter 1: "Working with Tcl", page 9; UG894, Chapter 1: "Getting Help", p.8

You can source the entire project configuration from the exported `.tcl` file:
```tcl
source run_sims.tcl
```

**Result**: Vivado loads:
- Design file paths (RTL, testbench, XDC) via `add_files` commands
- Project settings (synthesis, implementation, simulation options) via `set_property`
- Device configuration and top-level module specification
- **Does NOT run synthesis** — only recreates project state

**Important Notes** (from UG894):
- `source run_sims.tcl` is **idempotent if project does not exist**; if project is already open, second source may fail
- File paths in run_sims.tcl may be relative to export location; ensure working directory is consistent
- **Solution for batch loops**: Close project before sourcing again (see Section 2.3)

### 2.3 Project Lifecycle: Opening, Closing, and Cleanup

**Source**: UG894, Section 1.2 (Project Management Commands), p.6–7

**In batch loops, manage project state carefully**:

```tcl
# At start of each loop iteration:
if {[catch {source run_sims.tcl} proj_err]} {
  puts "ERROR: Failed to load project: $proj_err"
  exit 1
}

# ... run elaborate and launch_simulation ...

# At end of each loop iteration (CRITICAL for next iteration):
if {[catch {close_project -force} close_err]} {
  puts "WARNING: Failed to close project: $close_err"
}
```

**Key Commands** (from UG894):

| Command | Effect | When to Use |
|---------|--------|-------------|
| `close_project` | Closes current project (fails if one doesn't exist) | After work complete |
| `close_project -force` | Closes without prompting to save | In batch loops (recommended) |
| `close_design` | Unloads elaborated design (lightweight) | Between simulations if reusing project |
| `close_simulator` | Stops XSim process | After simulation launch |
| `reset_runs <run_name>` | Clears results from previous runs | Only if re-running synthesis/impl |

**For Phase 4 batch loop**: Use `close_project -force` after each simulation cycle to ensure clean state for next source.

---

## SECTION 3: ELABORATION & PARAMETRIC OVERRIDE

### 3.1 Elaborate Testbench with Parameter Override

**Source**: UG893, Chapter 2, Section "Vivado IDE Viewing Environment" → "Flow Navigator", page 16–17; UG894 Tcl Reference

**Basic Elaboration**:
```tcl
elaborate -top tb_dispatcher_integration
```

**With Parameter Override** (for K-sweep):
```tcl
elaborate -top tb_dispatcher_integration \
  -generics [list \
    "WORKER_LATENCY=5" \
    "INJECTION_RATE=1.0" \
  ]
```

**Alternative Syntax** (if above fails):
```tcl
set generics_flags "-generics {WORKER_LATENCY=10}"
set elaborationCmd "elaborate -top tb_dispatcher_integration $generics_flags"
eval $elaborationCmd
```

**Key Point**: The `-generics` flag substitutes parameter values at elaboration time without recompiling RTL.

---

## SECTION 4: LAUNCHING & CONTROLLING SIMULATION

### 4.2 Launch Behavioral Simulation (XSim)

**Source**: UG893, Chapter 2, Section "Vivado IDE Viewing Environment" → "Flow Navigator", page 16–17; UG900 (Logic Simulation), Chapter 2, "Preparing for Simulation", p.12–37

**Minimal Launch**:
```tcl
launch_simulation -scripts {
  run 1500 ns
  exit
}
```

**With Custom Simulation Script**:
```tcl
launch_simulation -scripts sim.tcl
```

**Suppress GUI** (batch-friendly):
```tcl
launch_simulation -mode behavioral -scripts {
  run 1500 ns
  exit
}
```

**Note**: In batch mode, GUI is already suppressed. `-mode behavioral` specifies simulation type (not actual GUI visibility).

### 4.3 Understanding Simulation Duration

**Source**: UG900 (Logic Simulation), Chapter 4 ("Simulating with Vivado Simulator"), subsection "Understanding Simulation Duration", p.48+

**Duration specification**:
```tcl
run 1500 ns        ;# 1500 nanoseconds (NOT 1500 cycles)
run 1500           ;# 1500 in design's timescale (usually 1ns, same as above)
run -all           ;# Run until $finish or $stop is encountered
```

**Critical Note**: `run 1500 ns` = 1500 nanoseconds of simulation time, NOT 1500 clock cycles. If your design uses 10 ns clock, this is only ~150 cycles. Adjust as needed for testbench duration.

**Proper termination**:
```tcl
# Inside sim.tcl script:
run 1500 ns    ;# Advance simulation
exit 0         ;# Exit with success code
# (exit code 0 = Vivado continues; exit 1 = Vivado stops)
```

**If simulation hangs** (does not respond to run/exit):
- Testbench must call `$finish` to explicitly stop
- OR Vivado TCL (not inside sim.tcl) can call `close_simulator -force`

---

## SECTION 5: LOGGING & OUTPUT CAPTURE

### 5.1 Capturing Simulation Output to File

**Source**: UG893, Chapter 2, Section "Vivado IDE Viewing Environment" → "Results Windows Area", page 20

**Method 1: Redirect XSim stdout**:
```tcl
launch_simulation -scripts {
  run 1500 ns
  exit
} > "log_K5_inj1.0_1.txt" 2>&1
```

**Method 2: TCL File Output** (within batch script):
```tcl
set logfile [open "log_K5_inj1.0_1.txt" w]

# Write simulation header
puts $logfile "Simulation Configuration:"
puts $logfile "  WORKER_LATENCY: 5"
puts $logfile "  INJECTION_RATE: 1.0"
puts $logfile "  Run: 1"
puts $logfile "---"

# Launch simulation and capture output
if {[catch {launch_simulation -scripts sim.tcl} sim_err]} {
  puts $logfile "ERROR: $sim_err"
}

close $logfile
```

**Method 3: Vivado Batch Log** (all messages):
```bash
vivado -mode batch -source batch_simulate.tcl -log batch.log
```

The `-log` file contains all Vivado messages. Parse for simulation-specific output.

---

## SECTION 6: NESTED LOOP PATTERN FOR PARAMETER SWEEP

### 6.1 K-Sweep, Injection Rate Sweep, Multiple Runs

**Source**: Standard TCL control structures (for loops)

**Complete Pattern** (for Phase4/batch_simulate.tcl):

```tcl
#!/usr/bin/env tclsh
# Phase 4 Batch Simulation Script
# Sweeps: K ∈ {5, 10, 15, 20}, Injection Rate ∈ {0.1, 0.5, 1.0, 1.5, 2.0}
# Runs per configuration: 3

# Load Vivado TCL shell
package require Tcl 8.5

# Define parameter space
set K_values {5 10 15 20}
set injection_rates {0.1 0.5 1.0 1.5 2.0}
set num_runs 3
set total_configs [expr {[llength $K_values] * [llength $injection_rates] * $num_runs}]
set config_count 0

puts "Starting Phase 4 batch simulations..."
puts "Total configurations: $total_configs"

# Outer loop: Worker Latency
foreach K $K_values {
  # Middle loop: Injection Rate
  foreach inj_rate $injection_rates {
    # Inner loop: Multiple Runs for statistics
    for {set run 1} {$run <= $num_runs} {incr run} {
      incr config_count
      set log_file "build/log_K${K}_inj${inj_rate}_${run}.txt"

      puts "\n[clock format [clock seconds]]: Starting config $config_count/$total_configs"
      puts "  K=$K, Injection=$inj_rate, Run=$run"
      puts "  Logging to: $log_file"

      # Open log file with line buffering (important for batch mode)
      set log_fd [open $log_file w]
      fconfigure $log_fd -buffering line
      puts $log_fd "Configuration: K=$K, InjectRate=$inj_rate, Run=$run"
      puts $log_fd "Timestamp: [clock format [clock seconds]]"
      puts $log_fd "---"

      # Source project (imported from GUI)
      if {[catch {source run_sims.tcl} proj_err]} {
        puts $log_fd "ERROR sourcing project: $proj_err"
        close $log_fd
        continue
      }

      # Elaborate testbench with parameter override
      if {[catch {
        elaborate -top tb_dispatcher_integration \
          -generics "WORKER_LATENCY=$K" \
          -j 4
      } elab_err]} {
        puts $log_fd "ERROR elaborating: $elab_err"
        close $log_fd
        continue
      }

      # Create simulation script
      set sim_tcl "build/sim_temp_${K}_${inj_rate}_${run}.tcl"
      set sim_fd [open $sim_tcl w]
      puts $sim_fd "run 1500 ns"
      puts $sim_fd "exit"
      close $sim_fd

      # Launch simulation (capture output)
      puts $log_fd "Launching simulation..."
      if {[catch {
        launch_simulation \
          -mode behavioral \
          -scripts $sim_tcl
      } sim_err]} {
        puts $log_fd "ERROR in simulation: $sim_err"
      }

      puts $log_fd "Simulation complete at [clock format [clock seconds]]"
      close $log_fd

      # Clean up temp TCL file
      file delete -force $sim_tcl

      # Close project before next iteration (CRITICAL for batch loops)
      if {[catch {close_project -force} close_err]} {
        puts "WARNING: Failed to close project after run: $close_err"
      }
    }
  }
}

puts "\n[clock format [clock seconds]]: All simulations completed!"
puts "Results saved in build/log_*.txt"
exit 0
```

**Key Features**:
- **Nested loops**: 4 × 5 × 3 = 60 configurations
- **Logging**: Each run logs to unique filename
- **Error handling**: `catch` blocks prevent crashes on elaboration/simulation errors
- **Progress tracking**: Prints status to console and log
- **Cleanup**: Removes temporary TCL scripts

---

## SECTION 7: DESIGN EXPORT & RUN STATE MANAGEMENT

### 7.1 Writing Project as TCL

**Source**: UG893, Chapter 1: "Working with Tcl", page 9

**In Vivado GUI** (one-time setup):
1. **File → Project → Write Project Tcl**
2. Save as `Phase4/run_sims.tcl`

**What TCL File Contains**:
- Project creation commands (`create_project`, `add_files`, etc.)
- Synthesis settings
- Elaboration defaults
- Device configuration

**Usage in Batch Script**:
```tcl
source run_sims.tcl        ;# Recreates project state, no GUI needed
```

### 7.2 Resetting Design Between Runs

**Important for Batch Loop**:
```tcl
# After one simulation completes, before next one:
close_simulator -force     ;# Shut down XSim
close_design -force        ;# Unload RTL design
reset_runs synth_1         ;# Clear synthesis results (for clean re-run)
```

**Alternative** (lighter cleanup):
```tcl
# Just reset elaboration, keep synthesis
reset_runs impl_1
```

---

## SECTION 8: ERROR HANDLING & DEBUGGING

### 8.1 Robust TCL Error Handling

**Source**: UG894, Chapter 1: "Error Handling", p.61

**Catch Command Pattern** (standard Tcl):
```tcl
if {[catch {
  elaborate -top tb_dispatcher_integration \
    -generics "WORKER_LATENCY=$K"
} error_msg]} {
  puts "ERROR: Elaboration failed"
  puts "Details: $error_msg"

  # Log to file instead of crashing
  puts $log_fd "ELABORATION ERROR: $error_msg"
}
```

**Understanding Error Messages** (from UG894):

- **Vivado internal errors**: Format `ERROR: [Common X-XXX] description`
  - Example: `ERROR: [Common 17-226] Could not open design file`
  - Can be parsed with regex: `if {[regexp {\[Common (\d+)-(\d+)\]} $error_msg -> code num]} { ... }`

- **TCL errors**: Format `invalid command name "cmd"` or `wrong number of arguments`
  - Indicates syntax error in TCL script itself
  - Check script for typos, missing braces, or unmatched quotes

- **Command errors**: Format `ERROR: Command 'elaborate' not found in current context`
  - Indicates design not open or wrong mode
  - Always ensure `source run_sims.tcl` succeeded before calling elaborate

**Return from error gracefully**:
```tcl
if {[catch { ... } error_msg]} {
  # Don't call exit 1 in loop (kills entire batch)
  # Instead: log error and continue to next iteration
  puts $log_fd "ERROR: $error_msg"
  # Optionally close project for next iteration
  catch {close_project -force}
  continue  ;# Go to next configuration
}
```

### 8.2 Verifying Command Success

**Source**: UG894, Section 8.2, p.34

**Check if elaboration actually completed**:
```tcl
if {[catch {get_cells} cell_list]} {
  error "Design not elaborated; cannot continue"
}
```

**Verify property exists before querying**:
```tcl
set fmax [get_property TRANSPORT_DELAY [get_cells]]
# If command fails, $fmax is unchanged; check error via catch
```

### 8.3 Debugging TCL Scripts

**Print variables for inspection** (UG894, Section 8.3, p.35):
```tcl
puts "DEBUG: K=$K, inj_rate=$inj_rate, run=$run"
puts "DEBUG: Generics string: WORKER_LATENCY=$K"
puts "DEBUG: TCL variables available: [info locals]"
```

**Print full error stack trace**:
```tcl
if {[catch { ... } error_msg]} {
  puts "ERROR: $error_msg"
  puts "STACK: [info errorinfo]"
}
```

**Enable global command tracing** (verbose; use sparingly):
```tcl
set tcl_trace 1  ;# Prints every TCL command before execution
# ... commands to debug ...
set tcl_trace 0
```

### 8.4 Log File Best Practices

**Source**: UG894, File I/O patterns, p.35–36

**Line-buffered I/O** (flush output immediately):
```tcl
set log_fd [open "log.txt" w]
fconfigure $log_fd -buffering line  ;# Flush after each puts $log_fd
puts $log_fd "Message 1"           ;# Appears in file immediately
# ... (do work) ...
puts $log_fd "Message 2"           ;# Appears in file immediately
close $log_fd
```

**Append mode** (for accumulating results across runs):
```tcl
set log_fd [open "accumulated.txt" a+]  ;# 'a' = append
puts $log_fd "Result from run: [clock format [clock seconds]]"
close $log_fd
```

**Always close files** (prevents data loss in batch mode):
```tcl
close $log_fd     ;# Or: close $log_fd -force if stuck
```

---

## SECTION 9: VIVADO TCL COMMAND REFERENCE (Complete for Phase 4)

**Source**: UG894 (Using Tcl Scripting), Chapter 1 (compiled from multiple sections including Elaboration, Simulation, and Project Management)

### 9.1 Project Management Commands

**Source**: UG894 (Using Tcl Scripting), Chapter 1, Section "Loading and Running Tcl Scripts", p.17–22

| Command | Syntax | Purpose | Phase 4 Example |
|---------|--------|---------|-----------------|
| `open_project` | `open_project <path.xpr>` | Load Vivado project file | `open_project dispatcher.xpr` |
| `close_project` | `close_project [-force]` | Close current project (ask to save unless -force) | `close_project -force` |
| `create_project` | `create_project <name> <dir> -part <device>` | Create new project (called by run_sims.tcl) | (used in exported TCL) |
| `source` | `source <file.tcl>` | Execute TCL script and load its output | `source run_sims.tcl` |
| `save_project` | `save_project` | Save current project | Not needed in batch |

### 9.2 Design Elaboration Commands

**Source**: UG894 (Using Tcl Scripting), Chapter 1, Section "Loading and Running Tcl Scripts", p.17–22

| Command | Syntax | Purpose | Phase 4 Example |
|---------|--------|---------|-----------------|
| `elaborate` | `elaborate -top <module> [-generics <list>] [-j <threads>]` | Elaborate RTL design at runtime | `elaborate -top tb_dispatcher_integration -generics "WORKER_LATENCY=10" -j 4` |
| `-top` | `-top <module_name>` | Specify top-level module for elaboration | `-top tb_dispatcher_integration` |
| `-generics` | `-generics "<PARAM>=<VALUE>"` | Override parameter at elaboration (no re-compile) | `-generics "WORKER_LATENCY=5"` |
| `-j` | `-j <num_threads>` | Parallel elaboration threads (optional, speeds up) | `-j 4` for 4 threads |
| `close_design` | `close_design [-force]` | Unload elaborated design (lightweight) | `close_design -force` |

**Notes on elaboration**:
- `-generics` flag accepts multiple parameters: `"PARAM1=VAL1 PARAM2=VAL2"` or list format
- Alternative syntax: `set gen "WORKER_LATENCY=$K"; elaborate -top tb ... -generics $gen`
- Design must be open (`source run_sims.tcl` or explicit `open_project`) before elaborating

### 9.3 Simulation Launch Commands

**Source**: UG894 (Using Tcl Scripting), Chapter 1, Section "Loading and Running Tcl Scripts", p.17–22

| Command | Syntax | Purpose | Phase 4 Example |
|---------|--------|---------|-----------------|
| `launch_simulation` | `launch_simulation [-mode <mode>] [-scripts <file.tcl>]` | Start behavioral or post-synth simulation | `launch_simulation -mode behavioral -scripts sim.tcl` |
| `-mode` | `-mode behavioral` (or post-synthesis, post-implementation) | Simulation type (Phase 4: behavioral only) | `-mode behavioral` |
| `-scripts` | `-scripts <file.tcl>` | TCL script to run inside simulator (contains `run` commands) | `-scripts build/sim_temp.tcl` |
| `-gui` | `-gui` (default) or omit for batch | Show simulation GUI window (don't use in batch mode) | N/A (omitted in batch) |
| `close_simulator` | `close_simulator [-force]` | Stop XSim and close simulation window | `close_simulator -force` |

**Notes on launch_simulation**:
- Must have elaborated design before launching
- `-scripts` file should contain `run <duration>` and `exit` commands
- XSim blocks until simulation completes (no background execution)
- `exit 0` in script = success; `exit 1` in script = error code

### 9.4 Simulation Control Commands (inside .tcl script)

**Source**: UG894 (Using Tcl Scripting), Chapter 1, Section "Loading and Running Tcl Scripts", p.17–22

**These commands go inside the `-scripts` file (e.g., sim.tcl)**, not in batch_simulate.tcl directly:

| Command | Syntax | Purpose | Example |
|---------|--------|---------|---------|
| `run` | `run <duration>` | Advance simulation time | `run 1500 ns` |
| `exit` | `exit [<code>]` | Stop simulation (code: 0 success, 1 error) | `exit 0` |
| `quit` | `quit [<code>]` | Alias for exit | `quit` |
| `time` | (not applicable in XSim) | — | — |

**Duration units** (UG900 note):
- `run 1500 ns` = 1500 nanoseconds simulation time
- `run 1500` = 1500 in design's timescale (usually 1ns, same as above)
- `run -all` = run until `$finish` is called in testbench

### 9.5 Design Query Commands

**Source**: UG894 (Using Tcl Scripting), Chapter 1, Section "Accessing Design Objects", p.35–51

| Command | Syntax | Purpose | Example |
|---------|--------|---------|---------|
| `get_cells` | `get_cells [<filter>]` | List design cells/hierarchies | `set cells [get_cells]` |
| `get_nets` | `get_nets [<filter>]` | List nets in design | `get_nets dispatcher_fsm/*` |
| `get_ports` | `get_ports [<filter>]` | List ports (I/O) | `get_ports [get_ports -filter {NAME != clk}]` |
| `get_pins` | `get_pins [<filter>]` | List pins (internal) | `get_pins Module/Signal` |
| `get_property` | `get_property <property> <object>` | Query object properties | `get_property UTIL.LUT [get_runs synth_1]` |
| `set_property` | `set_property <property> <value> <object>` | Set properties (mostly used in GUI) | `set_property IOSTANDARD LVCMOS33 [get_ports]` |

### 9.6 Run Management Commands

**Source**: UG894 (Using Tcl Scripting), Chapter 1, Section "Compilation and Reporting Example Scripts", p.10–34

| Command | Syntax | Purpose | Phase 4 Use |
|---------|--------|---------|-------------|
| `reset_runs` | `reset_runs <run_name>` | Clear results from previous synthesis/implementation | `reset_runs synth_1` (not needed Phase 4) |
| `wait_on_run` | `wait_on_run <run_name>` | Block until run completes (for async runs) | N/A (Phase 4 uses synchronous flows) |

### 9.7 Report Generation Commands

| Command | Syntax | Purpose | Example (Post-Synthesis) |
|---------|--------|---------|---------|
| `report_timing` | `report_timing [-nworst <n>] [-file <path>]` | Generate timing report | `report_timing -nworst 10 -file timing.txt` |
| `report_utilization` | `report_utilization [-file <path>]` | Generate resource utilization report | `report_utilization -file util.txt` |
| `report_power` | `report_power [-file <path>]` | Power estimation report | `report_power -file power.txt` |
| `report_design_analysis` | `report_design_analysis [-file <path>]` | Detailed design summary | `report_design_analysis -file design.txt` |

**Note**: Phase 4 doesn't require report commands in batch script (run once after synthesis via GUI).

### 9.8 File and Variable Commands

| Command | Syntax | Purpose | Example |
|---------|--------|---------|---------|
| `open` | `open <filename> <mode>` | Open file for reading/writing | `set fd [open "log.txt" w]` |
| `close` | `close <filehandle> [-force]` | Close file | `close $fd` |
| `puts` | `puts [<filehandle>] <string>` | Write to file or stdout | `puts $fd "message"` or `puts "message"` |
| `gets` | `gets <filehandle> [<varname>]` | Read line from file | `gets $fd line` |
| `read` | `read <filehandle> [<numchars>]` | Read entire file or N chars | `set content [read $fd]` |
| `set` | `set <varname> [<value>]` | Assign variable | `set K 10` |
| `expr` | `expr { ... }` | Evaluate expression | `set total [expr {$count + 1}]` |

### 9.9 Control Flow Commands

| Command | Syntax | Purpose | Phase 4 Example |
|---------|--------|---------|-----------------|
| `foreach` | `foreach <var> <list> { ... }` | Loop over list items | `foreach K {5 10 15 20} { ... }` |
| `for` | `for {init} {condition} {increment} { ... }` | C-style loop | `for {set i 1} {$i <= 3} {incr i} { ... }` |
| `if` | `if {<condition>} { ... } else { ... }` | Conditional | `if {[catch { ... } err]} { ... }` |
| `catch` | `catch {<command>} [<varname>]` | Trap errors (critical for batch) | `catch {elaborate ...} elab_err` |
| `incr` | `incr <varname> [<increment>]` | Increment variable | `incr config_count` |
| `continue` | `continue` | Skip to next loop iteration | `continue` |
| `break` | `break` | Exit loop | (not used in Phase 4) |

### 9.10 String and Formatting Commands

| Command | Syntax | Purpose | Example |
|---------|--------|---------|---------|
| `format` | `format <format_string> <args>` | String formatting (like C printf) | `format "K=%d" $K` |
| `string` | `string <subcommand> <string>` | String operations | `string map {, ""} "1,000"` |
| `clock` | `clock format [clock seconds]` | Current timestamp | `puts "Time: [clock format [clock seconds]]"` |
| `llength` | `llength <list>` | List length | `llength {5 10 15 20}` = 4 |
| `lindex` | `lindex <list> <index>` | Get list element | `lindex {a b c} 1` = b |

---

### 9.11 FConfigure (File Configuration) — Important for Batch

**Source**: Tcl standard library; critical for batch file I/O

```tcl
# Line-buffered output (flush immediately after each puts)
fconfigure $fd -buffering line

# Full buffering (flush only on close or explicit flush)
fconfigure $fd -buffering full

# No buffering (instant write)
fconfigure $fd -buffering none

# Explicit flush (force write to disk)
flush $fd
```

**Phase 4 recommendation**: Use `fconfigure $log_fd -buffering line` when opening log files to ensure output appears immediately (critical in case of crash).

---

## SECTION 10: BATCH SIMULATION WORKFLOW CHECKLIST

**For overall Phase 4 workflow context and GUI setup**, start with [`VIVADO_PHASE4_GUIDE.md`](./VIVADO_PHASE4_GUIDE.md) (Sections 1–4: Project Creation, Constraints, Synthesis, Checkpoints).

**Before Running Batch Script**:

- [ ] **Vivado project created and synthesized** (GUI setup complete)
- [ ] **XDC constraints file** added and attached to synthesis
- [ ] **Testbench parameterized** with WORKER_LATENCY in module declaration
- [ ] **run_sims.tcl exported** from GUI (File → Write Project Tcl)
- [ ] **batch_simulate.tcl created** with nested loops and logging
- [ ] **build/ directory exists** (for output logs and CSV files)
- [ ] **Phase4/ directory exists** (containing batch scripts)

**Running Batch**:
```bash
cd d:\College\4-2\SoP2\Code\queuebit\Phase4
vivado -mode batch -source batch_simulate.tcl -log batch.log
```

**Expected Output**:
- `batch.log` — Vivado execution log
- `build/log_K5_inj0.1_1.txt` through `build/log_K20_inj2.0_3.txt` (60 files total)
- Console: Progress message for each configuration

---

**Document References**:
- **UG910**: Vivado Design Suite Getting Started (v2025.1), Chapter 2
- **UG893**: Vivado Design Suite User Guide: Using the Vivado IDE (v2025.1), Chapter 1–2
- **UG894**: Vivado Design Suite User Guide: Using Tcl Scripting (Full reference; key sections on elaboration, simulation control)
- **UG900**: Vivado Design Suite User Guide: Logic Simulation (Simulation-specific TCL)

**Last Updated**: 2026-04-05 | **Phase 4 Stage**: Batch Automation (6.6c–d)
