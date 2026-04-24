#!/usr/bin/env python3
"""
Parse d=23 K-sweep simulation logs and aggregate metrics into tables.

Input:  build_d23/log_K*.txt (60 files from batch_simulate_d23.tcl)
Output: build_d23/k_sweep_results.csv (aggregated metrics)

Key features:
- Hardened regex matching (case-insensitive, with sanity checks)
- Per-run metrics extraction (cycles, issued, collisions, stalled)
- Statistical aggregation (mean across 3 runs per config)
- Warning on missing metrics (prevents silent failures)
"""

import glob
import re
import csv
from pathlib import Path
from collections import defaultdict
import sys

def parse_metrics_from_log(log_path):
    """
    Extract simulation metrics from testbench $display output.

    Expected log format (from tb_dispatcher_integration_d23.sv):
    - Total Cycles: <integer>
    - Syndromes Issued: <integer>
    - Collisions Detected: <integer>
    - Syndromes Stalled: <integer>

    Returns dict with keys: cycles, issued, collisions, stalled
    Returns empty dict if file cannot be read.
    """
    metrics = {}

    try:
        with open(log_path, 'r') as f:
            for line in f:
                # Use case-insensitive matching to handle format variations
                line_lower = line.lower()

                if 'total' in line_lower and 'cycles' in line_lower:
                    match = re.search(r'(\d+)', line)
                    if match:
                        metrics['cycles'] = int(match.group(1))

                elif ('issued' in line_lower or 'syndromes' in line_lower) and 'issued' in line_lower:
                    match = re.search(r'(\d+)', line)
                    if match:
                        metrics['issued'] = int(match.group(1))

                elif 'collision' in line_lower or 'collisions' in line_lower:
                    match = re.search(r'(\d+)', line)
                    if match:
                        metrics['collisions'] = int(match.group(1))

                elif 'stall' in line_lower:
                    match = re.search(r'(\d+)', line)
                    if match:
                        metrics['stalled'] = int(match.group(1))

    except Exception as e:
        print(f"⚠️  ERROR reading {log_path}: {e}", file=sys.stderr)
        return {}

    # SANITY CHECK: Warn if metrics incomplete
    expected_keys = {'cycles', 'issued', 'collisions', 'stalled'}
    found_keys = set(metrics.keys())
    if not expected_keys.issubset(found_keys):
        missing = expected_keys - found_keys
        print(f"⚠️  WARNING: Incomplete metrics in {log_path}", file=sys.stderr)
        print(f"     Missing: {missing}", file=sys.stderr)
        print(f"     Found: {found_keys}", file=sys.stderr)

    return metrics

def main():
    log_dir = Path('build_d23')

    # Ensure log directory exists
    if not log_dir.exists():
        print(f"❌ ERROR: Log directory not found: {log_dir}")
        print("   Run: vivado -mode batch -source batch_simulate_d23.tcl")
        sys.exit(1)

    print(f"📊 Parsing K-sweep logs from {log_dir}...")

    # Parse all logs and group by (K, inj_rate)
    results = defaultdict(list)
    log_count = 0

    for log_file in sorted(glob.glob(str(log_dir / 'log_*.txt'))):
        # Parse filename: log_K5_inj0.1_1.txt → K=5, inj_rate=0.1, run=1
        match = re.search(r'log_K(\d+)_inj([\d.]+)_(\d+)\.txt', log_file)
        if not match:
            print(f"⚠️  WARNING: Filename format mismatch: {log_file}", file=sys.stderr)
            continue

        K, inj_rate, run_num = match.groups()
        K, inj_rate, run_num = int(K), float(inj_rate), int(run_num)

        metrics = parse_metrics_from_log(log_file)
        if metrics:  # Only collect if parsing succeeded
            results[(K, inj_rate)].append(metrics)
            log_count += 1

    if log_count == 0:
        print("❌ ERROR: No valid logs parsed!")
        print("   Check that build_d23/log_K*.txt files exist and contain valid metrics")
        sys.exit(1)

    print(f"✅ Parsed {log_count} logs")

    # Aggregate per (K, inj_rate) across 3 runs
    print("📈 Aggregating metrics...")
    summary = []

    for (K, inj_rate), runs in sorted(results.items()):
        num_runs = len(runs)

        # Compute means
        avg_cycles = sum(m.get('cycles', 0) for m in runs) / num_runs if num_runs > 0 else 0
        avg_issued = sum(m.get('issued', 0) for m in runs) / num_runs if num_runs > 0 else 0
        avg_collisions = sum(m.get('collisions', 0) for m in runs) / num_runs if num_runs > 0 else 0
        avg_stalled = sum(m.get('stalled', 0) for m in runs) / num_runs if num_runs > 0 else 0

        # Compute stall rate %
        stall_rate_pct = 0.0
        if avg_issued > 0:
            stall_rate_pct = (avg_stalled / avg_issued) * 100.0

        summary.append({
            'K': K,
            'Injection_Rate': inj_rate,
            'Avg_Cycles': f"{avg_cycles:.1f}",
            'Avg_Issued': f"{avg_issued:.1f}",
            'Avg_Collisions': f"{avg_collisions:.1f}",
            'Avg_Stalled': f"{avg_stalled:.1f}",
            'Stall_Rate_%': f"{stall_rate_pct:.1f}",
            'Num_Runs': num_runs
        })

    # Write CSV
    out_path = log_dir / 'k_sweep_results.csv'
    print(f"📝 Writing results to {out_path}...")

    fieldnames = ['K', 'Injection_Rate', 'Avg_Cycles', 'Avg_Issued',
                  'Avg_Collisions', 'Avg_Stalled', 'Stall_Rate_%', 'Num_Runs']

    try:
        with open(out_path, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(summary)
        print(f"✅ Results written: {out_path}")
    except Exception as e:
        print(f"❌ ERROR writing CSV: {e}", file=sys.stderr)
        sys.exit(1)

    # Print summary to stdout
    print("\n" + "="*80)
    print("K-SWEEP METRICS SUMMARY (d=23)")
    print("="*80)
    print(f"{'K':<4} {'Inj Rate':<12} {'Avg Cycles':<12} {'Avg Issued':<12} {'Collisions':<12} {'Stall %':<10}")
    print("-"*80)

    for row in summary:
        print(f"{row['K']:<4} {row['Injection_Rate']:<12} {row['Avg_Cycles']:<12} "
              f"{row['Avg_Issued']:<12} {row['Avg_Collisions']:<12} {row['Stall_Rate_%']:<10}")

    print("="*80)
    print(f"\n✅ Extraction complete: {len(summary)} configurations")

if __name__ == '__main__':
    main()
