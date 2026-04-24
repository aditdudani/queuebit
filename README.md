# QueueBit

QueueBit is a hardware dispatcher for online syndrome routing in surface-code decoding pipelines. It accepts syndrome coordinates, checks them against the active lock state, and either issues them to a worker or stalls them until the hazard clears.

QueueBit is not a full decoder. The current project studies the dispatch problem itself: whether hazard-aware routing is necessary, how the dispatcher behaves under different worker latencies and offered loads, and how the design scales from a smaller d=11 case to a larger d=23 case.

## Current State

The current deliverable package is in `deliverables/`.

That package contains:
- the finalized report draft in markdown form
- d=11 sweep results
- d=23 sweep results
- d=11 post-route synthesis results
- d=23 post-route synthesis results
- paper figures and summary CSV files

## Main Findings

The experimental evidence supports the following claims:

1. Hazard checking is necessary. The naive baseline produces 138 unsafe concurrent pairs out of 439 concurrent pairs, which is a 31.4% violation rate.
2. Both d=11 and d=23 show a source-limited regime at low offered load and a saturated regime at higher offered load.
3. Worker latency matters. Larger `K` increases runtime and stall pressure.
4. The d=23 case is the stronger scale-up result. It shows substantially more blocked hazard events than d=11 under load.
5. Both d=11 and d=23 meet the applied 100 MHz timing target on XC7Z020.

## Synthesis Summary

### d=11

- target clock: 100 MHz
- setup slack: +0.424 ns
- LUTs: 2804 / 53200 = 5.27%
- FFs: 928 / 106400 = 0.87%
- total estimated power: 115.0 mW

### d=23

- target clock: 100 MHz
- setup slack: +0.163 ns
- LUTs: 12321 / 53200 = 23.16%
- FFs: 2797 / 106400 = 2.63%
- total estimated power: 145.0 mW

These are post-route implementation results under the current internal design constraint set. They are not yet a full board-level I/O timing study.

## Repository Structure

```text
queuebit/
|-- rtl/              # RTL modules
|-- tb/               # simulation testbenches
|-- verification/     # parsing and verification scripts
|-- batch_run/        # Vivado automation, sweeps, synthesis reports
|-- constraints/      # XDC constraints
`-- deliverables/     # current deliverable package
```

## Deliverable Package

### `deliverables/`

This is the current package to use for writing and submission. It contains:
- `README.md`: package guide
- `QUEUEBIT_REPORT_DRAFT.md`: finalized report draft
- `d11/`: d=11 sweep and synthesis artifacts
- `d23/`: d=23 sweep and synthesis artifacts
- `figures/`: paper figures and summary CSV data

## Reproducing the Current Results

### Basic testing

From the repository root:

```bash
./build.sh test-integration
./build.sh test-integration-naive
```

### d=11 sweep

From the Vivado Tcl console:

```tcl
cd D:/College/4-2/SoP2/Code/queuebit/batch_run
source batch_simulate.tcl
```

Then extract:

```powershell
cd D:\College\4-2\SoP2\Code\queuebit\batch_run
python extract_metrics.py
```

### d=23 sweep

From the Vivado Tcl console:

```tcl
cd D:/College/4-2/SoP2/Code/queuebit/batch_run
source batch_simulate_d23.tcl
```

Then extract:

```powershell
cd D:\College\4-2\SoP2\Code\queuebit
python verification\extract_d23_k_sweep.py
```

### Synthesis

For d=11:

```tcl
cd D:/College/4-2/SoP2/Code/queuebit/batch_run
source synthesize.tcl
```

For d=23:

```tcl
cd D:/College/4-2/SoP2/Code/queuebit/batch_run
source synthesize_d23.tcl
```

### Figure generation

The paper figure script is:

```text
batch_run/generate_publication_figures.py
```

It requires a Python environment with `matplotlib` installed.

## Recommended Starting Points

For the current submission package, start with:

- `deliverables/README.md`
- `deliverables/QUEUEBIT_REPORT_DRAFT.md`
