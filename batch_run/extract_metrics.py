#!/usr/bin/env python3
"""
Phase 4 Metrics Extraction Script
Parses simulation logs for stall cycles and worker utilization
Skips logs that failed (no XSIM output)
"""

import os
import csv
import re
from collections import defaultdict

# Define output CSV file
OUTPUT_CSV = "build/metrics.csv"
LOG_DIR = "build"

# Parse logs
results = []
skipped = 0

log_files = sorted([f for f in os.listdir(LOG_DIR) if f.startswith("log_K") and f.endswith(".txt")])

for log_file in log_files:
    # Extract K, injection_rate, run from filename
    match = re.match(r"log_K(\d+)_inj([\d.]+)_(\d+)\.txt", log_file)
    if not match:
        continue

    K = int(match.group(1))
    inj_rate = float(match.group(2))
    run = int(match.group(3))

    filepath = os.path.join(LOG_DIR, log_file)

    # Count FSM_STALL cycles and worker activity
    stall_cycles = 0
    total_cycles = 0
    worker_bits = defaultdict(int)
    syndromes_issued = 0
    errors = []
    has_xsim_output = False

    with open(filepath, 'r') as f:
        for line in f:
            # Check if this is valid XSIM output
            if "--- XSIM STDOUT ---" in line:
                has_xsim_output = True

            # Count FSM_STALL state transitions
            if "FSM_STALL" in line:
                stall_cycles += 1

            # Count FSM cycles (every [FSM] Cycle line)
            if "[FSM] Cycle" in line:
                total_cycles += 1

            # Extract worker state from workers_ready field
            workers_match = re.search(r"workers_ready=(\d{4})", line)
            if workers_match:
                worker_state = workers_match.group(1)
                # Active = total (4) minus ready (count of 1s)
                active_workers = 4 - worker_state.count('1')
                worker_bits[active_workers] += 1

            # Count issued syndromes
            if "Issued syndr" in line:
                syndromes_issued += 1

            # Capture errors
            if "Error:" in line or "ERROR" in line:
                errors.append(line.strip())

    # Skip logs without valid XSIM output
    if not has_xsim_output or total_cycles == 0:
        print(f"✗ {log_file}: SKIPPED (no valid XSIM output)")
        skipped += 1
        continue

    # Calculate metrics
    stall_rate = (stall_cycles / total_cycles * 100) if total_cycles > 0 else 0
    avg_workers = sum(k * v for k, v in worker_bits.items()) / sum(worker_bits.values()) if total_cycles > 0 else 0

    results.append({
        'K': K,
        'injection_rate': inj_rate,
        'run': run,
        'stall_cycles': stall_cycles,
        'total_cycles': total_cycles,
        'stall_rate_pct': round(stall_rate, 2),
        'avg_workers': round(avg_workers, 2),
        'syndromes_issued': syndromes_issued,
        'errors': len(errors)
    })

    print(f"✓ {log_file}: stall={stall_rate:.2f}%, workers={avg_workers:.2f}, issued={syndromes_issued}, errors={len(errors)}")

# Write CSV
with open(OUTPUT_CSV, 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=['K', 'injection_rate', 'run', 'stall_cycles', 'total_cycles', 'stall_rate_pct', 'avg_workers', 'syndromes_issued', 'errors'])
    writer.writeheader()
    writer.writerows(results)

print(f"\n✓ Metrics written to {OUTPUT_CSV}")
print(f"✓ Valid runs: {len(results)}/60")
print(f"✗ Skipped runs: {skipped}/60")

# Summary statistics
if results:
    print("\n--- SUMMARY STATISTICS ---")
    for K in sorted(set(r['K'] for r in results)):
        k_results = [r for r in results if r['K'] == K]
        avg_stall = sum(r['stall_rate_pct'] for r in k_results) / len(k_results)
        print(f"K={K}: avg_stall_rate={avg_stall:.2f}%")
