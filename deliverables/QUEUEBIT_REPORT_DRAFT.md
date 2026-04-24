# QueueBit: A Hardware Dispatcher for Online Syndrome Routing in Surface-Code Decoding

## Abstract

Real-time quantum error correction requires classical control logic that can route syndrome events to processing units without creating unsafe overlap between concurrently active work regions. This report presents QueueBit, a hardware dispatcher for online syndrome routing in surface-code decoding pipelines. QueueBit is not a full decoder. It is a control-plane component that receives syndrome coordinates, checks them against the active lock state, and either issues them to a worker or stalls until the hazard clears. The design is evaluated at two operating points, d=11 and d=23, using worker-latency and offered-load sweeps. The results show that QueueBit behaves predictably across both scales, with clear source-limited and saturated regimes. A naive baseline without hazard checking produces 138 unsafe concurrent pairs out of 439 concurrent pairs, confirming that collision-aware dispatch is functionally necessary. Post-route FPGA implementation on XC7Z020 meets the applied 100 MHz timing target at both d=11 and d=23. The d=23 results also show substantial blocked hazard activity at larger scale and heavier load, which makes d=23 the main platform for discussing operating limits.

## 1. Introduction

Surface-code quantum error correction depends on fast classical processing. Syndrome bits must be collected, interpreted, and routed to decoder logic quickly enough that the correction pipeline does not fall behind the quantum system. Much of the literature focuses on the decoder itself, for example matching-based decoders, Union-Find decoders, and cluster-based methods. However, before a worker or decoder stage can process a syndrome, that syndrome must first be assigned safely.

This report studies that assignment problem. If two workers are allowed to process nearby syndromes at the same time, they may operate on overlapping spatial regions. In a practical decoding pipeline this creates a coordination problem. QueueBit addresses this by placing a hardware dispatch layer in front of the workers. The dispatcher keeps track of active regions, tests whether a new syndrome would conflict with the current lock state, and either issues the syndrome immediately or stalls it until the hazard clears.

The contribution of this work is therefore not a new decoder algorithm. It is a hardware dispatch mechanism for online, collision-aware syndrome routing. The report focuses on three questions:

1. Is active hazard checking actually necessary?
2. How does the dispatcher behave as worker latency and offered load change?
3. Does the design remain implementable when scaled from a smaller d=11 case to a larger d=23 case?

These questions are answered using a naive baseline, d=11 and d=23 sweeps, and post-route FPGA implementation results.

## 2. Background and Scope

QueueBit is designed for surface-code style workloads in which syndrome events arrive over time and must be routed to a worker pool. The key assumption is that each active worker occupies a local spatial neighborhood for some number of cycles. During that time, issuing a nearby syndrome to another worker is unsafe and should be prevented.

This makes QueueBit a control-plane component. It sits between syndrome generation and downstream worker logic. It does not decode by itself. It does not replace Union-Find, matching, or clustering methods. Instead, it provides an online dispatch policy that can be placed in front of such workers.

The implementation and measurements presented here are dispatcher-level results. They show whether QueueBit accepts, delays, and routes syndromes coherently. They do not yet provide a full end-to-end decoder proof.

## 3. Architecture

QueueBit has three main blocks.

### 3.1 Syndrome FIFO

The FIFO buffers incoming syndrome coordinates. It decouples the arrival stream from the dispatch logic and provides the next candidate syndrome to the FSM. The interface uses a valid/ready protocol.

### 3.2 Tracking Matrix

The tracking matrix stores the currently locked spatial regions. When a worker receives a syndrome, a local neighborhood around that coordinate is marked as active. When the worker completes, that region is released. Collision checking is performed against this matrix before a new syndrome is issued.

In the present design, the lock model is a static local neighborhood around each active syndrome. This keeps collision checking simple in hardware, but it also means the design should be interpreted as a bounded operating policy rather than a universal proof for all future decoder models.

### 3.3 Dispatch FSM

The FSM coordinates the pipeline. It reads the next syndrome from the FIFO, queries the tracking matrix, and either:

- issues the syndrome to an available worker and locks the corresponding region, or
- stalls until the hazard clears

The worker interface is abstract in the current testbench. Each worker has a configurable latency `K`, which represents the number of cycles that worker remains busy after receiving a syndrome.

## 4. Experimental Method

### 4.1 Testbench Configuration

Two dispatcher operating points are studied:

- d=11 baseline configuration
- d=23 scale-up configuration

For each case, the dispatcher is exercised with a fixed workload of 221 syndrome pairs. Worker latency is swept across:

- `K in {5, 10, 15, 20}`

Offered load is swept across:

- `inj in {0.1, 0.5, 1.0, 1.5, 2.0}` syndromes per cycle

Each configuration is run three times. The runs are deterministic, so the three repeats serve mainly as a consistency check.

### 4.2 Simulation Flow

The final d=11 and d=23 datasets are taken only from the verified simulation flow. Earlier intermediate runs exposed several issues:

- injection-rate parameters were not initially reaching the simulator
- summaries could be printed before the testbench had fully drained
- d11 stimulus logic had to be updated to respect the FIFO protocol cleanly

These issues were fixed before the final datasets used in this report were generated. The final d11 and d23 logs both show complete runs with valid summaries, zero protocol errors in the d11 sweep, and deterministic results across repeated configurations.

### 4.3 Metrics

The report uses the following metrics:

- `total cycles`: total runtime of one simulation
- `syndromes issued`: total number of dispatched syndromes
- `hazard detections`: number of detected conflicts in the d=23 scale-up path
- `stall cycles`: number of cycles in which the dispatcher is stalled
- `stall fraction of runtime`: `stall_cycles / total_cycles * 100`
- `average busy workers`: average number of active workers over the run

One older metric was intentionally not used in this report: `stalled / issued * 100`. That metric mixes cycles and syndromes and can exceed 100% in a way that is difficult to interpret. The present report instead uses stall fraction of runtime, which remains cycle-normalized.

### 4.4 Synthesis Method

Post-route FPGA implementation was performed for:

- `dispatcher_top` (d=11)
- `dispatcher_top_d23` (d=23)

Target device:

- Xilinx XC7Z020-1CLG484

Clock target:

- 100 MHz

The synthesis numbers in this report should be interpreted as internal design implementation results under the current constraint set. The present study does not yet include a fully board-constrained I/O timing model.

## 5. Results

### 5.1 Naive Baseline

The naive dispatcher disables hazard checking and issues work without spatial protection. This baseline tests whether collision-aware dispatch is actually needed.

The result is clear: the naive baseline produces spatial violations, while the standard dispatcher prevents them by stalling when necessary. Collision-aware dispatch is therefore a functional requirement of the control layer rather than a performance optimization.

**Table 1. Naive baseline summary**

| Mode | Concurrent pairs observed | Unsafe pairs | Unsafe-pair rate |
| --- | ---: | ---: | ---: |
| Standard dispatcher | 144 | 0 | 0.0% |
| Naive dispatcher | 439 | 138 | 31.4% |

### 5.2 d=11 and d=23 Sweeps

The d=11 sweep is the baseline characterization case. All 60 runs are valid, complete, and free of FIFO protocol errors. The d=23 sweep is the main scale-up characterization case. All 60 runs are also complete and deterministic.

Both operating points show the same broad structure:

- `inj=0.1` is source-limited
- `inj >= 1.0` is effectively saturated

At low offered load, the source itself limits throughput. At higher offered load, the dispatcher and worker availability become the limiting factors. This is why the same 221-syndrome workload finishes much faster at `inj=1.0` than at `inj=0.1`.

**Figure 1. Runtime versus offered load**

![Runtime versus offered load](figures/figure_cycles_distance_comparison.png)

**Figure 2. Stall fraction versus offered load**

![Stall fraction versus offered load](figures/figure_stall_distance_comparison.png)

**Table 2. Sweep summary using representative low-load and saturated-load points**

| Distance | K | Cycles at inj=0.1 | Cycles at inj=1.0 | Stall fraction at inj=0.1 | Stall fraction at inj=1.0 |
| --- | ---: | ---: | ---: | ---: | ---: |
| d=11 | 5 | 2225 | 1062 | 0.00% | 57.06% |
| d=11 | 10 | 2230 | 1737 | 23.95% | 54.35% |
| d=11 | 15 | 2271 | 2196 | 70.37% | 78.23% |
| d=11 | 20 | 2880 | 2871 | 71.25% | 71.75% |
| d=23 | 5 | 2226 | 519 | 9.93% | 47.21% |
| d=23 | 10 | 2231 | 728 | 9.91% | 57.83% |
| d=23 | 15 | 2236 | 1165 | 9.88% | 66.70% |
| d=23 | 20 | 2241 | 1380 | 9.82% | 69.13% |

The d=11 case is the cleaner baseline. It shows expected saturation behavior, and larger `K` increases runtime and stall pressure. For example, at `inj=1.0`, runtime rises from `1062` cycles at `K=5` to `2871` cycles at `K=20`.

The d=23 case shows the same low-load versus saturated-load structure, but it also exposes much stronger contention. For example, at `K=5`, runtime drops from `2226` cycles at `inj=0.1` to `519` cycles at `inj=1.0`, while at `K=20` it only drops from `2241` to `1380` cycles because long worker occupancy dominates the runtime.

### 5.3 d=23 Hazard Detections

The most important scale-up result is the hazard-detection behavior at d=23. In this report, a d=23 "collision detected" event is treated as a blocked hazard or blocked conflict event. It is not, by itself, proof that unsafe overlapping work was actually issued.

These counts measure how often QueueBit detects that a candidate syndrome conflicts with the current lock state and therefore must be stalled.

**Figure 3. d=23 hazard detections versus offered load**

![d=23 hazard detections versus offered load](figures/figure_d23_collisions.png)

**Table 3. d=23 hazard detections**

| K | Hazard detections at inj=0.1 | Hazard detections at inj>=0.5 |
| --- | ---: | ---: |
| 5 | 0 | 31 |
| 10 | 6 | 52 |
| 15 | 24 | 91 |
| 20 | 33 | 112 |

This result should be interpreted as follows:

1. larger `K` keeps locks active for longer
2. higher offered load keeps the candidate issue path populated
3. at d=23, those two effects create many more blocked hazard events

This is therefore a contention result and an operating-envelope result. It shows where the dispatcher spends its effort under load.

### 5.4 FPGA Implementation Results

Post-route implementation results are available for both operating points.

**Table 4. Post-route FPGA implementation summary on XC7Z020**

| Metric | d=11 | d=23 |
| --- | ---: | ---: |
| Target clock | 100 MHz | 100 MHz |
| Setup slack | +0.424 ns | +0.163 ns |
| Hold slack | +0.191 ns | +0.151 ns |
| LUTs | 2804 (5.27%) | 12321 (23.16%) |
| Flip-flops | 928 (0.87%) | 2797 (2.63%) |
| DSPs | 0 | 0 |
| BRAMs | 0 | 0 |
| Total power | 115.0 mW | 145.0 mW |
| Dynamic power | 10.0 mW | 40.0 mW |
| Static power | 105.0 mW | 105.0 mW |

Both operating points meet the applied 100 MHz timing target. This is the fair synthesis comparison to use. Older unconstrained frequency numbers should not be mixed into this table.

The scale-up story is also clear. LUT growth from d=11 to d=23 is about `4.4x`, which closely matches the growth in tracking-grid cells between the two operating points. The d=23 design is substantially larger than d=11, but it still fits comfortably on XC7Z020 under the current implementation flow.

## 6. Discussion

### 6.1 Interpretation of d=23 Hazard Detections

The non-zero d=23 hazard-detection counts are the most important result in the project.

They should not be described as direct evidence of unsafe overlap. Instead, they show that under larger scale, longer worker occupancy, and heavier offered load, the dispatcher encounters many more candidate issues that conflict with the current lock state. QueueBit then blocks those issues.

This is a performance result and an operating-envelope result. It shows where the dispatcher becomes contention-limited. It does not by itself prove a safety failure.

### 6.2 Source-Limited Execution at Low Injection Rates

One result that could confuse readers is the large runtime drop between `inj=0.1` and `inj=1.0`. For example, at `K=5`, d=23 drops from `2226` cycles to `519` cycles.

The explanation is straightforward. The workload contains the same 221 syndromes in both cases. The difference is only how quickly those syndromes are offered to the dispatcher. At low offered load, the source itself becomes the bottleneck. At high offered load, the dispatcher and worker availability become the bottleneck.

This is why moving from `inj=0.1` to `inj=1.0` reduces total runtime without changing the amount of work completed.

### 6.3 Scalability and Contention Pressure at d=23

d=11 is a necessary baseline, but d=23 is the more informative stress case. The d=23 results expose:

- stronger contention effects
- stronger sensitivity to worker occupancy
- measurable blocked hazard activity under load

Because of this, d=23 should carry the main discussion burden in the results and discussion sections. The comparison should not be framed as d=23 being better. It should be framed as d=23 being larger and harder.

### 6.4 Scope of the Present Study

This report does not yet establish:

- end-to-end decoder integration
- physical-board runtime validation
- a universal formal sufficiency theorem for the lock policy

The present evidence is empirical and bounded to the tested operating points. For the present paper, that scope is acceptable as long as it is stated plainly.

## 7. Limitations and Future Work

This report has several clear boundaries.

First, QueueBit is evaluated as a dispatcher, not as a full decoder. The worker model is still abstract.

Second, the synthesis results are implementation results for the internal design logic under the current constraint set. They are not a full board-level interface study.

Third, the present report studies one worker count and two code-distance operating points. Broader scaling across worker counts remains future work.

Fourth, the report does not attempt to prove a universal formal lemma for the lock policy across all loads and scales. The current paper is an empirical characterization study.

Natural next steps are:

- integration with a reference decoder
- board-level deployment
- worker-count scaling
- broader error-rate characterization

## 8. Conclusion

This report presented QueueBit, a hardware dispatcher for online syndrome routing in surface-code decoding pipelines. QueueBit is a control-plane block that accepts syndrome coordinates, checks them against the active lock state, and either issues them to a worker or stalls until the conflict clears.

The experimental results support four main conclusions:

1. Hazard checking is necessary. The naive baseline produces spatial violations.
2. QueueBit shows clear source-limited and saturated regimes at both d=11 and d=23.
3. Larger worker latency increases runtime and contention pressure.
4. Scaling from d=11 to d=23 remains implementable on XC7Z020 at the applied 100 MHz target, but d=23 exposes substantial blocked hazard activity under load.

These results give the project an empirical base, a clean baseline-to-scale-up comparison, and a practical FPGA implementation story at two operating points.

## References

[1] Ben Barber et al. "A real-time, scalable, fast and resource-efficient decoder for a quantum computer". In: Nature Electronics 8.1 (Jan. 2025), pp. 84–91. issn: 2520-1131. doi: 10.1038/s41928-024-01319-5. url: http://dx.doi.org/10.1038/s41928-024-01319-5.

[2] Nicolas Delfosse and Naomi H. Nickerson. "Almost-linear time decoding algorithm for topological codes". In: Quantum 5 (Dec. 2021), p. 595. issn: 2521-327X. doi: 10.22331/q-2021-12-02-595. url: http://dx.doi.org/10.22331/q-2021-12-02-595.

[3] Takuya Kasamura, Junichiro Kadomoto, and Hidetsugu Irie. "Design of an Online Surface Code Decoder Using Union-Find Algorithm". In: 2025 IEEE 43rd International Conference on Computer Design (ICCD). Los Alamitos, CA, USA: IEEE Computer Society, Nov. 2025, pp. 823–830. doi: 10.1109/ICCD65941.2025.00121. url: https://doi.ieeecomputersociety.org/10.1109/ICCD65941.2025.00121.

[4] Federico Valentino et al. "QUEKUF: An FPGA Union Find Decoder for Quantum Error Correction on the Toric Code". In: ACM Trans. Reconfigurable Technol. Syst. 18.3 (Aug. 2025). issn: 1936-7406. doi: 10.1145/3733239. url: https://doi.org/10.1145/3733239.
