# Deliverables

This folder contains the current QueueBit deliverable package. It should be used as the primary source for report writing, figure generation, and submission preparation.

## Package Contents

### `QUEUEBIT_REPORT_DRAFT.md`

Final markdown draft of the paper/report based on the sweep datasets and synthesis runs.

### `d11/`

d=11 artifacts:
- `metrics.csv`: d=11 sweep output
- `synthesis_metrics.txt`: extracted post-route synthesis summary
- `timing_report.txt`
- `utilization_report.txt`
- `power_report.txt`
- `design_report.txt`

### `d23/`

d=23 artifacts:
- `k_sweep_results.csv`: d=23 sweep summary
- `synthesis_metrics.txt`: extracted post-route synthesis summary
- `timing_report.txt`
- `utilization_report.txt`
- `power_report.txt`
- `design_report.txt`

### `figures/`

Paper figures and summary data:
- `figure_cycles_distance_comparison.png`
- `figure_stall_distance_comparison.png`
- `figure_d23_collisions.png`
- `paper_results_summary.csv`

## How To Read This Package

Use the package in this order:

1. Read `QUEUEBIT_REPORT_DRAFT.md` for the full narrative.
2. Use `figures/` for plots referenced by the draft.
3. Use `d11/` and `d23/` for the underlying simulation and synthesis artifacts.

## Important Interpretation Notes

- The d23 `Collisions Detected` counts are treated in the report as hazard detections or blocked conflict events, not as direct proof of unsafe overlap.
- The report uses stall fraction of runtime, defined as `stall_cycles / total_cycles * 100`, rather than the older mixed-unit `stalled / issued * 100` metric.
- The synthesis comparison is reported fairly at the applied 100 MHz target for both d=11 and d=23.
