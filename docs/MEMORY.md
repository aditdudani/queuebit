# QueueBit Project Memory

## Project Overview
- **Name**: QueueBit (Dynamic Syndrome Dispatcher for Quantum Error Correction)
- **Course**: PHY F366 - Study-Oriented Project, BITS Pilani
- **Code Type**: **Surface Code** (d=11 code distance on 21×23 physical qubit lattice)
- **Status**: Phase 2 Complete (RTL & unit tests), Phase 3 TODO (FSM & integration)
- **Location**: `d:/College/4-2/SoP2/Code/queuebit`

## Architecture Summary
Hardware pipeline for on-the-fly syndrome dispatching in surface code error correction:
1. **Syndrome FIFO** (✓ Done): Buffers incoming syndrome coordinates
2. **Tracking Matrix** (✓ Done): 2D spatial collision detection (d=11 grid: 23×21)
3. **Dispatch FSM** (✗ TODO): Coordinates FIFO→Matrix→Workers with stall logic
4. **Noise Simulator** (✗ Phase 3): Models worker latency (stochastic delays)
   - Phase 3: Use simple fixed latency (K=5 cycles per syndrome)
   - Phase 4: Use stochastic distribution calibrated to QUEKUF framework

## Design Principles
1. **Stateless Worker Model**: Each syndrome is independent task (no historical state)
2. **Online Streaming**: Cycle-by-cycle error processing (no batch accumulation)
3. **O(1) Worker Pool**: Fixed 4-worker pool vs. O(d²) centralized memory
4. **Spatial Locks**: Static 3×3 (Chebyshev ≤2) justified by Union-Find cluster bound

## Test Status
- ✓ FIFO: 26/26 tests passing (dual-pointer, protocol, stress)
- ✓ Matrix: 22/22 tests passing (collisions, boundaries, locks)
- ✓ Both verified on iverilog AND Xilinx xsim
- ✗ Integration tests TODO (221 Stim-generated syndromes loaded, collision check via verify_collisions.py)

## Key Design Decisions
1. **Static 3×3 locks** via Chebyshev distance ≤ 2 (justified by Delfosse & Nickerson Theorem 1)
2. **Single-cycle matrix reads** (combinatorial collision detection)
3. **Atomic lock/release** of entire 3×3 region (mutual exclusion)
4. **Dual simulator support**: iverilog (fast iteration) + xsim (synthesis-aligned)
5. **Out-of-bounds returns 0** (safe boundary handling)

## Build System
- `Makefile` and `build.sh` both work (make may not be installed)
- All artifacts isolated in `build/` (not in root)
- `.gitignore` configured for xsim/iverilog/Vivado temp files
- Commands: `./build.sh test` (iverilog) or `./build.sh test-xsim` (xsim)

## Critical Next Steps (Priority Order)
1. **Design FSM state machine** (IDLE→FETCH→HAZARD_CHK→ISSUE→STALL with STALL→HAZARD_CHK re-evaluation) → `rtl/dispatcher_fsm.sv`
2. **Create top-level integration** → `rtl/dispatcher_top.sv`
3. **Build integration testbench** with Stim stimulus → `tb/tb_dispatcher_integration.sv`
4. **Run collision verification** using `verify_collisions.py` on dispatch logs
5. **Measure PRIMARY deliverable**: Stall-rate graph (Pipeline Stalls vs. Error Injection Rate)
6. **Synthesize to FPGA** and extract Fmax (Phase 4)

## File Structure
| Type | Key Files |
|------|-----------|
| RTL | `rtl/dispatcher_pkg.sv`, `syndrome_fifo.sv`, `tracking_matrix.sv` |
| TB | `tb/tb_syndrome_fifo.sv`, `tb_tracking_matrix.sv` |
| Verify | `verification/{generate_stim_data.py, verify_collisions.py, stim_errors.txt}` |
| Build | `Makefile`, `build.sh`, `.gitignore` |
| Docs | `README.md`, `PROJECT_STATUS.md`, `COMPREHENSIVE_AUDIT_REPORT.md`, `references/report.md` |

## Parameters (from dispatcher_pkg.sv)
- Code distance: d=11
- Grid: 21×23 (X=width×Y=height)
- FIFO depth: 32 entries
- Workers: 4 (stateless model)
- Coord width: 5 bits (clipped to [0,22])
- FSM states: 5 (IDLE, FETCH, HAZARD_CHK, ISSUE, STALL)
- Noise model: p=0.001 (QUEKUF-calibrated)
- Stimulus: 221 syndromes from Stim library

## Git Status
- Branch: `main` (clean, no uncommitted changes)
- Recent commits: Initial setup + verification infrastructure + Phase 2 RTL
- No PRs or active branches

## Known Limitations & Opportunities
- Static locks may over-allocate under clustered errors (relax in future)
- No formal verification (SVA properties could strengthen design)
- Multi-round cluster continuity not supported (single-round design, deferred to Phase 5+)
- Async FIFO needs CDC synchronizers if crossing clock domains in deployment

## Resources Referenced
- Stim library for quantum circuit simulation (221 pre-generated syndromes)
- Xilinx Vivado 2025.1 for synthesis
- iverilog for quick simulation
- Academic papers:
  - Midsem Report (QueueBit design)
  - Delfosse & Nickerson (Union-Find, Theorem 1 on cluster diameter)
  - QUEKUF (Valentino et al., centralized controller architecture)
  - Kasamura et al. (Online Surface Code Decoder)
  - Barber et al. (Real-time decoder, Nature Electronics)

## Audit Status (2026-04-05)
- ✅ Comprehensive audit conducted against all 5 academic PDFs
- ✅ All core parameters verified correct
- ✅ 5 gaps identified and fixed:
  1. Noise Simulator description added
  2. 3×3 lock justification with theorem citation added
  3. Explicit "Surface Code" statement added
  4. Worker latency model (K=5 cycles) for Phase 3 specified
  5. Stall-rate graph marked as PRIMARY deliverable
- ✅ Zero critical errors found
- See: `docs/COMPREHENSIVE_AUDIT_REPORT.md` for full cross-reference

