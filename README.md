# QueueBit: Hardware-Accelerated Syndrome Dispatcher for Quantum Error Correction

A synthesizable RTL dispatcher for real-time, collision-free syndrome routing in surface code quantum error correction decoders.

## What It Does

QueueBit solves the **syndrome dispatch bottleneck** in quantum error correction: given a stream of syndrome coordinates (error locations) and a pool of parallel worker processors, route each syndrome to an available worker while **preventing spatial collisions** that could cause decoding errors.

The dispatcher operates as the control plane between syndrome extraction and decoding workers, enforcing mutual exclusion via static 3×3 spatial locks. Designed for integration into larger quantum error correction systems on commodity FPGAs.

## Key Results

| Metric | Value | Status |
|--------|-------|--------|
| **Synthesis Frequency** | 127.5 MHz | Zynq-7020 (28nm), 27.5% above 100 MHz target |
| **Resource Utilization** | 5.30% LUTs, 0.86% FFs | Lightweight footprint |
| **Correctness** | 0 spatial collisions | 221-syndrome end-to-end verification |
| **Performance** | 52–89% stall rate | K-sweep across 4 worker latency values (5–20 cycles) |
| **Verification** | 48/48 unit tests | 100% pass (iverilog + xsim) |

**Full results, methodology, and analysis**: See [`deliverables/FINAL_REPORT.md`](deliverables/FINAL_REPORT.md) (6500+ words, 17 citations, publication-ready)

## Quick Start

### Build & Run Tests

```bash
# Run all tests (iverilog, ~30 seconds)
./build.sh

# Run with Xilinx xsim (requires Vivado 2025.1)
./build.sh test-xsim

# Clean all build artifacts
./build.sh clean

# View all targets
./build.sh help
```

All testbenches pass on both iverilog and xsim. Unit tests verify FIFO, collision matrix, and full dispatcher integration.

## Project Structure

```
queuebit/
├── rtl/                    # Production RTL (5 modules, 567 LOC)
│   ├── dispatcher_pkg.sv   # Parameters & types
│   ├── syndrome_fifo.sv    # FIFO buffer (32 entries)
│   ├── tracking_matrix.sv  # 2D collision detection (23×21 grid)
│   ├── dispatcher_fsm.sv   # 4-state control FSM (IDLE → HAZARD_CHK → ISSUE → STALL)
│   └── dispatcher_top.sv   # Top-level integration
│
├── tb/                     # Testbenches (3 modules, 722 LOC)
│   ├── tb_syndrome_fifo.sv  # 26 unit tests
│   ├── tb_tracking_matrix.sv # 22 unit tests
│   └── tb_dispatcher_integration.sv # 221-syndrome end-to-end test (parameterized K-sweep)
│
├── verification/           # Test infrastructure
│   ├── generate_stim_data.py   # Stimulus generator
│   ├── verify_collisions.py    # Collision verifier
│   └── stim_errors.txt         # 221 syndrome pairs
│
├── batch_run/              # Phase 4: Batch simulation & metrics
│   ├── batch_simulate.tcl  # Vivado batch automation
│   ├── extract_metrics.py  # Metrics parsing script
│   ├── plot_results.py     # Matplotlib visualization
│   └── queuebit_vivado/    # Vivado project (synthesis state)
│
├── deliverables/           # Phase 4 Results ⭐
│   ├── FINAL_REPORT.md     # Academic report (START HERE)
│   ├── stall_vs_load_sweep.png # Figure 1 (K-sweep curves)
│   ├── worker_utilization.png  # Figure 2 (pool utilization)
│   ├── synthesis_fmax.png      # Figure 3 (synthesis metrics)
│   ├── metrics.csv         # Raw data (60 simulations)
│   ├── dispatcher_top_utilization_synth.rpt # Synthesis report
│   └── README.md           # Artifact index
│
├── Makefile & build.sh     # Build automation
└── .gitignore              # Clean repository
```

## Architecture Overview

```
Syndrome Stream → [FIFO] → [Dispatch FSM] → [Tracking Matrix] → [4-Worker Pool]
                            (collision checking + queueing)
```

**Design principles**:
- **O(1) dispatch**: Amortized latency independent of queue depth
- **Collision detection**: Single-cycle combinatorial checks via 2D matrix
- **Mutual exclusion**: Static 3×3 Chebyshev locks (distance ≤ 2)
- **Parametric**: Worker latency K configurable; grid size, FIFO depth parameterized

## System Requirements

**Minimum**:
- Python 3.8+ (optional, for stimulus generation & verification)
- Bash shell (POSIX-compatible)

**For Unit Tests**:
- `iverilog` — Open-source Verilog simulator
- Installation: `apt-get install iverilog` (Ubuntu) or `brew install iverilog` (macOS)

**For xsim Tests & Synthesis**:
- Xilinx Vivado 2025.1 with xsim & synthesis tools
- Free webpack license sufficient for all work
- Target device: Zynq-7020 (ZedBoard or PYNQ board)

## Documentation

| Document | Purpose |
|----------|---------|
| **[`deliverables/FINAL_REPORT.md`](deliverables/FINAL_REPORT.md)** | **START HERE** — Full academic report with methodology, results, and analysis |
| **[`deliverables/README.md`](deliverables/README.md)** | Artifact index & interpretation guide |

## Reproducibility

All results are reproducible from source code:

1. **Unit tests**: Run `./build.sh` to verify RTL on iverilog/xsim
2. **Integration test**: 221-syndrome end-to-end verification with 0 collisions
3. **Synthesis**: Vivado project in `batch_run/queuebit_vivado/` (xc7z020clg484-1, 100 MHz constraint)
4. **Performance**: K-sweep across latencies 5–20 cycles, injection rates 0.1–2.0 syndromes/cycle
5. **Metrics**: Raw data in `deliverables/metrics.csv` (60 simulations)

## How to Cite

```
QueueBit: A Hardware-Accelerated Syndrome Dispatcher for Real-Time Surface Code Decoding
Author: Adit Dudani (2022B5A30533P)
Advisors: Prof. Jayendra N. Bandyopadhyay, Prof. Govind Prasad
Institution: BITS Pilani, PHY F366 Study-Oriented Project
Year: 2026
```

## References

This work builds on recent advances in hardware-accelerated quantum decoding:

- **Barber et al.** (2023, Nature Electronics): Collision Clustering decoder achieving 400+ MHz on 16nm
- **QUEKUF** (Valentino et al., 2025): FPGA Union-Find decoder with 7.3× speedup
- **Online Union-Find** (Kasamura et al., 2025, IEEE ICCD): Per-syndrome latency characterization (5–20 cycles)

See `deliverables/FINAL_REPORT.md` for full bibliography (17 citations).

## Status

All development, verification, synthesis, and documentation are finalized. The project demonstrates:
- **Correct design**: 48/48 unit tests + 1 integration test passing, 0 spatial collisions
- **Efficient hardware**: Synthesizable to 127.5 MHz on 28nm FPGA with 27.5% timing margin
- **Rigorous analysis**: K-sweep performance characterization with statistical validation
- **Publication quality**: Full academic report with proper citations and comparative analysis

## License & Attribution

**Author**: Adit Dudani (2022B5A30533P)
**Advisors**: Prof. Jayendra N. Bandyopadhyay (Physics), Prof. Govind Prasad (EEE)
**Institution**: BITS Pilani, PHY F366 Study-Oriented Project
**Date**: April 6, 2026

All RTL and testbenches are original work. All external references are properly cited in the final report.

---

**For detailed methodology, results, and analysis, see [`deliverables/FINAL_REPORT.md`](deliverables/FINAL_REPORT.md)**
