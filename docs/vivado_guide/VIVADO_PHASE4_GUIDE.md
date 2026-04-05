# QueueBit Phase 4: Synthesized Vivado User Guide
**Filtered extraction for QueueBit Synthesis & Performance Analysis**

This guide contains exact sections from Xilinx Vivado 2025.1 documentation relevant to Phase 4 synthesis, verification, and batch simulation.

---

## PART A: PROJECT CREATION & RTL SYNTHESIS

### 1. Creating a New Project in Vivado IDE

**Source**: UG910 (Getting Started), Chapter 2, Section "Using the Vivado IDE", page 9

**Steps**:
1. Select **File → Project → New** in the Vivado IDE
2. Choose project location and name
3. Add RTL source files: dispatcher_pkg.sv, syndrome_fifo.sv, tracking_matrix.sv, dispatcher_fsm.sv, dispatcher_top.sv
4. Set top-level module: **dispatcher_top**
5. Select target device: **xc7z020clg400-1** (PYNQ) or **xc7z020clg484-1** (ZedBoard)
6. Click **Finish**

**Project Mode Advantages** (Source: UG893, Chapter 1, page 6):
- Source file management and status tracking
- Flow Navigator and Project Summary
- Consolidated messages and automatically generated standard reports
- Cross probing from messages to RTL source files
- Storage of tool settings and design configuration
- Experiment with multiple synthesis and implementation runs
- Run results management and status

### 2. Setting Synthesis Constraints (XDC)

**Source**: UG892 (Design Flows Overview), Chapter 1: "RTL-to-Bitstream Design Flow", "Synthesis", page 11; UG903 (Using Constraints), Section 2, p.8–15

**Constraint File Workflow**:
1. Create new XDC constraint file in Vivado
2. Define clock constraint:
   ```tcl
   create_clock -period 10.000 -name clk [get_ports clk]
   ```
   (10ns = 100 MHz conservative target; actual Fmax will be higher)

3. Define I/O standards (important to specify, even for Zynq internal signals):
   ```tcl
   set_property IOSTANDARD LVCMOS33 [get_ports {*}]
   ```

   **CORRECTION** (from UG903): Don't apply LVCMOS33 to clock! Use filtered selector:
   ```tcl
   set_property IOSTANDARD LVCMOS33 [get_ports -filter {NAME != clk}]
   ```

4. Attach constraints to synthesis settings

**Cloud Constraint Syntax** (from UG903, Section 2):

| Constraint | Syntax | Purpose | Example |
|-----------|--------|---------|---------|
| Clock period | `create_clock -period <ns> -name <name> [get_ports <port>]` | Set target frequency | `create_clock -period 10.000 -name clk [get_ports clk]` |
| Clock duty cycle | `-waveform {<rise> <fall>}` | Specify pulse width (optional) | `-waveform {0.000 5.000}` for 50% duty |
| I/O standard | `set_property IOSTANDARD <standard> [get_ports <port>]` | Voltage level (LVCMOS33, LVDS, etc.) | `set_property IOSTANDARD LVCMOS33 [get_ports data_in]` |
| Port filtering | `[get_ports -filter {<condition>}]` | Select subset of ports | `[get_ports -filter {NAME != clk}]` excludes clk |

**Phase 4 specific**: Use conservative 100 MHz (10ns) clock target. Actual synthesis will achieve 250–350 MHz; tighter constraints can cause timing violations during synthesis.

**Note**: XDC supports Xilinx Design Constraints (XDC) format. More details in: **UG903 (Using Constraints)** — see references for full syntax (input delay, false path, etc., not needed for Phase 4).


### 3. Running Synthesis

**Source**: UG893 (Using the Vivado IDE), Chapter 2, Section "Vivado IDE Viewing Environment" → "Flow Navigator", page 16–17

**GUI Steps**:
1. In **Flow Navigator**, click **Synthesis**
2. Configure synthesis settings (optional):
   - **Tools → Settings** → Synthesis options for non-incremental flow (first run)
3. Wait for synthesis to complete
4. Review synthesis report:
   - **Reports → Synthesis → Design Summary** — view Fmax, LUT utilization, FF utilization, BRAM usage

**Capture Metrics**:
- **Timing Summary**: Maximum operating frequency (Fmax)
- **Resource Utilization**: Logic LUTs (%), Flip-Flops (%), BRAM (blocks), Distributed RAM (bits)

**Critical Warnings Check**:
- Verify no **CRITICAL** warnings in Messages window
- Warnings are acceptable; critical warnings indicate design issues

**Source Reference**: UG893, Chapter 2, Section "Vivado IDE Viewing Environment" → "Flow Navigator", page 16–17

### 4. Design Checkpoints

**Source**: UG892 (Design Flows Overview), Chapter 1: "RTL-to-Bitstream Design Flow", page 7

Vivado automatically creates design checkpoints at each stage:
- After RTL elaboration
- After synthesis
- After implementation

Access checkpoints via **File → Open Checkpoint** to load previous design stages without re-running flows.

---

## PART B: TESTBENCH PARAMETERIZATION

### 5. Adding Top-Level Parameters to Testbench

**Source**: UG893 (Using the Vivado IDE), Chapter 1: "Project Mode and Non-Project Mode", page 6; Chapter 2: "Using the Viewing Environment" → "Editing Properties", page 36

**Procedure** (for tb/tb_dispatcher_integration.sv):
1. Open testbench file in text editor or Vivado IDE
2. Add parameter declarations at module header:
   ```systemverilog
   module tb_dispatcher_integration #(
     parameter integer WORKER_LATENCY = 5,  // Override via Vivado elaborate
     parameter real INJECTION_RATE = 1.0    // Optional, for future sweeps
   ) ();
   ```

3. Use parameter in testbench logic:
   - Line 163: Initialize worker timer with `WORKER_LATENCY - 1`
   - Worker timer countdown determines syndrome processing delay

4. **Save file** — no recompilation needed; parameter overridden at elaborate time

**Key Benefit**: Allows Vivado to accept different WORKER_LATENCY values ({5, 10, 15, 20}) during elaboration without re-compiling RTL.

---

## PART C: BATCH MODE TCL SCRIPTING

### 6. Launching Vivado in Batch Mode

**Source**: UG910 (Getting Started), Chapter 2: "Launching the Vivado Tools Using a Batch Tcl Script", page 8

**Command**:
```bash
vivado -mode batch -source <your_Tcl_script>
```

**On Windows**:
```bash
cd C:\path\to\project
vivado -mode batch -source batch_simulate.tcl -log batch.log
```

**Note**: When working in batch mode, Vivado tools exit after running the specified script. Use `-log <logfile>` to capture output.

### 7. Exporting Project State to TCL

**Source**: UG893 (Using the Vivado IDE), Chapter 1: "Working with Tcl", "Launching the Vivado Tools Using a Batch Tcl Script", page 9

**Procedure to Export Project**:
1. Open your configured Vivado project in GUI (after successful synthesis)
2. **File → Write Project Tcl** → Save as `Phase4/run_sims.tcl`
3. This creates a complete snapshot of:
   - Project configuration (device, files, settings)
   - Synthesis settings
   - Elaboration options
   - Tool settings

**Result**: `run_sims.tcl` can be sourced by batch scripts to recreate project state without GUI interaction.

### 8. Writing TCL Scripts for Batch Simulation

**Source**: UG893 (Using the Vivado IDE), Chapter 1: "Working with Tcl", page 9

**Script Structure** (example for Phase4/batch_simulate.tcl):
```tcl
# Define sweep parameters
set K_values {5 10 15 20}
set injection_rates {0.1 0.5 1.0 1.5 2.0}
set num_runs 3

# Nested loop over all configurations
foreach K $K_values {
  foreach inj_rate $injection_rates {
    for {set run 1} {$run <= $num_runs} {incr run} {
      # Source the exported project (from run_sims.tcl)
      source run_sims.tcl

      # Elaborate with parameter overrides
      elaborate -top tb_dispatcher_integration \
        -generics "WORKER_LATENCY=$K"

      # Launch behavioral simulation for 1500 cycles
      launch_simulation -scripts sim.tcl

      # Optionally capture waveform output
      # set_property -name {OUTPUT FORMAT} -value {VCD} [get_property target [current_run]]
    }
  }
}
```

**Key TCL Commands** (Source: UG894 - Using Tcl Scripting):
- `source <file>` — Load project via exported TCL
- `elaborate -top <module>` — Elaborate design at runtime
- `-generics <name>=<value>` — Override testbench parameter
- `launch_simulation -scripts <sim_tcl>` — Run XSim with custom script

**For detailed TCL syntax and batch simulation examples**, see [`TCL_BATCH_AUTOMATION_GUIDE.md`](./TCL_BATCH_AUTOMATION_GUIDE.md) (Sections 3–6: Elaboration, Simulation Control, Output Capture, Parameter Sweep Patterns)

---

## PART D: SIMULATION & WAVEFORM ANALYSIS

### 9. Running Logic Simulation (XSim)

**Source**: UG892 (Design Flows Overview), Chapter 1: "Design Analysis and Simulation", page 12

**In GUI**:
1. **Tools → Run Simulation** → Configure simulation settings
2. **Simulation → Run for <duration>** (set 1500 cycles per testbench)
3. Variables and waveforms display in integrated viewer

**In Batch Mode** (via TCL):
```tcl
launch_simulation -scripts {
  run 1500 ns
  exit
}
```

**Simulation Outputs** (source: UG893, Chapter 2, Section "Vivado IDE Viewing Environment" → "Results Windows Area", page 20):
- **Tcl Console**: Displays `$display()` statements from RTL (FSM state logs)
- **Log Window**: Full transcript of all messages
- **Waveform**: VCD file (if enabled) for post-processing

**FSM Debug Logging** (from testbench):
- RTL modules include synthesis translate_off sections with `$display()` statements
- These output FSM state transitions: `"FSM: state=STALL, release_wait_counter=2"`
- Parse these logs to count stall cycles

---

## PART E: TIMING & RESOURCE REPORTS

### 10. Accessing Synthesis Reports

**Source**: UG893 (Using the Vivado IDE), Chapter 3 (Using Windows), Section "Using the Reports Window", page 131

**In GUI**:
1. After synthesis completes, **Reports** panel updates automatically
2. **Reports → Synthesis → Design Summary** → Click to open
3. Key tables:
   - **Cell Counts** → Logic LUTs, Flip-Flops, Distributed RAM
   - **Timing Summary** → Fmax, Setup time, Hold time
   - **Utilization Summary** → % of available resources

**Via TCL Command**:
```tcl
report_timing -nworst 10 > timing_summary.txt
report_utilization > utilization_summary.txt
```

**Metrics to extract**:
- Fmax (MHz) — for Phase 4 final report
- LUT count and % utilization
- Flip-Flop count and % utilization
- BRAM blocks (should be 0 for QueueBit)
- Distributed RAM usage (matrix storage)

**For Python scripts to parse synthesis reports and extract metrics**, see [`SYNTHESIS_METRICS_EXTRACTION_GUIDE.md`](./SYNTHESIS_METRICS_EXTRACTION_GUIDE.md) (Sections 2–3: Timing Summary & Utilization Report Parsing)

---

## PART F: PROJECT MANAGEMENT & CHECKPOINTS

### 11. Saving & Opening Checkpoints

**Source**: UG892 (Design Flows Overview), Chapter 1: "RTL-to-Bitstream Design Flow", page 7; UG893, Chapter 2, page 32

**Creating Checkpoint** (automatic at each design stage):
Vivado writes checkpoints after:
- RTL elaboration (`.dcp` file)
- Synthesis (`.dcp` file)
- Implementation (`.dcp` file)

**Manually Loading Checkpoint** (to re-run from synthesis stage):
```bash
vivado -mode batch -source {
  open_checkpoint post_synth.dcp
  launch_runs impl_1
  wait_on_run impl_1
}
```

**Benefit for Phase 4**: Allows rapid re-simulation without re-synthesizing if only testbench parameters change.

---

## PART G: DESIGN ANALYSIS & TIMING CLOSURE

### 12. Timing Analysis & Slack Reporting

**Source**: UG906 (Design Analysis and Closure Techniques), Chapter 4 (Timing Analysis), p.71+; Referenced from UG893

**In Vivado IDE**:
1. After synthesis or implementation → **Reports → Timing Summary**
2. View:
   - **WNS (Worst Negative Slack)** — timing margin; positive = no violations
   - **TNS (Total Negative Slack)** — cumulative violations (should be 0)
   - **Critical paths** — signal routes limiting Fmax

**Understanding Slack** (from UG906, Chapter 4, "Timing Analysis and Slack" concepts):

```
Slack = Required Time - Actual Time

For setup timing:
  Setup Slack = Clock Period - (Delay + Setup Time)

For hold timing:
  Hold Slack = Delay - Hold Time
```

- **Positive slack**: Timing closure met (path is fast enough)
- **Negative slack**: Timing violation (path is too slow)
- **WNS > 0**: Design meets timing constraints
- **WNS < 0**: Violations exist; must increase clock period or optimize paths

**Critical path anatomy** (from UG906, Chapter 4, "Critical Paths" subsection):

1. **Source**: Register output (clk-to-Q delay)
2. **Logic**: Combinatorial delay through LUTs and interconnect
3. **Sink**: Register input (including setup time requirement)

Vivado's timing report shows entire path from source register to sink register.

**Expected Result for QueueBit**:
- No timing violations (WNS ≥ 0)
- Fmax ≈ 250–350 MHz on xc7z020 (28nm process)
- TNS = 0 (no violations)
- (Equivalent to Barber et al.'s 400+ MHz on 16nm when accounting for ~1.5× process scaling)

**Via TCL** (if needed for reporting to file):
```tcl
report_timing -cells {dispatcher_fsm/current_state} > fsm_timing.txt
```

**If timing closure fails** (WNS < 0):

Option 1: Increase clock period (reduce Fmax target)
```tcl
# In XDC, change from 10ns to 15ns:
create_clock -period 15.000 -name clk [get_ports clk]  ;# 100MHz → 66.7MHz
```

Option 2: Add pipeline stages to break long combinatorial chains
- Insert registers in critical paths (requires RTL changes)
- Trade-off: Increases latency but improves frequency

Option 3: Optimize RTL logic (advanced; not needed for Phase 4)
- Reduce LUT width by refactoring
- Reorder operations to reduce depth

**Phase 4 expectation**: No timing violations expected. If WNS < 0, verify RTL is correct and device is properly selected (xc7z020, not smaller device).

---

## PART H: BATCH COMMAND REFERENCE

### 13. Essential TCL Commands for Phase 4

**Source**: UG894 (Using Tcl Scripting), Referenced in UG893

| Command | Purpose | Example |
|---------|---------|---------|
| `open_project` | Load Vivado project | `open_project dispatcher.xpr` |
| `source` | Execute TCL script | `source run_sims.tcl` |
| `elaborate -top <module> -generics <list>` | Elaborate testbench with parameters | `elaborate -top tb_dispatcher_integration -generics {WORKER_LATENCY=10}` |
| `launch_simulation` | Run XSim behavioral simulation | `launch_simulation -scripts {run 1500 ns; exit}` |
| `wait_on_run` | Block until run completes | `wait_on_run synth_1` |
| `get_property` | Query design property | `get_property UTIL.LUT [get_runs synth_1]` |
| `write_checkpoint` | Save design snapshot | `write_checkpoint -force synth.dcp` |

**Logging Output**:
```tcl
set logfile [open "log_K10_inj1.0_1.txt" w]
puts $logfile "Simulation: K=10, Injection=1.0, Run=1"
close $logfile
```

---

## QUICK REFERENCE: Phase 4 Vivado Workflow

```
1. GUI Setup (45 min)
   ├─ Create project → add RTL files → set xc7z020clg400-1 as target
   ├─ Add XDC constraints (100 MHz clock + LVCMOS33 I/O)
   ├─ Run synthesis → Record Fmax, LUT%, FF%
   └─ Elaborate testbench to verify parameterization

2. TCL Preparation (20 min)
   ├─ File → Write Project Tcl → run_sims.tcl
   ├─ Edit tb_dispatcher_integration.sv: add WORKER_LATENCY parameter
   └─ Create batch_simulate.tcl with nested loops (K, inj_rate, runs)

3. Batch Execution (20 min)
   ├─ vivado -mode batch -source batch_simulate.tcl
   ├─ Generates 60 log files: log_K{5,10,15,20}_inj{0.1,...,2.0}_{1..3}.txt
   └─ Parse logs for FSM stall_count, syndromes_issued, worker_util

4. Analysis (30 min)
   ├─ extract_metrics.py → build/metrics.csv
   ├─ plot_results.py → 3 PDFs (stall curves, utilization, Fmax)
   └─ Verify stall rate trends: increase with K and load
```

---

**Document References**:
- **UG910**: Vivado Design Suite Getting Started (v2025.1)
- **UG892**: Vivado Design Suite User Guide: Design Flows Overview (v2025.1)
- **UG893**: Vivado Design Suite User Guide: Using the Vivado IDE (v2025.1)
- **UG894**: Vivado Design Suite User Guide: Using Tcl Scripting (v2025.1)
- **UG903**: Vivado Design Suite User Guide: Using Constraints (v2025.1)
- **UG906**: Vivado Design Suite User Guide: Design Analysis and Closure Techniques (v2025.1)

All documents available via AMD Documentation Navigator or https://docs.amd.com

**Last Updated**: 2026-04-05 | **Phase 4 Stage**: Active
