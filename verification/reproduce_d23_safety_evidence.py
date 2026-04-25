#!/usr/bin/env python3
"""Reproduce and publish saturated d=23 safety validation data.

This script runs the d=23 integration testbench at K=20 for saturated
injection rates, verifies LOCK/RELEASE traces with verify_collisions.py,
and publishes a summary CSV plus raw logs.

Default cases:
  K=20
  inj_ppt in {500, 1000, 1500, 2000}

Outputs:
  build/safety_d23/
    - K20_INJ*.sim.txt
    - K20_INJ*.dispatch_log_d23.txt
    - K20_INJ*.verify.txt
    - K20_INJ*_verify/syndrome_separation_log.txt
    - d23_k20_saturated_safety_summary.csv
    deliverables/d23/safety_validation/
    - d23_k20_saturated_safety_summary.csv
    - raw/<all per-case proof files>
"""

from __future__ import annotations

import argparse
import csv
import re
import shutil
import subprocess
import sys
from pathlib import Path


def run_cmd(cmd: list[str], cwd: Path | None = None, capture: bool = True) -> tuple[int, str]:
    """Run a command and return (returncode, combined stdout+stderr)."""
    proc = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=capture,
        check=False,
    )
    out = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode, out


def parse_sim_metrics(sim_text: str) -> dict[str, int]:
    patterns = {
        "total_cycles": r"Total Cycles:\s*(\d+)",
        "syndromes_issued": r"Syndromes Issued:\s*(\d+)",
        "syndromes_stalled": r"Syndromes Stalled:\s*(\d+)",
        "collisions_detected": r"Collisions Detected:\s*(\d+)",
    }
    metrics: dict[str, int] = {}
    for key, pattern in patterns.items():
        m = re.search(pattern, sim_text)
        if not m:
            raise RuntimeError(f"Could not parse '{key}' from simulation output")
        metrics[key] = int(m.group(1))
    return metrics


def parse_verify_metrics(verify_text: str) -> dict[str, int]:
    patterns = {
        "spatial_collisions": r"SUCCESS:\s*0 Spatial Collisions Detected",
        "total_locks": r"Total LOCK events:\s*(\d+)",
        "total_releases": r"Total RELEASE events:\s*(\d+)",
        "peak_concurrent_locks": r"Peak concurrent locks:\s*(\d+)",
        "concurrent_pairs": r"Found\s*(\d+) concurrent syndrome pairs",
        "safe_pairs": r"Safe pairs:\s*(\d+), Unsafe pairs:\s*(\d+)",
    }

    if not re.search(patterns["spatial_collisions"], verify_text):
        raise RuntimeError("Trace verification did not report zero spatial collisions")

    out: dict[str, int] = {}

    for key in ["total_locks", "total_releases", "peak_concurrent_locks", "concurrent_pairs"]:
        m = re.search(patterns[key], verify_text)
        if not m:
            raise RuntimeError(f"Could not parse '{key}' from verification output")
        out[key] = int(m.group(1))

    m_safe = re.search(patterns["safe_pairs"], verify_text)
    if not m_safe:
        raise RuntimeError("Could not parse safe/unsafe pair counts")
    out["safe_pairs"] = int(m_safe.group(1))
    out["unsafe_pairs"] = int(m_safe.group(2))
    out["spatial_collisions"] = 0

    return out


def write_summary_csv(rows: list[dict[str, int]], output_csv: Path) -> None:
    fieldnames = [
        "worker_latency",
        "inj_ppt",
        "inj_rate",
        "total_cycles",
        "syndromes_issued",
        "syndromes_stalled",
        "collisions_detected",
        "spatial_collisions",
        "total_locks",
        "total_releases",
        "peak_concurrent_locks",
        "concurrent_pairs",
        "safe_pairs",
        "unsafe_pairs",
    ]

    output_csv.parent.mkdir(parents=True, exist_ok=True)
    with output_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def copy_raw_evidence(build_dir: Path, deliverables_evidence_dir: Path, case_tags: list[str]) -> None:
    raw_dir = deliverables_evidence_dir / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)

    for tag in case_tags:
        to_copy = [
            build_dir / f"{tag}.sim.txt",
            build_dir / f"{tag}.verify.txt",
            build_dir / f"{tag}.dispatch_log_d23.txt",
            build_dir / f"{tag}_verify" / "syndrome_separation_log.txt",
        ]
        for src in to_copy:
            if src.exists():
                dst_name = f"{tag}.{src.name}" if src.name == "syndrome_separation_log.txt" else src.name
                shutil.copy2(src, raw_dir / dst_name)


def main() -> int:
    parser = argparse.ArgumentParser(description="Reproduce d=23 saturated safety evidence")
    parser.add_argument("--k", type=int, default=20, help="Worker latency K (default: 20)")
    parser.add_argument(
        "--inj-ppt",
        nargs="*",
        type=int,
        default=[500, 1000, 1500, 2000],
        help="Injection rates in thousandths per cycle (default: 500 1000 1500 2000)",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Path to repository root",
    )
    parser.add_argument(
        "--iverilog",
        type=str,
        default="C:/iverilog/bin/iverilog.exe",
        help="Path to iverilog executable",
    )
    parser.add_argument(
        "--vvp",
        type=str,
        default="C:/iverilog/bin/vvp.exe",
        help="Path to vvp executable",
    )
    parser.add_argument(
        "--publish-deliverables",
        action="store_true",
        help="Copy summary and raw files into deliverables/d23/safety_validation",
    )

    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    build_dir = repo_root / "build" / "safety_d23"
    build_dir.mkdir(parents=True, exist_ok=True)

    verify_script = repo_root / "verification" / "verify_collisions.py"
    if not verify_script.exists():
        print(f"ERROR: Missing verifier: {verify_script}")
        return 2

    sources = [
        "rtl/dispatcher_pkg.sv",
        "rtl/syndrome_fifo.sv",
        "rtl/tracking_matrix.sv",
        "rtl/dispatcher_fsm_d23.sv",
        "rtl/dispatcher_top_d23.sv",
        "tb/tb_dispatcher_integration_d23.sv",
    ]

    source_paths = [str((repo_root / s).resolve()) for s in sources]

    rows: list[dict[str, int]] = []
    case_tags: list[str] = []

    for inj in args.inj_ppt:
        tag = f"K{args.k}_INJ{inj}"
        case_tags.append(tag)

        vvp_artifact = build_dir / f"{tag}.vvp"
        sim_out_file = build_dir / f"{tag}.sim.txt"
        dispatch_log_file = build_dir / f"{tag}.dispatch_log_d23.txt"
        verify_out_file = build_dir / f"{tag}.verify.txt"
        verify_case_dir = build_dir / f"{tag}_verify"

        print(f"[*] Running case {tag}")

        compile_cmd = [
            args.iverilog,
            "-g2012",
            "-P",
            f"tb_dispatcher_integration_d23.WORKER_LATENCY={args.k}",
            "-P",
            f"tb_dispatcher_integration_d23.INJECT_RATE_PPT={inj}",
            "-o",
            str(vvp_artifact),
            *source_paths,
        ]
        rc, out = run_cmd(compile_cmd)
        if rc != 0:
            print(out)
            print(f"ERROR: iverilog compile failed for {tag}")
            return 3

        rc, sim_out = run_cmd([args.vvp, str(vvp_artifact.name)], cwd=build_dir)
        sim_out_file.write_text(sim_out, encoding="utf-8")
        if rc != 0:
            print(sim_out)
            print(f"ERROR: vvp simulation failed for {tag}")
            return 4

        generated_log = build_dir / "dispatch_log_d23.txt"
        if not generated_log.exists():
            print(f"ERROR: Expected dispatch log missing for {tag}: {generated_log}")
            return 5
        shutil.copy2(generated_log, dispatch_log_file)

        verify_cmd = [
            sys.executable,
            str(verify_script),
            str(dispatch_log_file),
            "--mode",
            "both",
            "--worker-latency",
            str(args.k),
            "--output-dir",
            str(verify_case_dir),
        ]
        rc, verify_out = run_cmd(verify_cmd, cwd=repo_root)
        verify_out_file.write_text(verify_out, encoding="utf-8")
        if rc != 0:
            print(verify_out)
            print(f"ERROR: trace verification failed for {tag}")
            return 6

        sim_metrics = parse_sim_metrics(sim_out)
        verify_metrics = parse_verify_metrics(verify_out)

        row: dict[str, int] = {
            "worker_latency": args.k,
            "inj_ppt": inj,
            "inj_rate": inj / 1000.0,
            **sim_metrics,
            **verify_metrics,
        }
        rows.append(row)

    summary_csv = build_dir / "d23_k20_saturated_safety_summary.csv"
    write_summary_csv(rows, summary_csv)

    print(f"[*] Wrote summary CSV: {summary_csv}")

    if args.publish_deliverables:
        evidence_dir = repo_root / "deliverables" / "d23" / "safety_validation"
        evidence_dir.mkdir(parents=True, exist_ok=True)

        shutil.copy2(summary_csv, evidence_dir / summary_csv.name)
        copy_raw_evidence(build_dir, evidence_dir, case_tags)

        print(f"[*] Published evidence bundle to: {evidence_dir}")

    print("[*] Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
