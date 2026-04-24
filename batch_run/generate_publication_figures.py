#!/usr/bin/env python3
"""
Generate paper-oriented figures from the corrected d=11 and d=23 results.

Outputs are written to deliverables/figures/.
The script uses only simulation results. Synthesis should be presented as a
table in the paper, not as a mixed-unit figure.
"""

import csv
from collections import defaultdict
from pathlib import Path

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parent.parent
D11_CSV = ROOT / "batch_run" / "build" / "metrics.csv"
D23_CSV = ROOT / "batch_run" / "build_d23" / "k_sweep_results.csv"
OUT_DIR = ROOT / "deliverables" / "figures"


def load_d11_results(path: Path) -> list[dict]:
    rows = []
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            rows.append(
                {
                    "K": int(row["K"]),
                    "injection_rate": float(row["injection_rate"]),
                    "cycles": float(row["cycles"]),
                    "stall_fraction_runtime": (float(row["stall_cycles"]) / float(row["cycles"])) * 100.0,
                    "avg_workers": float(row["avg_workers"]),
                }
            )
    return rows


def load_d23_results(path: Path) -> list[dict]:
    rows = []
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            rows.append(
                {
                    "K": int(row["K"]),
                    "injection_rate": float(row["Injection_Rate"]),
                    "cycles": float(row["Avg_Cycles"]),
                    "stall_fraction_runtime": (float(row["Avg_Stalled"]) / float(row["Avg_Cycles"])) * 100.0,
                    "hazard_detections": float(row["Avg_Collisions"]),
                }
            )
    return rows


def aggregate(rows: list[dict], value_key: str) -> dict[int, dict[float, float]]:
    out: dict[int, dict[float, list[float]]] = defaultdict(lambda: defaultdict(list))
    for row in rows:
        out[row["K"]][row["injection_rate"]].append(row[value_key])
    return {
        k: {inj: sum(vals) / len(vals) for inj, vals in inj_map.items()}
        for k, inj_map in out.items()
    }


def style_axes(ax, xlabel: str, ylabel: str, title: str) -> None:
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.grid(True, alpha=0.25)


def make_distance_comparison_figure(
    d11_rows: list[dict], d23_rows: list[dict], value_key: str, ylabel: str, title: str, filename: str
) -> None:
    d11 = aggregate(d11_rows, value_key)
    d23 = aggregate(d23_rows, value_key)
    colors = {5: "#1b9e77", 10: "#d95f02", 15: "#7570b3", 20: "#e7298a"}

    fig, axes = plt.subplots(1, 2, figsize=(11, 4.6), sharex=True)

    for ax, dataset, label in zip(axes, [d11, d23], ["d=11", "d=23"]):
        for k in sorted(dataset):
            inj_rates = sorted(dataset[k])
            values = [dataset[k][inj] for inj in inj_rates]
            ax.plot(inj_rates, values, marker="o", linewidth=2, markersize=5, color=colors[k], label=f"K={k}")
        style_axes(ax, "Injection rate (syndromes/cycle)", ylabel, label)
        ax.set_xlim(0.05, 2.05)
        ax.legend(frameon=False, fontsize=9)

    fig.suptitle(title)
    fig.tight_layout()
    fig.savefig(OUT_DIR / filename, dpi=300, bbox_inches="tight")
    plt.close(fig)


def make_d23_collision_figure(d23_rows: list[dict]) -> None:
    d23 = aggregate(d23_rows, "hazard_detections")
    colors = {5: "#1b9e77", 10: "#d95f02", 15: "#7570b3", 20: "#e7298a"}

    fig, ax = plt.subplots(figsize=(6.4, 4.6))
    for k in sorted(d23):
        inj_rates = sorted(d23[k])
        collisions = [d23[k][inj] for inj in inj_rates]
        ax.plot(inj_rates, collisions, marker="o", linewidth=2, markersize=5, color=colors[k], label=f"K={k}")

    style_axes(
        ax,
        "Injection rate (syndromes/cycle)",
        "Average hazard detections",
        "d=23 hazard detections versus offered load",
    )
    ax.set_xlim(0.05, 2.05)
    ax.legend(frameon=False, fontsize=9)
    fig.tight_layout()
    fig.savefig(OUT_DIR / "figure_d23_collisions.png", dpi=300, bbox_inches="tight")
    plt.close(fig)


def write_summary_table(d11_rows: list[dict], d23_rows: list[dict]) -> None:
    d11_cycles = aggregate(d11_rows, "cycles")
    d11_stall = aggregate(d11_rows, "stall_fraction_runtime")
    d23_cycles = aggregate(d23_rows, "cycles")
    d23_stall = aggregate(d23_rows, "stall_fraction_runtime")

    out_path = OUT_DIR / "paper_results_summary.csv"
    with out_path.open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "distance",
                "K",
                "inj_0.1_cycles",
                "inj_1.0_cycles",
                "inj_0.1_stall_fraction_runtime_pct",
                "inj_1.0_stall_fraction_runtime_pct",
            ]
        )
        for distance, cycles, stall in [("d11", d11_cycles, d11_stall), ("d23", d23_cycles, d23_stall)]:
            for k in sorted(cycles):
                writer.writerow(
                    [
                        distance,
                        k,
                        f"{cycles[k][0.1]:.1f}",
                        f"{cycles[k][1.0]:.1f}",
                        f"{stall[k][0.1]:.2f}",
                        f"{stall[k][1.0]:.2f}",
                    ]
                )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    d11_rows = load_d11_results(D11_CSV)
    d23_rows = load_d23_results(D23_CSV)

    make_distance_comparison_figure(
        d11_rows,
        d23_rows,
        "cycles",
        "Average total cycles",
        "Runtime versus offered load across d=11 and d=23",
        "figure_cycles_distance_comparison.png",
    )
    make_distance_comparison_figure(
        d11_rows,
        d23_rows,
        "stall_fraction_runtime",
        "Stall fraction of runtime (%)",
        "Stall fraction versus offered load across d=11 and d=23",
        "figure_stall_distance_comparison.png",
    )
    make_d23_collision_figure(d23_rows)
    write_summary_table(d11_rows, d23_rows)

    print(f"Paper figures written to {OUT_DIR}")


if __name__ == "__main__":
    main()
