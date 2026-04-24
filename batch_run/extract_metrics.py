#!/usr/bin/env python3
"""
Extract d=11 sweep metrics from batch_run/build logs.

This version uses the final summary block for core run metrics and only falls
back to detailed log-line counting for auxiliary values such as stall cycles
and average active workers.
"""

import csv
import re
import sys
from collections import defaultdict
from pathlib import Path


LOG_DIR = Path("build")
OUTPUT_CSV = LOG_DIR / "metrics.csv"


def parse_run_log(log_path):
    metrics = {
        "cycles": None,
        "injected": None,
        "issued": None,
        "stall_cycles": 0,
        "avg_workers": 0.0,
        "errors": 0,
        "has_xsim_output": False,
        "status": None,
    }

    try:
        content = log_path.read_text(errors="replace")
    except Exception as exc:
        print(f"ERROR reading {log_path}: {exc}", file=sys.stderr)
        return None

    if "--- XSIM STDOUT ---" in content:
        metrics["has_xsim_output"] = True

    summary_match = re.search(
        r"=+\s*\nDISPATCHER INTEGRATION TEST RESULTS\s*\n=+\s*\n(.*?)\n=+",
        content,
        re.DOTALL | re.IGNORECASE,
    )
    if summary_match:
        block = summary_match.group(1)
        patterns = [
            (r"Total cycles run\s*:\s*(\d+)", "cycles"),
            (r"Syndromes injected\s*:\s*(\d+)", "injected"),
            (r"Syndromes issued\s*:\s*(\d+)", "issued"),
            (r"Completion status\s*:\s*(.+)", "status"),
        ]
        for pattern, key in patterns:
            match = re.search(pattern, block, re.IGNORECASE)
            if match:
                metrics[key] = match.group(1).strip() if key == "status" else int(match.group(1))

    worker_bits = defaultdict(int)
    for line in content.splitlines():
        if "FSM_STALL" in line:
            metrics["stall_cycles"] += 1

        workers_match = re.search(r"workers_ready=(\d{4})", line)
        if workers_match:
            worker_state = workers_match.group(1)
            active_workers = 4 - worker_state.count("1")
            worker_bits[active_workers] += 1

        if "Error:" in line or "ERROR" in line:
            metrics["errors"] += 1

    total_worker_samples = sum(worker_bits.values())
    if total_worker_samples > 0:
        metrics["avg_workers"] = sum(k * v for k, v in worker_bits.items()) / total_worker_samples

    return metrics


def main():
    if not LOG_DIR.exists():
        print(f"ERROR: Log directory not found: {LOG_DIR}")
        print("Run: vivado -mode batch -source batch_simulate.tcl")
        sys.exit(1)

    results = []
    skipped = 0

    log_files = sorted(LOG_DIR.glob("log_K*.txt"))
    for log_file in log_files:
        match = re.match(r"log_K(\d+)_inj([\d.]+)_(\d+)\.txt", log_file.name)
        if not match:
            continue

        K = int(match.group(1))
        inj_rate = float(match.group(2))
        run = int(match.group(3))

        metrics = parse_run_log(log_file)
        if metrics is None:
            skipped += 1
            continue

        if not metrics["has_xsim_output"] or metrics["cycles"] is None:
            print(f"SKIPPED {log_file.name}: no valid XSIM summary")
            skipped += 1
            continue

        stall_rate = (
            (metrics["stall_cycles"] / metrics["cycles"]) * 100.0
            if metrics["cycles"] > 0
            else 0.0
        )

        results.append(
            {
                "K": K,
                "injection_rate": inj_rate,
                "run": run,
                "cycles": metrics["cycles"],
                "syndromes_injected": metrics["injected"],
                "syndromes_issued": metrics["issued"],
                "stall_cycles": metrics["stall_cycles"],
                "stall_rate_pct": round(stall_rate, 2),
                "avg_workers": round(metrics["avg_workers"], 2),
                "status": metrics["status"],
                "errors": metrics["errors"],
            }
        )

        print(
            f"{log_file.name}: cycles={metrics['cycles']}, "
            f"issued={metrics['issued']}, stall={stall_rate:.2f}%, "
            f"workers={metrics['avg_workers']:.2f}, status={metrics['status']}"
        )

    with OUTPUT_CSV.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "K",
                "injection_rate",
                "run",
                "cycles",
                "syndromes_injected",
                "syndromes_issued",
                "stall_cycles",
                "stall_rate_pct",
                "avg_workers",
                "status",
                "errors",
            ],
        )
        writer.writeheader()
        writer.writerows(results)

    print(f"\nMetrics written to {OUTPUT_CSV}")
    print(f"Valid runs: {len(results)}/{len(log_files)}")
    print(f"Skipped runs: {skipped}/{len(log_files)}")

    if results:
        print("\nSummary by K:")
        for K in sorted(set(r["K"] for r in results)):
            k_results = [r for r in results if r["K"] == K]
            avg_stall = sum(r["stall_rate_pct"] for r in k_results) / len(k_results)
            avg_cycles = sum(r["cycles"] for r in k_results) / len(k_results)
            print(f"K={K}: avg_cycles={avg_cycles:.1f}, avg_stall_rate={avg_stall:.2f}%")


if __name__ == "__main__":
    main()
