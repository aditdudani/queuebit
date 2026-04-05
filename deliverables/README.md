# Deliverables

This folder contains the main results from the QueueBit project.

## Files

**FINAL_REPORT.md**
- Full academic report with introduction, methodology, results, analysis, and conclusions
- 17 citations to relevant literature
- Contains 4 embedded figures

**stall_vs_load_sweep.png**
- Dispatcher stall rate vs. syndrome injection load for worker latencies K ∈ {5, 10, 15, 20} cycles

**worker_utilization.png**
- Average concurrent busy workers vs. syndrome injection rate

**synthesis_fmax.png**
- Synthesis metrics: Fmax, LUT utilization, FF utilization

**metrics.csv**
- Raw simulation data: 60 runs across K values and injection rates
- Columns: K, injection_rate, run, stall_cycles, total_cycles, stall_rate_pct, avg_workers, syndromes_issued, errors

**dispatcher_top_utilization_synth.rpt**
- Vivado synthesis report with resource breakdown by module

**timing_summary.png**
- Vivado timing analysis showing critical path and slack

## Key Findings

- **Synthesis**: Achieves 127.5 MHz on xc7z020clg484-1 with 5.30% LUT and 0.86% FF utilization
- **Correctness**: 221-syndrome integration test with zero spatial collisions detected
- **Performance**: Stall rate ranges from 52% (K=5 cycles) to 89% (K=20 cycles), independent of injection load
- **Verification**: 48 unit tests (FIFO + tracking matrix) and 1 integration test, all passing on iverilog and xsim
- **Design**: O(1) dispatch achieved through single-cycle combinatorial collision detection and 4-state FSM

## How to Reproduce

All results can be regenerated from source code and the Vivado project state:

1. **Unit Tests**: Run `./build.sh test` from project root (iverilog) or `./build.sh test-xsim` (Xilinx xsim)
2. **Integration Test**: Included in `tb_dispatcher_integration.sv` (221 syndrome pairs with parameterized worker latency K)
3. **Synthesis**: Open project `batch_run/queuebit_vivado/` in Vivado 2025.1, target xc7z020clg484-1, run synthesis
4. **Batch Simulations**: Execute `vivado -mode batch -source batch_run/batch_simulate.tcl` for all 60 configurations (K values and injection rates)
5. **Metrics Extraction**: Run `python batch_run/extract_metrics.py` to parse simulation logs and generate metrics.csv
6. **Visualization**: Run `python batch_run/plot_results.py` to regenerate PNG figures from metrics.csv

See **[FINAL_REPORT.md](./FINAL_REPORT.md)** (§3 Methodology) for detailed procedural documentation.
