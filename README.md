# QueueBit: Dynamic Syndrome Dispatcher for Quantum Error Correction

Hardware-accelerated syndrome routing pipeline for surface code quantum error correction (d=11 code distance on 21×23 lattice).

**Status**: ✅ Phase 3 Complete (Integration Testing) | ⏳ Phase 4 In Progress (Synthesis & Performance)

## Quick Links

- **📊 Full Project Status**: See [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md) for comprehensive architecture, detailed task list, and Phase 4 deliverables
- **🧪 Phase 3 Test Results**: See [`docs/PHASE3_TEST_SUMMARY.md`](docs/PHASE3_TEST_SUMMARY.md) for debugging history and all test results
- **📋 Project Memory**: See [`docs/MEMORY.md`](docs/MEMORY.md) for key design decisions and project notes

## What's Working ✅

| Component | Tests | Status |
|-----------|-------|--------|
| Syndrome FIFO (`rtl/syndrome_fifo.sv`) | 26/26 passing | ✅ Phase 2 Complete |
| Tracking Matrix (`rtl/tracking_matrix.sv`) | 22/22 passing | ✅ Phase 2 Complete |
| Dispatcher FSM (`rtl/dispatcher_fsm.sv`) | Integration test | ✅ Phase 3 Complete |
| Top-level Dispatcher (`rtl/dispatcher_top.sv`) | 221 syndromes | ✅ Phase 3 Complete |
| **Collision Verification** | 0 violations | ✅ Phase 3 Complete |

## Project Structure

```
queuebit/
├── rtl/                          # RTL source (5 modules)
│   ├── dispatcher_pkg.sv         # Parameters & types
│   ├── syndrome_fifo.sv          # FIFO queue
│   ├── tracking_matrix.sv        # 2D collision detection
│   ├── dispatcher_fsm.sv         # 4-state control FSM
│   └── dispatcher_top.sv         # Top-level integration
├── tb/                           # Testbenches (3 tests)
│   ├── tb_syndrome_fifo.sv       # 26 tests
│   ├── tb_tracking_matrix.sv     # 22 tests
│   └── tb_dispatcher_integration.sv # 221-syndrome test
├── verification/                 # Test infrastructure
│   ├── generate_stim_data.py     # Stimulus generator
│   ├── verify_collisions.py      # Collision verifier
│   └── stim_errors.txt           # 221 syndrome pairs
├── docs/                         # Documentation
│   ├── PROJECT_STATUS.md         # Comprehensive status (THIS - detailed reference)
│   ├── PHASE3_TEST_SUMMARY.md    # Test results & debugging history
│   ├── MEMORY.md                 # Project notes
│   └── COMPREHENSIVE_AUDIT_REPORT.md # Academic validation
├── references/                   # Academic papers
│   └── report.md                 # Research report
├── build.sh                      # Build automation
└── Makefile                      # Alternative build (requires GNU Make)
```

## Build & Test

### Quick Start

```bash
# Run all tests with iverilog (default, ~30 seconds)
./build.sh

# Run all tests with Xilinx xsim
./build.sh test-xsim

# Run with both simulators
./build.sh test-all

# Clean all build artifacts
./build.sh clean
```

### Individual Components

```bash
# FIFO only (iverilog)
./build.sh iverilog-fifo

# Matrix only (xsim)
./build.sh xsim-matrix

# Integration test (full pipeline)
./build.sh test-integration
```

### Using Makefile (if GNU Make installed)

```bash
make              # Run all tests
make test-xsim    # Run with xsim
make clean        # Remove artifacts
make help         # Show all targets
```

## Test Results Summary

✅ **Phase 3 (2026-04-06) - All Tests PASSING**

```
Unit Tests:          48/48 PASS (26 FIFO + 22 Matrix)
  ├─ iverilog:       48/48 PASS
  └─ xsim:           48/48 PASS

Integration Test:    221 syndromes → 0 collisions PASS
  ├─ Syndromes loaded:      221
  ├─ Syndromes issued:      190
  ├─ Spatial collisions:    0 ✅
  └─ All workers complete:  Yes ✅

FSM Fix Applied:     2-cycle release delay counter
  └─ Prevents timing race between FSM and matrix
```

For detailed test breakdown and debugging history, see [`docs/PHASE3_TEST_SUMMARY.md`](docs/PHASE3_TEST_SUMMARY.md).

## System Requirements

- **Required**: Python 3.8+ (for stimulus generation & verification)
- **For iverilog tests**: `iverilog` (open-source Verilog simulator)
- **For xsim tests**: Xilinx Vivado 2025.1 with xsim
- **For synthesis (Phase 4)**: Xilinx Vivado 2025.1

## Key Features

- **O(1) Worker Pool**: Centralized dispatch to fixed 4-worker pool (vs. O(d²) centralized alternatives)
- **Spatial Collision Detection**: 3×3 Chebyshev locks prevent concurrent syndrome dispatch conflicts
- **FSM Control**: 4-state pipeline (IDLE → HAZARD_CHK → ISSUE → STALL) with proper stall/release coordination
- **Dual Simulator Support**: Works with both open-source iverilog and proprietary Xilinx xsim
- **Comprehensive Testing**: 48 unit tests + 1 integration test with 221 syndrome stimulus

## Architecture Overview

```
Quantum Circuit (Syndrome Extraction)
    ↓
[FIFO Buffer] ← 221 syndrome pairs
    ↓
[Dispatch FSM] ← Hazard checking with stall logic
    ↓
[Tracking Matrix] ← Collision detection (3×3 Chebyshev locks)
    ↓
[4-Worker Pool] ← Independent processing units
    ↓
[Decoder Output] ← Cluster estimates
```

## Next Steps (Phase 4)

1. **Synthesize to FPGA** (Xilinx Vivado) → Measure Fmax
2. **Collect Performance Data** → Stall vs. load curves (PRIMARY deliverable)
3. **Generate Final Report** → Results and conclusions

See [`docs/PROJECT_STATUS.md` § 6](docs/PROJECT_STATUS.md#6-next-steps-priority-order---phase-4-in-progress) for detailed Phase 4 plan.

## Documentation

- **Architecture & Design**: [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md) (comprehensive 1000+ line reference)
- **Test Results**: [`docs/PHASE3_TEST_SUMMARY.md`](docs/PHASE3_TEST_SUMMARY.md) (debugging history + test outputs)
- **Research Report**: [`references/report.md`](references/report.md) (academic background & methodology)
- **Project Notes**: [`docs/MEMORY.md`](docs/MEMORY.md) (key decisions & parameters)

## File Conventions

| Type | Location | Pattern |
|------|----------|---------|
| RTL | `rtl/` | `*.sv` |
| Testbenches | `tb/` | `tb_*.sv` |
| Build Output | `build/` (gitignored) | — |
| Verification Scripts | `verification/` | `*.py`, `*.txt` |
| Documentation | `docs/` | `*.md` |

## Notes

- All build artifacts are isolated in the `build/` directory (not in git)
- Run `./build.sh clean` to remove all generated files
- Both `build.sh` (POSIX bash) and `Makefile` (if available) support the same targets
- Testbenches include assertions to catch protocol violations

## Authors

**Student**: Adit Dudani (2022B5A30533P)
**Advisors**: Prof. Jayendra N. Bandyopadhyay (Physics), Prof. Govind Prasad (EEE)
**Course**: PHY F366 - Study-Oriented Project, BITS Pilani

---

**Last Updated**: 2026-04-06
**Status**: Phase 3 Complete (Integration PASSING) | Phase 4 In Progress (Synthesis Pending)
