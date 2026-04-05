#!/usr/bin/env python3
"""
Phase 4 Results Visualization
Generates three plots from metrics.csv:
1. Stall Rate vs Injection Rate (K-sweep curves)
2. Worker Utilization vs Injection Rate
3. Synthesis Results (Fmax reference)
"""

import csv
import matplotlib.pyplot as plt
import numpy as np
from collections import defaultdict

# Read metrics
INPUT_CSV = "build/metrics.csv"
results = []

with open(INPUT_CSV, 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        results.append({
            'K': int(row['K']),
            'injection_rate': float(row['injection_rate']),
            'run': int(row['run']),
            'stall_rate_pct': float(row['stall_rate_pct']),
            'avg_workers': float(row['avg_workers']),
            'syndromes_issued': int(row['syndromes_issued']),
            'errors': int(row['errors'])
        })

# ============================================================================
# GRAPH 1: Stall Rate vs Injection Rate (K-Sweep - PRIMARY)
# ============================================================================
fig1, ax1 = plt.subplots(figsize=(10, 6))

K_values = sorted(set(r['K'] for r in results))
colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']  # Blue, Orange, Green, Red

for K, color in zip(K_values, colors):
    K_results = [r for r in results if r['K'] == K]

    # Aggregate by injection rate: compute mean and std dev of 3 runs
    agg_data = defaultdict(list)
    for r in K_results:
        agg_data[r['injection_rate']].append(r['stall_rate_pct'])

    inj_rates = sorted(agg_data.keys())
    means = [np.mean(agg_data[rate]) for rate in inj_rates]
    stds = [np.std(agg_data[rate]) for rate in inj_rates]

    ax1.errorbar(inj_rates, means, yerr=stds, marker='o', label=f'K={K}',
                 color=color, linewidth=2, markersize=8, capsize=5)

ax1.set_xlabel('Injection Rate (syndromes/cycle)', fontsize=11, fontweight='bold')
ax1.set_ylabel('Stall Rate (%)', fontsize=11, fontweight='bold')
ax1.set_title('Dispatcher Stall Rate vs Load (K-Sweep)', fontsize=12, fontweight='bold')
ax1.grid(True, alpha=0.3)
ax1.legend(fontsize=10, loc='upper left')
ax1.set_ylim([0, 100])
ax1.set_xlim([0, 2.2])

plt.tight_layout()
plt.savefig('../deliverables/stall_vs_load_sweep.png', dpi=300, bbox_inches='tight')
print("[OK] Generated: ../deliverables/stall_vs_load_sweep.png")
plt.close(fig1)

# ============================================================================
# GRAPH 2: Worker Utilization vs Injection Rate (SECONDARY)
# ============================================================================
fig2, ax2 = plt.subplots(figsize=(10, 6))

# Aggregate worker utilization (should be independent of K, depends only on load)
agg_worker_data = defaultdict(list)
for r in results:
    agg_worker_data[r['injection_rate']].append(r['avg_workers'])

inj_rates = sorted(agg_worker_data.keys())
means = [np.mean(agg_worker_data[rate]) for rate in inj_rates]
stds = [np.std(agg_worker_data[rate]) for rate in inj_rates]

ax2.errorbar(inj_rates, means, yerr=stds, marker='s', color='#2ca02c',
             linewidth=2, markersize=8, capsize=5, label='Avg Concurrent Workers')

ax2.set_xlabel('Injection Rate (syndromes/cycle)', fontsize=11, fontweight='bold')
ax2.set_ylabel('Average Concurrent Busy Workers (out of 4)', fontsize=11, fontweight='bold')
ax2.set_title('Worker Pool Utilization vs Load', fontsize=12, fontweight='bold')
ax2.grid(True, alpha=0.3)
ax2.set_ylim([0, 4.5])
ax2.set_xlim([0, 2.2])
ax2.legend(fontsize=10)

plt.tight_layout()
plt.savefig('../deliverables/worker_utilization.png', dpi=300, bbox_inches='tight')
print("[OK] Generated: ../deliverables/worker_utilization.png")
plt.close(fig2)

# ============================================================================
# GRAPH 3: Synthesis Results (REFERENCE)
# ============================================================================
fig3, ax3 = plt.subplots(figsize=(8, 5))

# Synthesis data from Phase 4 (recorded manually from synthesis report)
synthesis_metrics = {
    'Fmax (MHz)': 127.5,
    'LUTs (%util)': 5.30,
    'FFs (%util)': 0.86,
    'BRAM': 0
}

labels = list(synthesis_metrics.keys())
values = list(synthesis_metrics.values())

# Create bars with appropriate scaling for different metrics
bars = ax3.bar(labels, values, color=['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728'],
               edgecolor='black', linewidth=1.5)

# Add value labels on bars
for bar, val in zip(bars, values):
    height = bar.get_height()
    ax3.text(bar.get_x() + bar.get_width()/2., height,
             f'{val:.2f}', ha='center', va='bottom', fontweight='bold', fontsize=11)

ax3.set_ylabel('Value', fontsize=11, fontweight='bold')
ax3.set_title('Synthesis Results (xc7z020clg484-1, Zynq-7020)', fontsize=12, fontweight='bold')
ax3.grid(True, alpha=0.3, axis='y')
ax3.set_ylim([0, max(values) * 1.2])

plt.tight_layout()
plt.savefig('../deliverables/synthesis_fmax.png', dpi=300, bbox_inches='tight')
print("[OK] Generated: ../deliverables/synthesis_fmax.png")
plt.close(fig3)

print("\n[OK] All plots generated successfully!")
