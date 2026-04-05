# QueueBit: Project Status & Development Plan

**Project**: Dynamic Syndrome Dispatcher for Quantum Error Correction
**Course**: PHY F366 - Study-Oriented Project (BITS Pilani)
**Author**: Adit Dudani (2022B5A30533P)
**Faculty Advisors**: Prof. Jayendra N. Bandyopadhyay (Physics), Prof. Govind Prasad (EEE)
**Last Updated**: 2026-04-05

---

## 1. EXECUTIVE SUMMARY

**QueueBit** is a hardware-accelerated syndrome dispatcher for surface code quantum error correction, designed to reduce the computational bottleneck in online decoding. The project is **Phase 2 Complete, Phase 3 In Progress**.

### Current State
- ✓ **Phase 1 & 2**: Core RTL modules implemented and fully tested
  - Syndrome FIFO queue (26/26 tests passing)
  - Topological anyon tracking matrix (22/22 tests passing)
- ✗ **Phase 3**: Dispatcher FSM and integration tests not yet started
- ✗ **Phase 4**: Synthesis, performance analysis, and final report pending

### Key Metrics
| Metric | Value | Status |
|--------|-------|--------|
| Unit Tests Passing | 48/48 | ✓ Complete |
| RTL Modules | 2/4 | ✓ Phase 2 Done |
| Simulators Supported | 2 (iverilog, xsim) | ✓ Complete |
| Build Automation | Makefile + build.sh | ✓ Complete |
| Documentation | Academic report + README | ✓ Complete |
| Integration Tests | 0 | ✗ Blocked on FSM |
| Synthesis Results | — | ✗ Not Started |

---

## 2. PROJECT ARCHITECTURE OVERVIEW

### The Dynamic Syndrome Dispatcher Pipeline (Surface Code Implementation)

This architecture is designed for **surface code quantum error correction** with **d=11 code distance**, operating on a 21×23 physical qubit lattice. It routes a continuous stream of syndrome measurements to a centralized 4-worker pool while preventing spatial collisions.

```
Quantum Circuit (Surface Code d=11)
      ↓
Syndrome Extraction (measurement round cycle)
      ↓
[FIFO Queue] ← Syndrome Ingestion (continuous stream)
      ↓
[FSM + Dispatch Logic] ← Hazard Checking & Stall Control (PHASE 3)
      ↓ (candidate syndromes, time-muxed)
[4× Worker Pool] ← Processing (latency modeled stochastically)
      ↓ (decoded cluster estimates)
[Noise Simulator] ← Latency Distribution (QUEKUF-calibrated p=0.001)
```

### Phase 2 Completed Modules

#### 2A. Syndrome FIFO (`rtl/syndrome_fifo.sv`)
**Purpose**: Buffer incoming syndrome coordinates from quantum measurement
**Type**: Asynchronous FIFO (dual clock domain capable)

| Aspect | Detail |
|--------|--------|
| Depth | 32 (configurable) |
| Data Format | 2 × 5-bit coordinates (X, Y) |
| Interface | Valid-Ready handshake (AXI-lite compatible) |
| Read Latency | 1 cycle combinatorial |
| Write Latency | 1 cycle synchronous |
| Status Signals | empty, full, count |
| Test Coverage | 26/26 tests (boundary, protocol, stress) |

**Handshake Protocol**:
```
Write:  wr_valid & wr_ready → data committed on clock
Read:   rd_valid & rd_ready → data consumed on clock
Simultaneous R/W: Possible (supports pipelined operation)
Full/Empty: MSB of pointer comparison
```

---

#### 2B. Tracking Matrix (`rtl/tracking_matrix.sv`)
**Purpose**: Track spatial allocations to prevent collision-based dispatch errors
**Type**: 2D register array with spatial collision detection

| Aspect | Detail |
|--------|--------|
| Grid Size | 23 rows × 21 columns (matches d=11 surface code) |
| Memory | 483 bits (23 × 21 single-bit storage) |
| Read Mode | Combinatorial (single-cycle collision detection) |
| Write Mode | Synchronous (atomic 3×3 lock/release) |
| Collision Distance | Chebyshev (L∞) distance ≤ 2 cells (9-cell neighborhood) |
| Output | collision signal (1 = workspace occupied, 0 = free) |
| Boundary Handling | Out-of-bounds cells return 0 (safe) |
| Test Coverage | 22/22 tests (corners, edges, simultaneous ops) |

**Spatial Lock Semantics**:
```
Lock (coord_x, coord_y):
  Set all 9 cells in 3×3 neighborhood to 1
  [region centered at (coord_x, coord_y)]

Release (coord_x, coord_y):
  Clear all 9 cells in 3×3 neighborhood to 0

Collision Query (coord_x, coord_y):
  Return OR of all 9 neighborhood cells
  Detects if any prior lock within L∞ distance ≤ 2
```

---

#### 2C. Dispatcher Package (`rtl/dispatcher_pkg.sv`)
**Purpose**: Centralized parameter definitions and data type declarations

| Component | Value / Definition |
|-----------|-------------------|
| Code Distance (d) | 11 |
| Grid Dimensions | 21 × 23 (X × Y) |
| FIFO Depth | 32 entries |
| Worker Count | 4 processing units |
| Coordinate Width | 5 bits (supports 0–31, but clipped to 0–22) |
| FSM States | IDLE, FETCH, HAZARD_CHK, ISSUE, STALL (5 states) |
| Coordinate Type | `coord_t` struct with x, y fields |

---

#### 2D. Noise Simulator (Worker Latency Model)
**Purpose**: Model realistic quantum syndrome processing delays

**Role in Architecture**:
The 4th major architectural block (not yet implemented in Phase 2). Because the design focuses on *control-plane routing logic* rather than arithmetic cluster-growth calculations, worker processing is abstracted via a stochastic latency model rather than synthesized as full decoding logic.

**Implementation Strategy**:
- **Phase 3** (Integration Testing): Use simple fixed latency (e.g., 5 cycles per syndrome)
- **Phase 4** (Stress Testing): Sample from `QUEKUF`-calibrated latency distribution at p=0.001
- **Calibration Source**: Empirical clock-cycle histograms from QUEKUF paper (Federico Valentino et al., Section 5.4)

**Why This Matters**:
- Ensures simulated worker contention reflects realistic quantum noise (p=0.001 is subcritical)
- Allows measurement of stall rates under realistic load
- Avoids over-optimism from combinatorial worker models

**Reference**: Midsem Report, Section 3 ("The Noise Simulator")

---

### Key Design Principle: Stateless Worker Model

This architecture employs a **stateless worker model**: each dispatched syndrome is treated as an independent computational task. Workers do not maintain historical cluster state or temporal memory between assignments. This simplification:
- Reduces FSM complexity (no state persistence across workers)
- Allows parallel processing without synchronization
- Defers multi-round cluster continuity to future work (Phase 5+)

**Reference**: Midsem Report, Section 3 and 5

---

#### Justification for 3×3 Lock Size

The choice of a 3×3 neighborhood (Chebyshev distance ≤ 2) is mathematically justified by **Theorem 1 of Delfosse and Nickerson** (Reference [2] in Midsem report):

**Theorem Statement**: The diameter of the largest cluster produced by the Union-Find decoder is bounded by 2s edges, where s = number of physical errors in a syndrome round.

**At Physical Error Rate p = 0.001**:
- Expected errors per round: E[s] ≈ q·p = 2·d²·p ≈ 2·121·0.001 ≈ 0.24 errors
- Maximum expected cluster diameter: 2·s ≈ 0–2 edges
- A 3×3 lock (covering up to Chebyshev distance ≤ 2) conservatively encloses all typical clusters
- **Benefit**: Avoids variable-sized hardware locks, which would introduce combinatorial routing delays

**Conservative Bound**: This design is under-conservative; most clusters will be substantially smaller than 3×3, providing robustness against error bursts.

**References**:
- Midsem Report, Section 5 ("Scope and Limitations")
- Delfosse & Nickerson (2021), arXiv:1709.06218, Theorem 1

---

## 3. PHASES & COMPLETION STATUS

### Phase 1: Problem Formulation & Planning ✓
| Task | Status | Date |
|------|--------|------|
| Literature review | ✓ Complete | 2026-03-19 |
| Problem statement | ✓ Complete | 2026-03-19 |
| Architecture design | ✓ Complete | 2026-03-19 |
| Initial git setup | ✓ Complete | 2026-03-19 |

**Deliverables**: Academic report (`references/report.md`), project rationale

---

### Phase 2: RTL Implementation of Syndrome Queue & Matrix ✓
| Task | Status | Completion | Tests |
|------|--------|------------|-------|
| FIFO RTL design | ✓ Complete | 2026-03-20 | 26/26 |
| FIFO testbench | ✓ Complete | 2026-03-20 | — |
| Matrix RTL design | ✓ Complete | 2026-03-20 | 22/22 |
| Matrix testbench | ✓ Complete | 2026-03-20 | — |
| Build automation | ✓ Complete | 2026-04-05 | — |
| Verification infrastructure | ✓ Complete | 2026-03-19 | — |

**Deliverables**:
- Fully tested FIFO and Matrix modules
- Comprehensive testbenches with 48/48 passing tests
- Makefile and build.sh for dual-simulator support
- Python stimulus generation and collision verification scripts

**Key Achievement**: Confirmed zero test failures on both iverilog and Xilinx xsim.

---

### Phase 3: Dispatcher FSM & Integration Testing ✗ (NEXT)
| Task | Status | Priority | Estimated Scope |
|------|--------|----------|-----------------|
| Design FSM state machine | — | **HIGH** | 3–5 FFs, 4 states |
| Implement dispatch logic | — | **HIGH** | Hazard check + stall logic |
| Create integration testbench | — | **HIGH** | Syndrome pipeline + collision rate |
| Load Stim stimulus data | — | **MEDIUM** | 221 error coordinates → FIFO |
| Run collision verification | — | **MEDIUM** | `verify_collisions.py` on logs |
| Measure stall rates | — | **MEDIUM** | Statistical analysis vs. error rate |

**Critical Unknowns**:
- How often does the dispatch FSM stall due to matrix conflicts?
- What is the impact of the static 3×3 lock on throughput?
- Does the 4-worker model saturate the FIFO?

---

### Phase 4: Synthesis & Final Results ✗ (LATER)
| Task | Status | Priority | Deliverables |
|------|--------|----------|---------------|
| RTL-to-gates (Xilinx) | — | HIGH | Netlist, timing constraints |
| Fmax measurement | — | HIGH | Maximum operating frequency |
| Area & power analysis | — | **MEDIUM** | LUT/FF/BRAM/power estimates |
| Stall vs. error rate graph | — | **MEDIUM** | Performance curve for report |
| Final project report | — | **MEDIUM** | Results, conclusions, limitations |

**Prerequisite**: Completion of Phase 3 (FSM and integration tests must pass)

---

### Phase 5: Optional Extensions (Post-Deadline)
| Enhancement | Scope | Value |
|-------------|-------|-------|
| Multi-round cluster continuity | Relax 3×3 lock shape | Better throughput |
| Dynamic lock sizing | Adaptive based on error model | Theoretical interest |
| Formal verification (SVA) | Mutual exclusion proofs | Academic rigor |
| HLS implementation | Abstract workers in C++ | Alternative design space |

---

## 4. DETAILED COMPONENT STATUS

### 4.1 RTL Modules

#### Syndrome FIFO (`rtl/syndrome_fifo.sv`)
**Lines of Code**: 108
**Test Status**: 26/26 passing ✓

**Implementation Details**:
- Dual-pointer architecture (wr_ptr, rd_ptr) with MSB for full/empty detection
- Queue storage: `fifo[i] = {x_coord, y_coord}` (10 bits per entry)
- Empty condition: `wr_ptr == rd_ptr`
- Full condition: `wr_ptr[DEPTH_BITS] != rd_ptr[DEPTH_BITS] && wr_ptr[DEPTH_BITS-1:0] == rd_ptr[DEPTH_BITS-1:0]`
- Count computation: `count = (wr_ptr - rd_ptr) % DEPTH` with correct MSB handling
- Assertions: Prevent protocol violations (write when full, read when empty)

**Tested Scenarios**:
1. Reset state verification (all flags correct)
2. Single write/read with data integrity
3. Fill to capacity (DEPTH=8)
4. Empty completely (FIFO order validation)
5. Simultaneous read-write (count stability under pipelined access)

**Known Limitations**:
- No metastability handling (assumes synchronous clock; async reset OK)
- For true dual-clock-domain use, add CDC synchronizers between clock domains
- Not tested under > 4 ns clock period (5 GHz)

---

#### Tracking Matrix (`rtl/tracking_matrix.sv`)
**Lines of Code**: 145
**Test Status**: 22/22 passing ✓

**Implementation Details**:
- 2D array: `matrix[y][x]` with 23×21 = 483 bits total
- Read path (combinatorial):
  ```verilog
  neighborhood[0:8] = {
    matrix[y-1][x-1], matrix[y-1][x], matrix[y-1][x+1],
    matrix[y  ][x-1], matrix[y  ][x], matrix[y  ][x+1],
    matrix[y+1][x-1], matrix[y+1][x], matrix[y+1][x+1]
  }
  collision = |neighborhood  // OR all 9 bits
  ```
- Out-of-bounds handling: Return '0' for cells outside [0,22] × [0,20]
- Write path (synchronous, CLK edge):
  - Lock: Set 3×3 region to all 1s (atomic)
  - Release: Set 3×3 region to all 0s (atomic)
  - Priority: Lock > Release (if both asserted, lock wins)

**Tested Scenarios**:
1. Reset state (all zeros, no collision)
2. Interior lock at (10,10) → 9 cells locked, collision detected
3. Collision distance (L∞ ≤ 2 shows collision, ≥ 3 doesn't)
4. Corner locks (0,0) and (20,22) → boundary masking correct
5. Non-overlapping locks (no false collisions between regions)
6. Out-of-bounds queries (safe return of 0)

**Known Limitations**:
- Static 3×3 locks may be suboptimal for tightly clustered errors
- Single-cycle read latency assumes matrix fits in LUT RAM (true for d=11)
- No read-after-write hazard detection (FSM must handle ordering)

---

#### Dispatcher Package (`rtl/dispatcher_pkg.sv`)
**Lines of Code**: 34
**Test Status**: Compile-time validation only

**Contents**:
```systemverilog
package dispatcher_pkg;
  parameter integer CODE_DIST = 11;
  parameter integer GRID_WIDTH = 21, GRID_HEIGHT = 23;
  parameter integer FIFO_DEPTH = 32;
  parameter integer NUM_WORKERS = 4;
  parameter integer COORD_WIDTH = 5;  // supports [0, 31]

  typedef enum logic [2:0] {
    IDLE, FETCH, HAZARD_CHK, ISSUE, STALL
  } fsm_state_e;

  typedef struct packed {
    logic [COORD_WIDTH-1:0] x, y;
  } coord_t;
endpackage
```

**Usage**: Imported by all modules (`import dispatcher_pkg::*`)

---

### 4.2 Testbenches

#### FIFO Testbench (`tb/tb_syndrome_fifo.sv`)
**Lines of Code**: 178
**Test Count**: 26 (grouped in 5 test phases)

**Test Tree**:
```
tb_syndrome_fifo.v
├── Reset State (4 tests)
│   ├── empty = 1
│   ├── full = 0
│   ├── count = 0
│   └── rd_valid = 0
├── Single Write/Read (6 tests)
│   ├── Write (10, 15)
│   ├── After write: empty = 0
│   ├── Count increments to 1
│   ├── Read returns (10, 15)
│   ├── After read: empty = 1
│   └── Count returns to 0
├── Fill to Capacity (3 tests)
│   ├── Write 8 entries in sequence
│   ├── full = 1
│   └── wr_ready = 0
├── Empty Completely (4 tests)
│   ├── Drain all 8 entries
│   ├── Verify FIFO order (0,1,2...7)
│   ├── empty = 1
│   └── count = 0
└── Simultaneous R/W (1 test)
    └── Full queue: concurrent read & write → count = 2
```

**Helper Tasks**:
- `reset()`: Assert RST for 5 cycles
- `write_coord(x, y)`: Set wr_valid, synchronize with clk, deassert
- `read_coord()`: Set rd_ready, capture output, deassert
- `check(expected, kind)`: Assert condition, report PASS/FAIL

---

#### Matrix Testbench (`tb/tb_tracking_matrix.sv`)
**Lines of Code**: 244
**Test Count**: 22 (grouped in 8 test phases)

**Test Tree**:
```
tb_tracking_matrix.v
├── Reset State (2 tests)
│   ├── All cells clear = 0
│   └── No collision detected
├── Interior Lock (3 tests)
│   ├── Lock at (10, 10)
│   ├── 9 cells locked in 3×3
│   └── Collision detected
├── Collision Boundary Dist=2 (3 tests)
│   ├── Dist 2 in X: collision
│   ├── Dist 2 in Y: collision
│   └── Dist 2 diagonal: collision
├── No Collision Boundary Dist=3 (2 tests)
│   ├── Dist 3 in X: no collision
│   └── Dist 3 in Y: no collision
├── Release Clears 3×3 (2 tests)
│   ├── After release: all cells = 0
│   └── No collision after release
├── Corner Locks (4 tests)
│   ├── Lock at (0, 0): 4 cells locked
│   ├── Lock at (20, 22): 4 cells locked
│   ├── Neighborhood bits correctly masked
│   └── No false cells beyond boundary
├── Non-Overlapping Locks (3 tests)
│   ├── Two locks: 18 cells total
│   ├── Each region shows collision
│   └── Gap between regions: no collision
└── Out-of-Bounds (3 tests)
    ├── Center X > 20: no collision
    ├── Center Y > 22: no collision
    └── Both out-of-bounds: no collision
```

**Helper Tasks**:
- `reset()`: CLK + RST synchronization
- `do_lock(x, y)`: Atomic lock operation
- `do_release(x, y)`: Atomic release operation
- `check_coord(x, y, expected)`: Query collision and verify
- `check(expr, msg)`: Assertion with reporting

---

### 4.3 Verification Infrastructure

#### Stimulus Generation (`verification/generate_stim_data.py`)
**Status**: ✓ Complete and executed

**Purpose**: Generate realistic syndrome coordinates from quantum error model

**Implementation**:
- Circuit: Rotated surface code memory Z (d=11)
- Rounds: 10 measurement cycles
- Error Model: Physical error rate p=0.001
- Output: Detector coordinates (221 valid pairs)

**Generated File**: `verification/stim_errors.txt`
```
0 2
2 4
4 6
...
18 20
```

**Quality Metrics**:
- 10 valid shots (≥2 detector triggers per shot)
- Coordinate range: X ∈ [0,20], Y ∈ [0,22]
- Density: 221 / 483 max capacity ≈ 46%

---

#### Collision Verification (`verification/verify_collisions.py`)
**Status**: ✓ Complete, awaiting integration testbench output

**Purpose**: Verify mutual exclusion in dispatch logs

**Algorithm**:
1. Parse chronological dispatch logs
2. For each cycle, compute active coordinates
3. Check all pairs: distance(c1, c2) > 2?
4. Report violations with cycle # and pairs

**Precondition**: Integration testbench must output dispatch log in format:
```
cycle 0: issued (5,5)
cycle 1: issued (8,8)
cycle 2: issued (3,3)
...
```

**Expected Output**:
```
Checking 221 syndromes...
Collisions found: 0
Mutual exclusion VERIFIED
```

---

### 4.4 Build & Test Automation

#### Makefile (`Makefile`)
**Status**: ✓ Complete (116 lines)

**Targets**:
```makefile
make              # Run FIFO + Matrix with iverilog
make test         # Alias for 'make'
make test-xsim    # Run FIFO + Matrix with xsim
make test-all     # Run with both simulators
make iverilog-fifo    # FIFO only, iverilog
make iverilog-matrix  # Matrix only, iverilog
make xsim-fifo        # FIFO only, xsim
make xsim-matrix      # Matrix only, xsim
make clean        # Remove build/ directory
make help         # Show this help
```

**Build Artifacts**:
- `build/iverilog/tb_fifo.vvp` (26 KB)
- `build/iverilog/tb_matrix.vvp` (69 KB)

---

#### Build Script (`build.sh`)
**Status**: ✓ Complete (174 lines, bash)

**Commands**:
```bash
./build.sh                   # Default: test
./build.sh test              # iverilog tests
./build.sh test-xsim         # xsim tests
./build.sh test-all          # Both simulators
./build.sh iverilog-fifo     # FIFO only
./build.sh xsim-fifo         # FIFO only (xsim)
./build.sh clean             # Remove artifacts
./build.sh help              # Show help
```

**Features**:
- Colored output (GREEN for success, RED for error, YELLOW for info)
- Isolated build directories (no main directory pollution)
- Automatic mkdir creation
- Bash portability (POSIX-compliant)

---

### 4.5 Documentation

#### User Documentation (`README.md`)
**Status**: ✓ Complete (60 lines)

**Contents**:
- Project overview
- Quick-start build instructions
- Test results summary
- Requirements (iverilog, Vivado)
- Project structure diagram

---

#### Academic Report (`references/report.md`)
**Status**: ✓ Complete (~8 KB, comprehensive)

**Sections**:
1. Introduction (surface codes, syndrome extraction bottleneck)
2. Literature Review (Union-Find, distributed decoders, QUEKUF)
3. Problem Statement (spatial collision risk)
4. Methodology (Dynamic Syndrome Dispatcher architecture)
5. Expected Deliverables (stall graph, Fmax, mutual exclusion proof)
6. Scope & Limitations (control-plane only, static locks, single round)
7. References (4 academic papers + Stim library)

**Key Claims**:
- O(1) worker pool amortized latency vs. O(d²) centralized approach
- Mutual exclusion guarantees via static 3×3 locks
- Stall-free operation under realistic noise rates

---

## 5. COMPLETED WORK SUMMARY

### What's Done ✓

#### Code & Design
- ✓ Syndrome ingestion FIFO (dual-pointer, async-ready)
- ✓ Topological tracking matrix (single-cycle collision detection)
- ✓ Dispatcher package (centralized parameters, types)
- ✓ Complete testbenches for both modules
- ✓ Build automation (Makefile + bash script)
- ✓ Verification infrastructure (Stim stimulus generation)

#### Testing & Verification
- ✓ 48/48 unit tests passing (26 FIFO + 22 Matrix)
- ✓ Tested on both iverilog and Xilinx xsim
- ✓ Edge case coverage (corners, boundaries, stress)
- ✓ Protocol correctness (handshakes, reads, writes)

#### Documentation
- ✓ Academic report with problem statement & methodology
- ✓ User README with quick-start guide
- ✓ Inline code comments explaining logic
- ✓ Structured project status (this file)

#### Infrastructure
- ✓ Git repository with clean commit history
- ✓ `.gitignore` configured for build artifacts
- ✓ Directory isolation (no root-directory clutter)

---

## 6. NEXT STEPS (PRIORITY ORDER)

### Immediate (Phase 3 - Dispatcher FSM)

#### 6.1 Design Dispatch FSM State Machine
**Priority**: 🔴 **CRITICAL** (blocks everything else)
**Effort**: 1–2 hours design, 2–3 hours implementation
**Deliverable**: Functional FSM module in `rtl/dispatcher_fsm.sv`

**State Diagram**:
```
IDLE
  ↓ (FIFO not empty)
FETCH ← pop syndrome from FIFO
  ↓
HAZARD_CHK ← query tracking matrix for collision
  ├─ (collision detected) → STALL
  └─ (no collision) → ISSUE
  ↓
ISSUE ← assign to available worker, lock 3×3 region
  ├─ (worker available) → HAZARD_CHK (re-evaluate after any worker completion)
  └─ (all workers busy) → STALL
  ↓
STALL ← wait for 'done' signal from any worker
  ↓
HAZARD_CHK ← RE-EVALUATE grid after worker releases lock
  ↓ (then back to FETCH or IDLE as appropriate)
```

**Critical Control Flow Note**:
When exiting STALL (after any worker finishes), the FSM **MUST** return to HAZARD_CHK to re-evaluate the tracking matrix. This prevents collision hazards when multiple workers hold overlapping 3×3 locks. If a syndrome was blocked because two workers held adjacent regions, and one finishes, the grid state has changed—STALL cannot exit directly to ISSUE without re-checking.

**Signals Needed**:
```systemverilog
// Inputs
logic clk, rst;
logic fifo_rd_valid;        // FIFO has data
logic [9:0] fifo_rd_data;   // syndrome coordinates
logic matrix_collision;      // collision signal from matrix
logic [3:0] worker_ready;   // per-worker availability
logic [3:0] worker_done;    // per-worker completion signals (triggers STALL exit)

// Outputs
logic fifo_rd_ready;        // pop from FIFO
logic matrix_lock_en;       // lock 3×3 region
logic matrix_release_en;    // release 3×3 region
logic [3:0] worker_issue;   // assign to worker[i] (one-hot or bitmask)
logic [9:0] dispatch_coord;         // payload for ALL workers
logic [3:0] dispatch_coord_valid;   // per-worker read-enable
```

**Multi-Worker Dispatch Architecture**:
Since you have 4 independent workers, the `dispatch_coord` signal must be routed correctly:
- **Option A**: Create an array `logic [9:0] dispatch_coord [4]` — one output per worker
- **Option B**: Use a shared `dispatch_coord [9:0]` bus with `dispatch_coord_valid [3:0]` bitmask to select which worker(s) read it

**Option B is recommended** (area-efficient) because:
- Only one syndrome is issued per cycle (no parallel dispatch)
- Workers are assigned sequentially via `worker_issue [3:0]` (one-hot)
- Each worker reads when `worker_issue[i] & dispatch_valid`


**Implementation Strategy**:
1. Define 5-state enum (IDLE, FETCH, HAZARD_CHK, ISSUE, STALL)
2. Create state transition logic based on signals above
3. Synchronize FIFO and matrix outputs with internal pipeline
4. Add assertions for protocol violations

---

#### 6.2 Create Top-Level Dispatcher Module
**Priority**: 🟠 **HIGH**
**Effort**: 1–2 hours (mostly instantiation + wiring)
**Deliverable**: `rtl/dispatcher_top.sv` (integrating FIFO + Matrix + FSM)

**Instantiation Tree**:
```
dispatcher_top
├── syndrome_fifo (FIFO instance)
├── tracking_matrix (Matrix instance)
└── dispatcher_fsm (FSM instance, connects above)
```

**Interface**:
```systemverilog
module dispatcher_top (
  input  logic clk, rst,
  // From syndrome extraction
  input  logic wr_valid,
  input  logic [9:0] wr_data,
  output logic wr_ready,
  // To worker pool
  output logic [3:0] worker_issue,    // one-hot: which worker gets task
  output logic [9:0] issue_coord,     // coordinate broadcast to all workers
  output logic issue_valid,           // strobe: task is valid this cycle
  input  logic [3:0] worker_done      // per-worker completion (triggers re-eval)
);
```

**Wiring Notes**:
- **FIFO ↔ FSM**: `rd_valid`, `rd_data`, `rd_ready` (standard AXI handshake)
- **Matrix ↔ FSM**:
  - Read: `collision = matrix.check_collision(coord_x, coord_y)` (combinatorial)
  - Write: `matrix.lock(coord_x, coord_y)` on ISSUE; `matrix.release(coord_x, coord_y)` on worker_done
- **FSM ↔ Workers**:
  - `worker_issue[i]` = 1 when assigning to worker i
  - `issue_coord` broadcast (all workers latch if `worker_issue[i] & issue_valid`)
  - `worker_done[i]` triggers FSM exit from STALL
- **Feedback**: `wr_ready` pulled from FIFO, can be stalled by FSM (via fifo_rd_ready gating)

---

#### 6.3 Create Integration Testbench
**Priority**: 🔴 **CRITICAL**
**Effort**: 3–4 hours (stimulus loop, logging, verification)
**Deliverable**: `tb/tb_dispatcher_integration.sv` (end-to-end scenario tests)

**Worker Latency Model (Phase 3)**:
For initial integration testing, use a **simple fixed latency model**:
- Each worker takes **K = 5 cycles** to complete syndrome processing
- After K cycles, that worker asserts `worker_done[i]`
- This models typical latency without stochastic overhead
- Allows full collision verification before stress testing with variable delays

**Strategy**:
1. Load stimulus from `stim_errors.txt` (221 error pairs)
2. Inject syndromes into FIFO at realistic rate (e.g., 1 per cycle)
3. Workers operate in parallel with fixed 5-cycle latency
4. FSM stalls when matrix collision detected
5. Compare dispatch log against collision verification rules
6. Measure metrics:
   - Total stalls (cycles in STALL state)
   - Dispatch latency (cycles from queue to issue)
   - Worker utilization (% time busy vs. idle)

**Pseudo-Code**:
```
load stimulus from stim_errors.txt
for each syndrome pair in stimulus:
  write to FIFO
  step FSM
  if issued:
    log "cycle N: issued (x,y)"
    start worker latency counter
  if any worker_done[i]:
    trigger re-evaluation in FSM
  measure stall_count

verify_collisions.py stim_log.txt
report "stalls = X, collisions = 0"
```

**Expected Behavior**:
- No collisions should be logged by verify_collisions.py
- Stall count will indicate how often matrix blocks new syndromes
- Worker utilization should scale with FIFO input rate

---

#### 6.4 Run Full Test Suite
**Priority**: 🟠 **HIGH**
**Effort**: 1 hour (automation)
**Deliverable**: All tests passing (units + integration)

```bash
./build.sh test-all        # iverilog + xsim
```

**Expected Output**:
```
Unit tests (FIFO): 26/26 PASS
Unit tests (Matrix): 22/22 PASS
Integration test: 221 syndromes, 0 collisions, X total stalls PASS
```

---

### Short-Term (Phase 4 - Synthesis & Results)

#### 6.5 Synthesize Design to FPGA
**Priority**: 🟡 **MEDIUM** (after Phase 3 complete)
**Effort**: 2–3 hours (Vivado flow)
**Deliverable**: Netlist, timing report

**Steps**:
1. Create Vivado project targeting Xilinx FPGA (e.g., Zynq-7000)
2. Add all RTL files from `rtl/`
3. Set clock constraint (e.g., 100 MHz)
4. Run synthesis, place & route
5. Extract Fmax from timing report

**Expected Results**:
- Fmax: 300–500 MHz (estimate for d=11)
- LUT utilization: < 5% moderate
- FF utilization: < 2%
- BRAM: None (matrix fits in distributed RAM)

---

#### 6.6 Measure Performance Metrics (PRIMARY DELIVERABLE)
**Priority**: 🟡 **MEDIUM** (after Phase 3 complete) — **But PRIMARY expected deliverable per Midsem**
**Effort**: 2–3 hours (data analysis)
**Deliverable**: Performance curves and graphs

**Primary Metric** (Midsem Section 4 expected deliverable):
The **"Average Pipeline Stalls vs. Error Injection Rate" graph** is the primary expected deliverable:

1. **Stall vs. Syndrome Injection Rate** (PRIMARY - Measure This First)
   - x-axis: Syndromes per cycle (0.1 to 2.0)
   - y-axis: % cycles FIFO-to-dispatch stalled
   - Shows throughput bottleneck under varying load
   - Demonstrates effectiveness of dispatch logic under realistic stress

**Secondary Metrics** (supporting analysis):

2. **Stall vs. Error Rate**
   - x-axis: Physical error rate p (0.0001 to 0.01)
   - y-axis: % cells locked by matrix
   - Shows collision pressure under varying noise

3. **Worker Utilization**
   - x-axis: Syndrome rate
   - y-axis: Avg. workers busy (0 to 4)
   - Shows if 4-worker pool is sufficient

4. **Operating Frequency (Fmax)**
   - Measured from synthesis (Phase 4)
   - Target: > 250 MHz to satisfy T1/T2 constraints (<1 μs per syndrome)

---

#### 6.7 Generate Final Project Report
**Priority**: 🟡 **MEDIUM**
**Effort**: 2–3 hours
**Deliverable**: Updated `references/report.md` or separate results document

**Sections to Add**:
- Results (Fmax, area, stall measurements)
- Analysis (comparison to theoretical baselines)
- Conclusions
- Future work (multi-round clusters, dynamic locks)
- Acknowledgments

---

## 7. KNOWN ISSUES & CRITICAL DESIGN CONSTRAINTS

### Critical Safety Constraint: FSM STALL State Re-evaluation

⚠️ **MUST IMPLEMENT CORRECTLY IN FSM** ⚠️

The FSM **must re-evaluate the tracking matrix after ANY worker completion signal**, even if exiting STALL. This is not optional:

**Scenario**: If syndrome A is blocked because workers 1 & 2 hold overlapping 3×3 regions, and worker 1 finishes:
- ❌ **WRONG**: Exit STALL → directly to ISSUE → collision risk (worker 2 still holding)
- ✓ **CORRECT**: Exit STALL → return to HAZARD_CHK → re-query matrix → safe decision

**Implementation requirement**:
```systemverilog
// When any worker_done[i] asserts:
next_state = HAZARD_CHK;  // Force re-evaluation, never skip directly to ISSUE
```

This ensures mutual exclusion is maintained even under concurrent worker releases.

---

## 8. KNOWN ISSUES & LIMITATIONS

### Current Design Limitations

| Issue | Impact | Mitigation |
|-------|--------|-----------|
| **Static 3×3 locks** | May over-allocate under clustered errors | Adaptive lock size (future work) |
| **Single-worker-per-syndrome** | No parallelism within clusters | Batch multiple syndromes (future) |
| **No multi-round tracking** | Can't link clusters across rounds | Extend matrix with round ID (future) |
| **Async FIFO not metastable-hardened** | CDC issues if used with mixed clocks | Add CDC synchronizers before deployment |
| **No formal properties (SVA)** | Mutual exclusion not formally proven | Add Verilog assertions post-Phase-3 |
| **FSM STALL re-evaluation critical** | Easy to implement incorrectly | See "Critical Safety Constraint" above |

### Code Quality Notes

✓ **Strengths**:
- Clear naming conventions (state_e, coord_t)
- Comprehensive comments explaining logic
- Parameterized for generalization (DEPTH, CODE_DIST)
- Tested on both open-source and vendor tools

⚠ **Opportunities**:
- Add SystemVerilog always procedures (currently uses blocking assigns for compatibility)
- Add formal verification properties (Assertion-Based Verification)
- Measure code coverage (line, branch, FSM state)

---

## 8. TIMELINE & NEXT SESSION PLAN

### Recommended Session 1 (Next 3–4 hours)
1. **Design FSM** (1–2 hrs) → `rtl/dispatcher_fsm.sv`
2. **Top-level module** (1 hr) → `rtl/dispatcher_top.sv`
3. **Unit test FSM** (1 hr) → verify state transitions

### Recommended Session 2 (Following 4–5 hours)
1. **Integration testbench** (2–3 hrs) → `tb/tb_dispatcher_integration.sv`
2. **Load Stim stimulus** (1 hr) → parse stim_errors.txt
3. **Run full test suite** (0.5 hr) → verify 0 collisions

### Recommended Session 3 (Post-Phase-3, ~2–3 hours)
1. **Xilinx synthesis** (1.5–2 hrs)
2. **Measure Fmax, area** (0.5 hr)
3. **Generate performance report** (1 hr)

---

## 9. KEY FILES & QUICK REFERENCE

### Source Code
| File | Purpose | Status |
|------|---------|--------|
| `rtl/dispatcher_pkg.sv` | Package definitions | ✓ Done |
| `rtl/syndrome_fifo.sv` | FIFO queue | ✓ Done |
| `rtl/tracking_matrix.sv` | Collision detection | ✓ Done |
| `rtl/dispatcher_fsm.sv` | **NEXT:** Dispatch FSM | ✗ TODO |
| `rtl/dispatcher_top.sv` | **NEXT:** Top-level integration | ✗ TODO |

### Testbenches
| File | Purpose | Status |
|------|---------|--------|
| `tb/tb_syndrome_fifo.sv` | FIFO tests (26 tests) | ✓ Done |
| `tb/tb_tracking_matrix.sv` | Matrix tests (22 tests) | ✓ Done |
| `tb/tb_dispatcher_integration.sv` | **NEXT:** End-to-end tests | ✗ TODO |

### Verification
| File | Purpose | Status |
|------|---------|--------|
| `verification/generate_stim_data.py` | Stimulus generation | ✓ Done |
| `verification/verify_collisions.py` | Collision checking | ✓ Done |
| `verification/stim_errors.txt` | 221 syndrome pairs | ✓ Done |

### Build & Docs
| File | Purpose | Status |
|------|---------|--------|
| `Makefile` | Build automation | ✓ Done |
| `build.sh` | Build script | ✓ Done |
| `README.md` | User guide | ✓ Done |
| `references/report.md` | Academic report | ✓ Done |
| `PROJECT_STATUS.md` | **THIS FILE:** Status & plan | ✓ Done |

---

## 10. SUCCESS CRITERIA

### Phase 3 Completion (Integration)
- [ ] FSM module compiles without errors
- [ ] Integration testbench runs 221 syndromes to completion
- [ ] Collision verification returns "0 collisions"
- [ ] Stall count measured and recorded
- [ ] All tests passing on both iverilog and xsim

### Phase 4 Completion (Results)
- [ ] Design synthesizes without critical warnings
- [ ] Fmax measured (target: > 250 MHz)
- [ ] Area measured (target: < 10K LUTs for dispatcher)
- [ ] Performance graphs generated (3 metrics)
- [ ] Final report updated with results

### Delivery Ready
- [ ] All code committed to git
- [ ] README updated with final instructions
- [ ] Test logs archived
- [ ] Synthesis reports included in references/

---

## 11. CONTACT & RESOURCES

**Faculty Advisors**:
- Physics: Prof. Jayendra N. Bandyopadhyay
- EEE: Prof. Govind Prasad

**References**:
- Stim library: https://github.com/quantumlib/Stim
- Surface codes: Fowler, arXiv:1110.5133
- Union-Find decoders: Delfosse & Nickerson, arXiv:1709.06218

**Tools**:
- iverilog: Open-source Verilog simulator
- Xilinx Vivado 2025.1: FPGA design suite
- Python 3.8+: Simulation infrastructure scripts

---

**Document Version**: 1.0
**Last Updated**: 2026-04-05
**Next Review**: After Phase 3 completion
