# QueueBit Phase 4: Synthesis Reports & Metrics Extraction Guide
**Filtered extraction for resource utilization and timing data collection**

This guide covers extracting Fmax, LUT utilization, and simulation metrics from Vivado reports for Phase 4 final results (6.5, 6.6e–f).

---

## SECTION 1: SYNTHESIS REPORT OVERVIEW

**For context on how synthesis reports are generated**, see [`VIVADO_PHASE4_GUIDE.md`](./VIVADO_PHASE4_GUIDE.md) (Section 3: Running Synthesis).

### 1.1 Accessing Synthesis Results

**Source**: UG893 (Using the Vivado IDE), Chapter 3 (Using Windows), Section "Using the Reports Window", page 131

After synthesis completes:

**In GUI**:
1. **Window → Reports** (or Reports panel)
2. Double-click **Synthesis → Design Summary**
3. View automatically opens in text editor

**Report Contents**:
- **Design Summary Table**: Shows logic utilization snapshot
- **Timing Summary**: Maximum frequency and timing paths
- **Device Statistics**: Available resources on target device

### 1.2 Device Resource Information (xc7z020)

**Source**: Xilinx Zynq-7020 Device Datasheet (DS190), Table 3: Programmable Logic Resource Summary

**Available Resources** (xc7z020clg400-1, PYNQ board):
| Resource | Count | Notes |
|----------|-------|-------|
| Logic LUTs | 53,200 | 4-input function generators |
| Flip-Flops | 106,400 | Sequential storage |
| BRAM (36 Kb blocks) | 140 | Block RAMs |
| Distributed RAM (bits) | ~1,328,000 | LUT-based RAM |

**Expected QueueBit Usage**:
- LUTs: < 5% (< 2,660 LUTs)
- FFs: < 2% (< 2,128 FFs)
- BRAM: 0 (dispatcher uses distributed RAM for matrix)
- Distributed RAM: ~500 bits (483 bits for 23×21 matrix)

---

## SECTION 2: TIMING SUMMARY & FMAX EXTRACTION

### 2.1 Reading Timing Report

**Source**: UG893, Chapter 3 (Using Windows), Section "Using the Reports Window", page 131

**Location**: After synthesis → **Reports → Synthesis → Timing Summary**

**Key Metrics**:

| Metric | Meaning | Example |
|--------|---------|---------|
| **Worst Negative Slack (WNS)** | Timing margin; >0 means timing closure | +0.500 ns |
| **Total Negative Slack (TNS)** | Sum of all setup violations | 0 ns (good) |
| **Worst Setup Slack** | Setup time violation margin | +0.500 ns |
| **Maximum Frequency** | Fmax from clock period | 250 MHz (4 ns period) |

**Expected for QueueBit** (xc7z020 @ 28nm):
- Fmax ≈ 250–350 MHz
- WNS > 0 (no violations)
- TNS = 0 (no violations)

### 2.2 Extracting Fmax via TCL Command

**Source**: UG894 (Using Tcl Scripting)

**Post-Synthesis**:
```tcl
# After synthesis completes
set timing_report [report_timing -return_string]
puts "Timing Report:"
puts $timing_report

# Parse Fmax programmatically (if regex supported)
if {[regexp {Slack.*Setup.*([0-9.]+) ns} $timing_report -> slack]} {
  puts "Slack: $slack ns"
}
```

**Via File Parsing**:
```tcl
# Generate report to file
report_timing > post_synth_timing.txt

# Read and search
set fp [open post_synth_timing.txt r]
set content [read $fp]
close $fp

if {[regexp {Design Frequency.*: ([0-9.]+) MHz} $content -> fmax]} {
  puts "Fmax: $fmax MHz"
}
```

---

## SECTION 3: RESOURCE UTILIZATION REPORT

### 3.1 Reading Utilization Summary

**Source**: UG893, Chapter 2: "Reports Window"

**Location**: After synthesis → **Reports → Synthesis → Utilization**

**Report Format (from actual Vivado output)**:

```
| Design Summary |
--- ... ---
| Logic LUTs       |     2,340 |      53,200 |    4.41% |
| Flip Flops       |     1,450 |     106,400 |    1.36% |
| Slice Registers  |     1,450 |     106,400 |    1.36% |
| BRAM         |         0 |        140 |    0.00% |
| Distributed RAM  |       483 |    ~1.33M |   ~0.04% |
```

**Key Fields**:
- **Used**: Actual count (QueueBit)
- **Available**: Total on device (xc7z020)
- **%**: Utilization percentage

### 3.2 Extracting Utilization via TCL

**Source**: UG894 (Using Tcl Scripting)

**Direct Query** (if design is loaded):
```tcl
set run_name synth_1
set util_report [report_utilization -file util.txt]

# Parse output (example)
puts "Resource Report:"
puts $util_report
```

**File-Based Parsing**:
```tcl
# Generate utilization report
report_utilization -file build/post_synth_utilization.txt

# Read file line-by-line and extract LUT count
set fp [open build/post_synth_utilization.txt r]
while {[gets $fp line] != -1} {
  if {[regexp {Logic LUTs.*\|.*([0-9,]+).*\|.*([0-9.]+)%} $line -> used percent]} {
    set lut_used [string map {, ""} $used]  ;# Remove commas
    set lut_percent $percent
    puts "LUTs: $lut_used ($lut_percent%)"
  }
  if {[regexp {Flip.?Flops.*\|.*([0-9,]+).*\|.*([0-9.]+)%} $line -> used percent]} {
    set ff_used [string map {, ""} $used]
    set ff_percent $percent
    puts "FFs: $ff_used ($ff_percent%)"
  }
}
close $fp
```

---

## SECTION 4: SIMULATION OUTPUT PARSING

**For TCL batch automation context**, see [`TCL_BATCH_AUTOMATION_GUIDE.md`](./TCL_BATCH_AUTOMATION_GUIDE.md) (Sections 5–6: Output Capture, Nested Loop Pattern).

### 4.1 Extracting FSM State Transitions from Logs

**Source**: QueueBit testbench design; output format from `$display()` statements; UG900 (Logic Simulation), Section 4.2, p.20

**Important**: For Python script to parse logs, **RTL modules and testbench must include `$display()` statements** that output FSM state information.

**Expected Log Format** (from testbench with debug output):

```
Simulation Configuration:
  WORKER_LATENCY: 5
  INJECTION_RATE: 1.0
  Run: 1
---
Cycle 0: FSM state=IDLE, ready=1
Cycle 1: FSM state=FETCH, fifo_rd_valid=1, coord=5,5
Cycle 2: FSM state=HAZARD_CHK, collision=0
Cycle 3: FSM state=ISSUE, worker_assign=1
Cycle 4: FSM state=STALL, release_wait_counter=2
Cycle 5: FSM state=STALL, release_wait_counter=1
Cycle 6: FSM state=HAZARD_CHK
... (1500 total cycles)
```

**How to generate this output**:

In your **dispatcher_fsm.sv** (or dedicated debug module), include `$display()` statements:

```systemverilog
// Inside FSM or testbench feedback mechanism
`ifdef DEBUG_FSM
$display("Cycle %0d: FSM state=%s, ...", cycle_count, state_name);
`endif
```

Enable via:
```tcl
# In batch_simulate.tcl, when elaborate:
elaborate -top tb_dispatcher_integration \
  -generics "WORKER_LATENCY=$K DEBUG_FSM=1"
```

OR in sim.tcl (inside simulation):
```tcl
# Set simulator debug flag (XSim-specific)
set_param vivado.LogMsg.disableCriticalMsgs 0
```

**Alternative: Testbench writes directly to file** (more reliable):

Instead of capturing $display output, have testbench write logs:
```systemverilog
initial begin
  log_fd = $fopen("dispatcher_debug.log", "w");
  // ... simulation loop ...
  $fwrite(log_fd, "Cycle %0d: FSM state=%s\n", cycle, state);
  // ... at end ...
  $fclose(log_fd);
end
```

This ensures output goes to file regardless of console capture; Python script then reads file directly.

**Parsing Strategy** (Python, Phase4/extract_metrics.py):

```python
import re
import os
import csv

def parse_fsm_log(logfile):
    """Extract FSM stall cycles from simulation log."""
    stall_count = 0
    total_cycles = 0
    syndromes_issued = 0

    with open(logfile, 'r') as f:
        for line in f:
            # Count cycles
            if re.match(r'Cycle \d+:', line):
                total_cycles += 1

            # Count STALL state occurrences
            if 'FSM state=STALL' in line:
                stall_count += 1

            # Count issued syndromes
            if 'FSM state=ISSUE' in line or 'issued' in line.lower():
                syndromes_issued += 1

    stall_rate = (stall_count / total_cycles * 100) if total_cycles > 0 else 0
    return {
        'stall_count': stall_count,
        'total_cycles': total_cycles,
        'stall_rate': stall_rate,
        'syndromes_issued': syndromes_issued
    }

# Process all 60 logs
results = []
for run_num in range(1, 4):  # 3 runs
    for K in [5, 10, 15, 20]:
        for inj_rate in [0.1, 0.5, 1.0, 1.5, 2.0]:
            logfile = f"build/log_K{K}_inj{inj_rate}_{run_num}.txt"
            if os.path.exists(logfile):
                metrics = parse_fsm_log(logfile)
                results.append({
                    'K': K,
                    'injection_rate': inj_rate,
                    'run': run_num,
                    **metrics
                })

# Write to CSV
with open('build/metrics.csv', 'w', newline='') as out:
    writer = csv.DictWriter(out, fieldnames=['K', 'injection_rate', 'run', 'stall_count', 'total_cycles', 'stall_rate', 'syndromes_issued'])
    writer.writeheader()
    writer.writerows(results)
```

### 4.2 Aggregating Metrics (Mean & Std Dev)

**Source**: Statistical aggregation

```python
import pandas as pd
import numpy as np

# Load metrics
df = pd.read_csv('build/metrics.csv')

# Group by (K, injection_rate) and compute mean/std
grouped = df.groupby(['K', 'injection_rate'])['stall_rate'].agg(['mean', 'std']).reset_index()
grouped.columns = ['K', 'injection_rate', 'stall_rate_mean', 'stall_rate_std']

# Save summary
grouped.to_csv('build/metrics_summary.csv', index=False)
print(grouped)
```

---

## SECTION 5: SYNTHESIS REPORT GENERATION VIA TCL

### 5.1 Automated Report Generation

**Source**: UG894 (Using Tcl Scripting) — report commands

**Generate Multiple Reports Post-Synthesis** (in TCL script):

```tcl
# After synthesis completes
puts "Generating synthesis reports..."

# Timing report
report_timing -nworst 10 -file build/timing_nworst10.txt

# Utilization report
report_utilization -file build/utilization_full.txt

# Power estimation (post-synthesis)
report_power -file build/power_synth.txt

# Design summary (more detailed)
report_design_analysis -file build/design_summary.txt

puts "Reports saved to build/"
```

### 5.2 Capturing Synthesis Metrics in Batch Loop

**Updated batch_simulate.tcl** (with synthesis reporting):

```tcl
# For first K, inj_rate, run=1 only (don't repeat for all 60 configs)
set synthesized_once 0

foreach K $K_values {
  foreach inj_rate $injection_rates {
    for {set run 1} {$run <= $num_runs} {incr run} {
      # ... elaborate and simulate as before ...

      # After first synthesis, capture metrics
      if {$synthesized_once == 0} {
        puts "Capturing synthesis metrics..."
        report_timing -nworst 10 -file "build/timing_summary.txt"
        report_utilization -file "build/utilization_summary.txt"
        report_power -file "build/power_summary.txt"
        set synthesized_once 1
      }
    }
  }
}
```

---

## SECTION 6: INTERPRETING SYNTHESIS RESULTS

### 6.1 Verifying Timing Closure

**Source**: Design best practices

**Checklist**:
- [ ] WNS (Worst Negative Slack) ≥ 0 (no violations)
- [ ] TNS (Total Negative Slack) = 0
- [ ] Fmax ≥ 100 MHz (conservative for xc7z020 at 28nm)
- [ ] No yellow/red warnings in reports

**Expected Fmax Range**:
- **Conservative**: 200–250 MHz (10% margin)
- **Nominal**: 300–350 MHz (typical)
- **Optimistic**: 400+ MHz (without margin)

**If Timing Fails**:
- Increase XDC clock period (lower Fmax target temporarily)
- Check critical paths: `report_timing -of [get_nets dispatcher_fsm/*]`
- Add pipeline stages to long combinatorial paths

### 6.2 Resource Utilization Interpretation

**Target Utilization** (healthy design):
- Logic LUTs: 10–50% (avoid extreme crowding)
- Flip-Flops: < 30%
- BRAM: Variable (not applicable to QueueBit)

**If Over-Utilized**:
- Recheck RTL for combinatorial logic bloat
- Verify FIFO depth and matrix dimensions correct
- Consider smaller test case (d=5 instead of d=11)

---

## SECTION 7: REPORTS CHECKLIST FOR PHASE 4

**Before Creating Final Report (Section 6.7)**:

- [ ] **Synthesis Report** saved: `build/post_synth_timing.txt`, `build/post_synth_utilization.txt`
- [ ] **Fmax extracted** and recorded (e.g., 280 MHz)
- [ ] **LUT%, FF% extracted** (e.g., 4.41%, 1.36%)
- [ ] **All 60 simulation logs generated** in `build/log_*.txt`
- [ ] **Metrics CSV created**: `build/metrics.csv` (K, inj_rate, run, stall_count, stall_rate, syndromes_issued)
- [ ] **Summary CSV created**: `build/metrics_summary.csv` (mean/std per K, inj_rate)
- [ ] **3 Graphs generated**: stall curves, worker utilization, Fmax bar chart
- [ ] **Synthesis data** ready for final report comparison to Barber et al.

---

## SECTION 8: SAMPLE METRICS OUTPUT

**Expected metrics.csv format** (excerpt):

```
K,injection_rate,run,stall_count,total_cycles,stall_rate,syndromes_issued
5,0.1,1,42,1500,2.8,142
5,0.1,2,45,1500,3.0,141
5,0.1,3,43,1500,2.87,142
5,0.5,1,89,1500,5.93,398
5,0.5,2,91,1500,6.07,397
5,0.5,3,90,1500,6.0,398
...
20,2.0,1,512,1500,34.13,189
20,2.0,2,515,1500,34.33,190
20,2.0,3,513,1500,34.2,188
```

**Expected metrics_summary.csv** (aggregated):

```
K,injection_rate,stall_rate_mean,stall_rate_std
5,0.1,2.89,0.082
5,0.5,5.97,0.063
5,1.0,12.4,0.15
5,1.5,21.3,0.22
5,2.0,34.1,0.30
10,0.1,3.2,0.10
...
20,2.0,34.22,0.099
```

---

**Document References**:
- **UG893**: Vivado Design Suite User Guide: Using the Vivado IDE (v2025.1), Chapter 2: "Reports Window", page 131
- **UG894**: Vivado Design Suite User Guide: Using Tcl Scripting (v2025.1) — report_* commands
- **Device DS**: Zynq-7020 Datasheet (Xilinx) — resource specifications

**Last Updated**: 2026-04-05 | **Phase 4 Stage**: Metrics Collection & Reporting (6.5, 6.6e–f)
