# d=23 Saturated Safety Validation Data

This folder contains the saturated d=23 safety validation data used by the report.

## Contents

- `d23_k20_saturated_safety_summary.csv`
- `raw/` per-case logs for `K20_INJ{500,1000,1500,2000}`

For each case in `raw/`:

- `*.sim.txt`: simulation console output
- `*.dispatch_log_d23.txt`: dispatch log with `LOCK` and `RELEASE` events
- `*.verify.txt`: output from `verification/verify_collisions.py`
- `*.syndrome_separation_log.txt`: concurrent-pair separation analysis

## Reproducibility

From repository root:

```powershell
python verification\reproduce_d23_safety_evidence.py --publish-deliverables
```

This command regenerates the saturated d=23 runs (`K=20`, `inj={0.5,1.0,1.5,2.0}`), reruns verification, and updates this folder.

## Inputs Used by the Script

- RTL: `rtl/dispatcher_pkg.sv`, `rtl/syndrome_fifo.sv`, `rtl/tracking_matrix.sv`, `rtl/dispatcher_fsm_d23.sv`, `rtl/dispatcher_top_d23.sv`
- Testbench: `tb/tb_dispatcher_integration_d23.sv`
- Verifier: `verification/verify_collisions.py`
- Stimulus: `verification/stim_errors_d23.txt`
