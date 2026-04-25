# Deliverables

This folder contains the submission package for QueueBit.

## Contents

### `QUEUEBIT_REPORT_DRAFT.md`

Current report draft.

### `d11/`

d=11 sweep and synthesis artifacts:

- `metrics.csv`
- `synthesis_metrics.txt`
- `timing_report.txt`
- `utilization_report.txt`
- `power_report.txt`
- `design_report.txt`

### `d23/`

d=23 sweep and synthesis artifacts:

- `k_sweep_results.csv`
- `synthesis_metrics.txt`
- `timing_report.txt`
- `utilization_report.txt`
- `power_report.txt`
- `design_report.txt`
- `safety_validation/`: saturated d=23 (`K=20`, `inj>=0.5`) safety validation data
  - `d23_k20_saturated_safety_summary.csv`
  - `raw/` per-case simulation logs, dispatch logs, and verification outputs

### `figures/`

Figure files and summary CSV used by the report.

## Reproducing Saturated d=23 Safety Validation Data

From repository root:

```powershell
python verification\reproduce_d23_safety_evidence.py --publish-deliverables
```

This command regenerates the saturated d=23 runs, reruns trace verification, and writes outputs to:

- `build/safety_d23/`
- `deliverables/d23/safety_validation/`

## Notes

- In d=23 saturated runs (`K=20`, `inj>=0.5`), the testbench counter `Collisions Detected` corresponds to blocked hazards in the dispatch FSM.
- The validated traces in `d23/safety_validation/` show zero spatial overlap for those runs.
