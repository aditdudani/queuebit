#!/usr/bin/env python3
"""
Extract area, timing, and power metrics from Vivado synthesis reports.

Input:  Vivado-generated reports (build_d23/):
        - timing_report.txt (from report_timing_summary)
        - utilization_report.txt (from report_utilization)
        - power_report.txt (from report_power)

Output: Console summary + build_d23/synthesis_metrics.txt

Parses key metrics for paper:
- LUT utilization (used / available)
- Flip-flop utilization
- DSP and BRAM counts
- Fmax (maximum clock frequency)
- Timing slack (setup/hold margins)
- Power dissipation @ nominal frequency
"""

import re
from pathlib import Path
import sys

def extract_timing_metrics(report_path):
    """Extract Fmax, setup slack, hold slack from timing_report.txt"""
    metrics = {
        'fmax_mhz': None,
        'setup_slack_ns': None,
        'hold_slack_ns': None
    }

    if not report_path.exists():
        print(f"⚠️  WARNING: Timing report not found: {report_path}")
        return metrics

    try:
        with open(report_path, 'r') as f:
            content = f.read()

        # Look for "Design Timing Summary" or similar section
        # Vivado format varies; look for common patterns

        # Pattern 1: "Fmax (MHz): X.XXX"
        fmax_match = re.search(r'Fmax.*?:\s*([\d.]+)\s*MHz', content, re.IGNORECASE)
        if fmax_match:
            metrics['fmax_mhz'] = float(fmax_match.group(1))

        # Pattern 2: "Setup Slack" or "WNS"
        setup_match = re.search(r'(?:Setup Slack|WNS).*?:\s*([-\d.]+)', content, re.IGNORECASE)
        if setup_match:
            metrics['setup_slack_ns'] = float(setup_match.group(1))

        # Pattern 3: "Hold Slack"
        hold_match = re.search(r'Hold Slack.*?:\s*([-\d.]+)', content, re.IGNORECASE)
        if hold_match:
            metrics['hold_slack_ns'] = float(hold_match.group(1))

    except Exception as e:
        print(f"⚠️  ERROR parsing timing report: {e}", file=sys.stderr)

    return metrics


def extract_area_metrics(report_path):
    """Extract LUT, FF, DSP, BRAM from utilization_report.txt"""
    metrics = {
        'lut_used': None,
        'lut_total': None,
        'lut_pct': None,
        'ff_used': None,
        'ff_total': None,
        'ff_pct': None,
        'dsp_used': None,
        'dsp_total': None,
        'dsp_pct': None,
        'bram_used': None,
        'bram_total': None,
        'bram_pct': None
    }

    if not report_path.exists():
        print(f"⚠️  WARNING: Utilization report not found: {report_path}")
        return metrics

    try:
        with open(report_path, 'r') as f:
            lines = f.readlines()

        for i, line in enumerate(lines):
            # Look for resource utilization table rows
            # Vivado format: "Resource | Used | Available | Utilization %"

            if 'Slice LUTs' in line or 'LUT' in line:
                # Try to parse: "X | Y | Z%" pattern
                parts = re.split(r'\|', line)
                if len(parts) >= 3:
                    try:
                        used = int(parts[1].strip())
                        total = int(parts[2].strip())
                        metrics['lut_used'] = used
                        metrics['lut_total'] = total
                        metrics['lut_pct'] = f"{100*used/total:.1f}" if total > 0 else "0"
                    except ValueError:
                        pass

            elif 'Slice Registers' in line or 'FF' in line or 'Registers' in line:
                parts = re.split(r'\|', line)
                if len(parts) >= 3:
                    try:
                        used = int(parts[1].strip())
                        total = int(parts[2].strip())
                        metrics['ff_used'] = used
                        metrics['ff_total'] = total
                        metrics['ff_pct'] = f"{100*used/total:.1f}" if total > 0 else "0"
                    except ValueError:
                        pass

            elif 'DSP' in line:
                parts = re.split(r'\|', line)
                if len(parts) >= 3:
                    try:
                        used = int(parts[1].strip())
                        total = int(parts[2].strip())
                        metrics['dsp_used'] = used
                        metrics['dsp_total'] = total
                        metrics['dsp_pct'] = f"{100*used/total:.1f}" if total > 0 else "0"
                    except ValueError:
                        pass

            elif 'BRAM' in line or 'Block RAM' in line:
                parts = re.split(r'\|', line)
                if len(parts) >= 3:
                    try:
                        used = int(parts[1].strip())
                        total = int(parts[2].strip())
                        metrics['bram_used'] = used
                        metrics['bram_total'] = total
                        metrics['bram_pct'] = f"{100*used/total:.1f}" if total > 0 else "0"
                    except ValueError:
                        pass

    except Exception as e:
        print(f"⚠️  ERROR parsing utilization report: {e}", file=sys.stderr)

    return metrics


def extract_power_metrics(report_path):
    """Extract power dissipation from power_report.txt"""
    metrics = {
        'total_power_mw': None,
        'dynamic_power_mw': None,
        'static_power_mw': None
    }

    if not report_path.exists():
        print(f"⚠️  WARNING: Power report not found: {report_path}")
        return metrics

    try:
        with open(report_path, 'r') as f:
            content = f.read()

        # Look for power summary lines (Vivado format)
        # "Total On-Chip Power: X.XXX W"

        total_match = re.search(r'Total On-Chip Power.*?:\s*([\d.]+)\s*W', content, re.IGNORECASE)
        if total_match:
            metrics['total_power_mw'] = float(total_match.group(1)) * 1000  # Convert W to mW

        dynamic_match = re.search(r'Dynamic.*?:\s*([\d.]+)\s*W', content, re.IGNORECASE)
        if dynamic_match:
            metrics['dynamic_power_mw'] = float(dynamic_match.group(1)) * 1000

        static_match = re.search(r'Static.*?:\s*([\d.]+)\s*W', content, re.IGNORECASE)
        if static_match:
            metrics['static_power_mw'] = float(static_match.group(1)) * 1000

    except Exception as e:
        print(f"⚠️  ERROR parsing power report: {e}", file=sys.stderr)

    return metrics


def main():
    report_dir = Path('build_d23')

    if not report_dir.exists():
        print(f"❌ ERROR: Report directory not found: {report_dir}")
        print("   Run synthesis: vivado -mode batch -source synthesize_d23.tcl")
        sys.exit(1)

    print("📊 Extracting Vivado synthesis metrics...")
    print()

    # Extract all metrics
    timing = extract_timing_metrics(report_dir / 'timing_report.txt')
    area = extract_area_metrics(report_dir / 'utilization_report.txt')
    power = extract_power_metrics(report_dir / 'power_report.txt')

    # Print results
    print("="*80)
    print("d=23 DISPATCHER SYNTHESIS RESULTS (XC7Z020)")
    print("="*80)

    print("\n[TIMING]")
    if timing['fmax_mhz']:
        print(f"  Fmax: {timing['fmax_mhz']:.1f} MHz")
    else:
        print(f"  Fmax: NOT FOUND in timing_report.txt")

    if timing['setup_slack_ns'] is not None:
        status = "✅ PASS" if timing['setup_slack_ns'] >= 0 else "❌ FAIL"
        print(f"  Setup Slack: {timing['setup_slack_ns']:+.3f} ns {status}")
    else:
        print(f"  Setup Slack: NOT FOUND")

    if timing['hold_slack_ns'] is not None:
        status = "✅ PASS" if timing['hold_slack_ns'] >= 0 else "❌ FAIL"
        print(f"  Hold Slack: {timing['hold_slack_ns']:+.3f} ns {status}")
    else:
        print(f"  Hold Slack: NOT FOUND")

    print("\n[AREA]")
    if area['lut_used'] and area['lut_total']:
        print(f"  LUT: {area['lut_used']} / {area['lut_total']} ({area['lut_pct']}%)")
    else:
        print(f"  LUT: NOT FOUND")

    if area['ff_used'] and area['ff_total']:
        print(f"  Flip-Flops: {area['ff_used']} / {area['ff_total']} ({area['ff_pct']}%)")
    else:
        print(f"  Flip-Flops: NOT FOUND")

    if area['dsp_used'] is not None and area['dsp_total']:
        print(f"  DSP: {area['dsp_used']} / {area['dsp_total']} ({area['dsp_pct']}%)")
    else:
        print(f"  DSP: NOT FOUND")

    if area['bram_used'] is not None and area['bram_total']:
        print(f"  BRAM: {area['bram_used']} / {area['bram_total']} ({area['bram_pct']}%)")
    else:
        print(f"  BRAM: NOT FOUND")

    print("\n[POWER]")
    if power['total_power_mw']:
        print(f"  Total On-Chip Power: {power['total_power_mw']:.1f} mW")
    else:
        print(f"  Total Power: NOT FOUND")

    if power['dynamic_power_mw']:
        print(f"  Dynamic Power: {power['dynamic_power_mw']:.1f} mW")

    if power['static_power_mw']:
        print(f"  Static Power: {power['static_power_mw']:.1f} mW")

    print("\n" + "="*80)

    # Write to file for paper records
    out_file = report_dir / 'synthesis_metrics.txt'
    try:
        with open(out_file, 'w') as f:
            f.write("d=23 DISPATCHER SYNTHESIS METRICS\n")
            f.write("="*80 + "\n\n")
            f.write(f"Fmax (MHz): {timing['fmax_mhz']}\n")
            f.write(f"Setup Slack (ns): {timing['setup_slack_ns']}\n")
            f.write(f"Hold Slack (ns): {timing['hold_slack_ns']}\n\n")
            f.write(f"LUT Used: {area['lut_used']} / {area['lut_total']} ({area['lut_pct']}%)\n")
            f.write(f"FF Used: {area['ff_used']} / {area['ff_total']} ({area['ff_pct']}%)\n")
            f.write(f"DSP Used: {area['dsp_used']} / {area['dsp_total']} ({area['dsp_pct']}%)\n")
            f.write(f"BRAM Used: {area['bram_used']} / {area['bram_total']} ({area['bram_pct']}%)\n\n")
            f.write(f"Total Power (mW): {power['total_power_mw']}\n")
            f.write(f"Dynamic Power (mW): {power['dynamic_power_mw']}\n")
            f.write(f"Static Power (mW): {power['static_power_mw']}\n")
        print(f"✅ Metrics saved to {out_file}")
    except Exception as e:
        print(f"⚠️  ERROR writing metrics file: {e}", file=sys.stderr)


if __name__ == '__main__':
    main()
