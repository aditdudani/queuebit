# QueueBit Project Memory

## Project Overview
- **Name**: QueueBit (Dynamic Syndrome Dispatcher for Quantum Error Correction)
- **Course**: PHY F366 - Study-Oriented Project, BITS Pilani
- **Code Type**: **Surface Code** (d=11 code distance on 21×23 physical qubit lattice)
- **Status**: ✅ Phase 3 Complete (FSM & integration testbench working), Phase 4 TODO (synthesis & results)
- **Location**: `d:/College/4-2/SoP2/Code/queuebit`

## Architecture Summary
Hardware pipeline for on-the-fly syndrome dispatching in surface code error correction:
1. **Syndrome FIFO** (✓ Done): Buffers incoming syndrome coordinates
2. **Tracking Matrix** (✓ Done): 2D spatial collision detection (d=11 grid: 23×21)
3. **Dispatch FSM** (✓ Done): Coordinates FIFO→Matrix→Workers with stall logic
4. **Top-Level Dispatcher** (✓ Done): Integrates FIFO + Matrix + FSM with per-worker tracking
5. **Integration Testbench** (✓ Done): 221-syndrome stimulus + K=5 latency model
6. **Noise Simulator** (✓ Phase 3 Complete): Fixed latency (K=5 cycles per syndrome)

## Design Principles
1. **Stateless Worker Model**: Each syndrome is independent task (no historical state)
2. **Online Streaming**: Cycle-by-cycle error processing (no batch accumulation)
3. **O(1) Worker Pool**: Fixed 4-worker pool vs. O(d²) centralized memory
4. **Spatial Locks**: Static 3×3 (Chebyshev ≤2) justified by Union-Find cluster bound

## Test Status
- ✓ FIFO: 26/26 tests passing (dual-pointer, protocol, stress)
- ✓ Matrix: 22/22 tests passing (collisions, boundaries, locks)
- ✓ Both verified on iverilog AND Xilinx xsim
- ✓ **Integration testbench: PASSING** (221 syndromes processed, 0 collisions detected, all workers complete)

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

## Critical Next Steps (Priority Order - Phase 4)
1. ✅ **Integration test with 221 syndromes** (COMPLETED 2026-04-06) → verify_collisions.py confirms 0 collisions
2. **Synthesize to FPGA** (Xilinx Vivado) → Measure Fmax and resource utilization
3. **Measure performance metrics** → Stall rates, dispatch latency, efficiency (cycles/syndrome)
4. **Generate final report** with synthesis results and performance analysis (PRIMARY deliverable)

## File Structure
| Type | Key Files |
|------|-----------|
| RTL | `rtl/dispatcher_pkg.sv`, `syndrome_fifo.sv`, `tracking_matrix.sv`, `dispatcher_fsm.sv`, `dispatcher_top.sv` |
| TB | `tb/tb_syndrome_fifo.sv`, `tb_tracking_matrix.sv`, `tb_dispatcher_integration.sv` |
| Verify | `verification/{generate_stim_data.py, verify_collisions.py, stim_errors.txt}` |
| Build | `Makefile`, `build.sh`, `.gitignore` |
| Docs | `README.md`, `PROJECT_STATUS.md`, `PHASE3_TEST_SUMMARY.md`, `COMPREHENSIVE_AUDIT_REPORT.md`, `references/report.md` |

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

## Phase 3 Fix (2026-04-06) ✅
**FSM Deadlock Root Cause & Solution**:
- **Problem**: FSM re-checked collision before matrix release propagated through sequential logic
- **Root Cause**: Combinatorial state transitions were too fast for sequential release to complete
- **Solution**: Added 2-cycle release_wait_counter in STALL state (rtl/dispatcher_fsm.sv lines 41-46, 83-98, 165-179)
- **Result**: Integration test now completes successfully with 0 spatial collisions detected
- **Evidence**: dispatch_log.txt shows 4 LOCK/4 RELEASE events with perfect ordering

## Audit Status (2026-04-05 → 2026-04-06)
- ✅ Comprehensive audit conducted against all 5 academic PDFs
- ✅ All core parameters verified correct
- ✅ 5 gaps identified and fixed (see COMPREHENSIVE_AUDIT_REPORT.md)
- ✅ Phase 3 Integration Test: PASSING (2026-04-06)
  - FSM deadlock fixed with release delay counter
  - 221 syndromes processed end-to-end
  - 0 spatial collisions detected
  - All workers complete successfully
- ✅ Zero critical errors in RTL design
- See: `docs/COMPREHENSIVE_AUDIT_REPORT.md` for full cross-reference and `PHASE3_TEST_SUMMARY.md` for test results

