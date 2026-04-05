# QueueBit Phase 4 Deliverables

**Overview**: Results, data, and synthesis reports from Phase 4 (Synthesis & Performance Analysis)

---

## Contents

### Primary Results

**📊 stall_vs_load_sweep.png** (115 KB)
- **Main Finding**: Dispatcher stall rate vs. syndrome injection load, parameterized by worker latency K
- **Data**: 4 curves for K ∈ {5, 10, 15, 20} cycles
- **Interpretation**: Stall rate increases with K (collision-driven), but remains <90% at worst case; injection rate independent
- **Figure**: Referenced in final report as Figure 1

**📊 worker_utilization.png** (129 KB)
- **Finding**: Average concurrent busy workers (out of 4) vs. syndrome injection rate
- **Data**: Single curve, independent of K
- **Interpretation**: Pool remains below saturation (<1.2 workers average); 4-worker allocation is sufficient
- **Figure**: Referenced in final report as Figure 2

**📊 synthesis_fmax.png** (90 KB)
- **Metrics**: Fmax, LUT%, FF%, BRAM usage from Vivado synthesis
- **Highlights**: Fmax=127.5 MHz, LUT 5.30%, FF 0.86%
- **Figure**: Referenced in final report as Figure 3

### Data & Analysis

**📋 metrics.csv** (2.2 KB)
- **Format**: 60 rows (one per simulation) + header
- **Columns**: K, injection_rate, run, stall_cycles, total_cycles, stall_rate_pct, avg_workers, syndromes_issued, errors
- **Reproducibility**: Raw data enabling independent verification or re-analysis
- **Usage**: Import into Excel/Python/R for further statistical analysis

### Technical Reports

**📄 dispatcher_top_utilization_synth.rpt** (8.1 KB)
- **Source**: Vivado synthesis report (RTL-to-gates)
- **Contents**: Resource utilization breakdown by module
- **Audience**: Hardware engineers, archival

**📝 timing_summary.png** (38 KB)
- **Source**: Vivado timing analysis output
- **Shows**: Worst Negative Slack (WNS), critical path, timing closure status
- **Supplementary**: Detailed timing information for hardware review

---

## How to Read These Results

### For Reviewers/Readers

1. **Start here**: See `FINAL_REPORT.md` in this folder for full academic report with methodology and analysis
2. **Verify numbers**: Cross-reference report claims against `metrics.csv` data
3. **View graphs**: PNG files (stall_vs_load, worker_utilization, synthesis_fmax) are integrated into FINAL_REPORT.md
4. **Deep dive**: Examine `dispatcher_top_utilization_synth.rpt` for synthesis details

### For Reproducibility

1. All source code in `rtl/` and `tb/` directories (fully synthesizable)
2. Simulation methodology documented in final report (§3.3)
3. Metrics extraction scripts in `batch_run/` (extract_metrics.py, plot_results.py)
4. Run `./build.sh` from project root to execute full test suite

---

## Key Findings Summary

| Metric | Value | Status |
|--------|-------|--------|
| **Synthesis Fmax** | 127.5 MHz | PASS (27.5% margin) |
| **LUT Utilization** | 5.30% | Excellent |
| **FF Utilization** | 0.86% | Excellent |
| **K=5 Stall Rate** | 52.05% | Optimistic |
| **K=10 Stall Rate** | 68.91% | Baseline |
| **K=15 Stall Rate** | 84.25% | Conservative |
| **K=20 Stall Rate** | 88.55% | Upper bound |
| **Integration Test** | 221 syndromes, 0 collisions | PASS |

---

## Quality Checklist

- ✅ All PNG graphs at 300 DPI (publication quality)
- ✅ All metrics data in standardized CSV format
- ✅ Vivado reports extracted from official synthesis tool
- ✅ Results reproducible (methodology documented, code provided)
- ✅ No binary design files (Vivado project in .gitignore)
- ✅ Comprehensive academic report in deliverables/ (this folder)

---

**Folder Last Updated**: April 6, 2026
**Status**: Ready for Final Submission
**Total Size**: ~418 KB (graphs, data, technical reports)
