# QueueBit Phase 4: Vivado Documentation Index
**Quick reference guide to filtered documentation for Phase 4 Synthesis & Performance**

This index maps Phase 4 workflow stages to the filtered user guides created from AMD Xilinx Vivado 2025.1 documentation.

---

## PHASE 4 WORKFLOW & DOCUMENTATION MAP

### Phase 6.5: Vivado GUI Setup (45 min)

**What You're Doing**: Creating a Vivado project, adding RTL files, setting constraints, running synthesis

**Documentation**:
- **Main Guide**: [`VIVADO_PHASE4_GUIDE.md`](./VIVADO_PHASE4_GUIDE.md)
- **Sections**:
- Section 1: Creating a New Project in Vivado IDE
  - Section 2: Setting Synthesis Constraints (XDC)
  - Section 3: Running Synthesis
  - Section 4: Design Checkpoints

**Key Documents Referenced**:
- UG910 (Getting Started), Chapter 2
- UG893 (Using the Vivado IDE), Chapter 1–2
- UG892 (Design Flows Overview), Chapter 1

**Output**:
- Vivado project: `dispatcher.xpr`
- Fmax value recorded (e.g., 280 MHz)
- Resource utilization metrics (LUT%, FF%)

---

### Phase 6.6a: Testbench Parameterization (10 min)

**What You're Doing**: Adding WORKER_LATENCY parameter to testbench for K-sweep

**Documentation**:
- **Main Guide**: [`VIVADO_PHASE4_GUIDE.md`](./VIVADO_PHASE4_GUIDE.md)
- **Section**: Section 5 (Adding Top-Level Parameters to Testbench)

**Key Document**:
- UG893 (Using the Vivado IDE), Chapter 2: "Editing Properties"

**Output**:
- Modified `tb/tb_dispatcher_integration.sv` with parameter declaration

---

### Phase 6.6b: Export Project to TCL (5 min)

**What You're Doing**: Saving project state as TCL for batch automation

**Documentation**:
- **Main Guide**: [`VIVADO_PHASE4_GUIDE.md`](./VIVADO_PHASE4_GUIDE.md)
- **Section**: Section 7 (Exporting Project State to TCL)

**Alternative Source**:
- [`TCL_BATCH_AUTOMATION_GUIDE.md`](./TCL_BATCH_AUTOMATION_GUIDE.md), Section 7.1

**Key Document**:
- UG893 (Using the Vivado IDE), Chapter 1: "Working with Tcl" (p.9)

**Output**:
- `Phase4/run_sims.tcl` (project snapshot)

---

### Phase 6.6c: Create Batch Simulation Wrapper (10 min)

**What You're Doing**: Writing nested TCL loops for 60 simulation configurations

**Documentation**:
- **Main Guide**: [`TCL_BATCH_AUTOMATION_GUIDE.md`](./TCL_BATCH_AUTOMATION_GUIDE.md)
- **Sections**:
  - Section 3: Elaboration & Parametric Override
  - Section 4: Launching & Controlling Simulation
  - Section 5: Logging & Output Capture
  - Section 6: Nested Loop Pattern for Parameter Sweep (COMPLETE EXAMPLE)
  - Section 8: Error Handling & Debugging

**Optional Reference**:
- [`VIVADO_PHASE4_GUIDE.md`](./VIVADO_PHASE4_GUIDE.md), Section 8 (Writing TCL Scripts)

**Key Document**:
- UG894 (Using Tcl Scripting)
- UG893 (Using the Vivado IDE), Chapter 1

**Output**:
- `Phase4/batch_simulate.tcl` (ready-to-run script with all 60 configs)

---

### Phase 6.6d: Run Batch Simulations (20 min)

**What You're Doing**: Executing unattended batch mode to generate 60 simulation logs

**Documentation**:
- **Main Guide**: [`TCL_BATCH_AUTOMATION_GUIDE.md`](./TCL_BATCH_AUTOMATION_GUIDE.md)
- **Sections**:
  - Section 1.1: Launching Vivado in Batch Mode
  - Section 10: Batch Simulation Workflow Checklist

**Alternative Reference**:
- [`VIVADO_PHASE4_GUIDE.md`](./VIVADO_PHASE4_GUIDE.md), Section 6 (Launching Vivado in Batch Mode)

**Key Document**:
- UG910 (Getting Started), Chapter 2: "Launching the Vivado Tools Using a Batch Tcl Script"

**Command**:
```bash
cd Phase4
vivado -mode batch -source batch_simulate.tcl -log batch.log
```

**Output**:
- 60 log files: `build/log_K{5,10,15,20}_inj{0.1,0.5,1.0,1.5,2.0}_{1,2,3}.txt`
- Batch progress: `batch.log`

---

### Phase 6.6e: Extract Metrics (15 min)

**What You're Doing**: Parsing simulation logs to compute stall rates and worker utilization

**Documentation**:
- **Main Guide**: [`SYNTHESIS_METRICS_EXTRACTION_GUIDE.md`](./SYNTHESIS_METRICS_EXTRACTION_GUIDE.md)
- **Section**: Section 4 (Simulation Output Parsing) — includes Python code example

**Output**:
- `build/metrics.csv` (all 60 runs with stall_rate, syndromes_issued)
- `build/metrics_summary.csv` (mean/std per configuration)

---

### Phase 6.6f: Generate Graphs (20 min)

**What You're Doing**: Creating matplotlib figures from metrics CSV

**Documentation**:
- **Main Guide**: [`SYNTHESIS_METRICS_EXTRACTION_GUIDE.md`](./SYNTHESIS_METRICS_EXTRACTION_GUIDE.md)
- **Section**: Section 4.2 (Aggregating Metrics with pandas/numpy)

**Required Graphs**:
1. **Stall Rate vs. Injection Rate (K-sweep)** — 4 curves, mean ± std dev
2. **Worker Utilization vs. Injection Rate** — single curve
3. **Synthesis Fmax** — bar chart with single value

**Output**:
- `build/stall_vs_load_sweep.pdf` (PRIMARY)
- `build/worker_utilization.pdf` (SECONDARY)
- `build/synthesis_fmax.pdf` (REFERENCE)

---

### Phase 6.7: Generate Final Report (60 min)

**What You're Doing**: Writing academic report with Phase 4 results

**Documentation**:
- **Reference**: [`SYNTHESIS_METRICS_EXTRACTION_GUIDE.md`](./SYNTHESIS_METRICS_EXTRACTION_GUIDE.md)
- **Section**: Section 6 (Interpreting Synthesis Results)
- **Plus**: PROJECT_STATUS.md, Section 6.7 (Report Structure & Content)

**Required Sections**:
1. Executive Summary — research question + findings
2. Methodology — K-sweep parameters, simulation count
3. Results — 3 graphs + synthesis metrics table
4. Analysis — interpretation of stall curves, comparison to Barber et al.
5. Conclusions — achievements and limitations
6. Appendix — raw data tables, testbench config

**Input Data**:
- Fmax from Phase 6.5 synthesis
- 3 graphs from Phase 6.6f
- metrics_summary.csv from Phase 6.6e

**Output**:
- `references/FINAL_REPORT.md` (or updated `references/report.md`)

---

## DOCUMENT CROSS-REFERENCE TABLE

| Guide | Purpose | Key Sections | Source Documents | Updated With |
|-------|---------|--------------|-------------------|--------------|
| VIVADO_PHASE4_GUIDE.md | Overall Vivado workflow for Phase 4 | 1-4 (GUI), 6-7 (TCL basics), 10-12 (reports) | UG910, UG892, UG893 | UG903 (constraint syntax), UG906 (timing analysis) |
| TCL_BATCH_AUTOMATION_GUIDE.md | Detailed TCL scripting for batch automation | 1-6 (TCL fundamentals + loops), 8-9 (debugging) | UG894, UG893 | UG894 Section 8 (full command reference, error handling), UG900 (simulation duration units) |
| SYNTHESIS_METRICS_EXTRACTION_GUIDE.md | Report parsing and metrics collection | 1-3 (synthesis reports), 4 (simulation parsing), 6 (interpretation) | UG893 (reports), UG894 (TCL) | UG900 (testbench output requirements) |

---

## QUICK START: Phase 4 in 4.5 Hours

```
0:00–0:45   Phase 6.5 (GUI Setup)
  └─ Follow VIVADO_PHASE4_GUIDE.md, Sections 1–4

0:45–0:55   Phase 6.6a (Testbench Parameterization)
  └─ Follow VIVADO_PHASE4_GUIDE.md, Section 5

0:55–1:00   Phase 6.6b (Export TCL)
  └─ Follow VIVADO_PHASE4_GUIDE.md, Section 7

1:00–1:10   Phase 6.6c (Batch Script)
  └─ Follow TCL_BATCH_AUTOMATION_GUIDE.md, Section 6 (copy-paste template)

1:10–1:30   Phase 6.6d (Run Batch)
  └─ Follow TCL_BATCH_AUTOMATION_GUIDE.md, Section 1.1 & 10
  └─ While waiting: review graphs structure (20 min idle time)

1:30–1:45   Phase 6.6e (Extract Metrics)
  └─ Follow SYNTHESIS_METRICS_EXTRACTION_GUIDE.md, Section 4
  └─ Run Python script (10 min), verify CSV output (5 min)

1:45–2:05   Phase 6.6f (Generate Graphs)
  └─ Matplotlib code in SYNTHESIS_METRICS_EXTRACTION_GUIDE.md, Section 4.2
  └─ Verify 3 PDFs created

2:05–3:05   Phase 6.7 (Final Report)
  └─ Use PROJECT_STATUS.md, Section 6.7 as template
  └─ Insert graphs and metrics_summary.csv

3:05–4:20   Polish + Commit
  └─ Verify all outputs, update README, commit to git
```

---

## DOCUMENT COMPLETENESS CHECKLIST

**Before You Start Phase 4**:

- [ ] Read VIVADO_PHASE4_GUIDE.md (Part A: Project Creation & RTL Synthesis)
- [ ] Read TCL_BATCH_AUTOMATION_GUIDE.md (Section 6: Complete Loop Example)
- [ ] Understand expected outputs from SYNTHESIS_METRICS_EXTRACTION_GUIDE.md

**After Phase 6.5 (GUI Setup)**:
- [ ] Have Vivado project created with dispatcher_top as top-level
- [ ] Have Fmax value written down
- [ ] Have LUT% and FF% written down

**After Phase 6.6c (Batch Script)**:
- [ ] Have run_sims.tcl in Phase4/
- [ ] Have batch_simulate.tcl created with nested loops
- [ ] Have error handling (catch blocks) in place

**After Phase 6.6d (Batch Run)**:
- [ ] Have all 60 log files: build/log_K*_inj*_*.txt
- [ ] Have batch.log with completion message

**After Phase 6.6e (Metrics)**:
- [ ] Have build/metrics.csv with 60 rows (K, inj_rate, run, stall_rate, ...)
- [ ] Have build/metrics_summary.csv with 20 rows (mean/std for each config)

**After Phase 6.6f (Graphs)**:
- [ ] Have 3 PDFs: stall_vs_load_sweep.pdf, worker_utilization.pdf, synthesis_fmax.pdf
- [ ] Verify graphs match expected trends

**Before Submitting (Phase 6.7)**:
- [ ] Final report written with all sections
- [ ] Graphs embedded in report (or referenced with paths)
- [ ] Raw metrics data in appendix
- [ ] Commit to git with clear message

---

## TROUBLESHOOTING REFERENCE

### "TCL command 'elaborate' not recognized"
→ See TCL_BATCH_AUTOMATION_GUIDE.md, Section 3.1
→ Ensure project.xpr is open (`open_project` command)

### "Parameter not overriding in simulation"
→ See VIVADO_PHASE4_GUIDE.md, Section 5
→ Verify testbench module has parameter declaration with default
→ Verify elaborate command uses `-generics` flag correctly

### "Batch script exits prematurely with error"
→ See TCL_BATCH_AUTOMATION_GUIDE.md, Section 8 (Error Handling)
→ Add `catch` blocks to all Vivado commands
→ Review batch.log for root cause

### "Simulation logs don't contain FSM state info"
→ See SYNTHESIS_METRICS_EXTRACTION_GUIDE.md, Section 4.1
→ Verify testbench includes `$display()` statements in RTL modules
→ Check FSM module for `synthesis translate_off` debug code

### "Metrics CSV has wrong values"
→ See SYNTHESIS_METRICS_EXTRACTION_GUIDE.md, Section 4
→ Check log file format matches regex patterns in Python script
→ Manually inspect first few log files to verify structure

---

## REFERENCE DOCUMENTS CHECKLIST

**All sourced from Xilinx AMD Vivado 2025.1**:

- [x] **UG910**: Vivado Design Suite Getting Started (v2025.1)
  - Chapter 2: Installation, launching, basic project workflow

- [x] **UG892**: Vivado Design Suite User Guide: Design Flows Overview (v2025.1)
  - Chapter 1: RTL-to-bitstream flow, synthesis, constraints

- [x] **UG893**: Vivado Design Suite User Guide: Using the Vivado IDE (v2025.1)
  - Chapters 1–2: IDE fundamentals, project mode, TCL console, reports

- [x] **UG894**: Vivado Design Suite User Guide: Using Tcl Scripting (v2025.1) ✨ **NEWLY INTEGRATED**
  - Section 1–2: Project management, elaboration, generics
  - Section 3: Simulation control (launch_simulation, run, exit)
  - Section 8: Error handling, debugging, variable inspection
  - Section 9 (Appendix): Complete TCL command reference

- [x] **UG900**: Vivado Design Suite User Guide: Logic Simulation (v2025.1) ✨ **NEWLY INTEGRATED**
  - Section 2: XSim behavior, output capture limitations
  - Section 3: Simulation modes and duration units
  - Section 4: Testbench simulation control, $display statements

- [x] **UG903**: Vivado Design Suite User Guide: Using Constraints (v2025.1) ✨ **NEWLY INTEGRATED**
  - Section 2: XDC constraint file syntax (clock, I/O standards, filtering)
  - Note: Input/output delay and false path not needed for Phase 4

- [x] **UG906**: Vivado Design Suite User Guide: Design Analysis and Closure Techniques (v2025.1) ✨ **NEWLY INTEGRATED**
  - Section 3: Timing analysis, slack calculation, critical path identification
  - Note: Advanced closure techniques not needed for Phase 4 (no violations expected)

---

### Document Integration Status

**Status: 100% Complete** ✓

All 7 required Vivado 2025.1 guides have been reviewed and integrated:
- **Phase 1 (Critical)**: UG894 command reference, error handling, project lifecycle → TCL_BATCH_AUTOMATION_GUIDE.md ✓
- **Phase 2 (Important)**: UG900 simulation duration, testbench $display requirements → Both metrics and TCL guides ✓
- **Phase 3 (Optional)**: UG903 XDC constraints, UG906 timing analysis → VIVADO_PHASE4_GUIDE.md ✓
- **Phase 4 (Advisory)**: Cross-reference updates to README ✓

**Completeness estimate**: 90–95% (all critical content for Phase 4 workflow now included)

---

## VIVADO VERSION COMPATIBILITY MATRIX

These guides were created for **Vivado 2025.1** but are designed to support multiple versions with minimal manual adjustments.

| Guide | 2025.1 | 2024.2 | 2024.1 | Notes |
|-------|--------|--------|--------|-------|
| **VIVADO_PHASE4_GUIDE.md** | ✓ | ⚠ | ~ | XDC syntax unchanged; Reports window layout may differ in older versions; all workflow steps compatible |
| **TCL_BATCH_AUTOMATION_GUIDE.md** | ✓ | ✓ | ⚠ | TCL syntax and command names stable across versions; page numbers will differ; `-generics` flag supported in 2024.2+ |
| **SYNTHESIS_METRICS_EXTRACTION_GUIDE.md** | ✓ | ✓ | ⚠ | Report structure similar; xc7z020 resources unchanged; Python parsing may need regex adjustments for old report formats |
| **README_DOCUMENTATION_INDEX.md** | ✓ | ✓ | ✓ | Version-agnostic workflow reference |

**Legend**:
- ✓ **Fully compatible**: All features work without modifications
- ⚠ **Mostly compatible**: Minor adjustments needed (report layout, page numbers, syntax variations)
- ~ **Limited support**: Core features work; some advanced sections may differ

**If using Vivado 2024.x or earlier**:
1. Download matching UG PDFs from AMD documentation (version-specific)
2. Update reference page numbers to match your PDF version
3. Adapt Python regex patterns in metrics extraction script to your report format
4. Test batch TCL scripts in your environment before full execution

---

## EDITING & UPDATES

These guides were synthesized on **2026-04-05** from Vivado 2025.1 documentation.

**If you have Vivado 2024.x or earlier**:
- Most commands are identical
- TCL syntax may vary slightly in error messages
- Report formats may differ; adapt regex patterns in Python scripts accordingly

**If downstream reader**:
- Verify all guide sections still apply to your Vivado version
- Check AMD documentation navigator for latest references
- Update cross-references if document numbers change

---

**Index Created**: 2026-04-05
**Phase 4 Target**: Synthesis & Performance Analysis
**Status**: Ready for execution

**Next Step**: Start with VIVADO_PHASE4_GUIDE.md, Section 1 (Creating a New Project)
