#!/usr/bin/env python3
"""
Dispatch Log Analyzer for Hardware Verification

Parses chronological dispatch logs from SystemVerilog simulation and verifies:
1. No two workers held overlapping 3x3 bounding box regions (collision check)
2. Statistics on spatial separation of concurrent syndrome pairs (separation analysis)

Supports multiple analysis modes:
  --mode collision   : Collision verification only
  --mode separation  : Separation statistics only
  --mode both        : Both analyses (default)
"""

import sys
import argparse
from collections import defaultdict
from itertools import combinations
from pathlib import Path
from statistics import mean, stdev


def chebyshev_distance(coord1: tuple[int, int], coord2: tuple[int, int]) -> int:
    """Calculate Chebyshev (chessboard) distance between two coordinates."""
    return max(abs(coord1[0] - coord2[0]), abs(coord1[1] - coord2[1]))


def check_collision(active_coords: set[tuple[int, int]], cycle: int) -> tuple[bool, str]:
    """
    Check for spatial collisions among all active coordinates.

    Two coordinates collide if their 3x3 bounding boxes overlap,
    which occurs when Chebyshev distance <= 2.

    Args:
        active_coords: Set of currently locked (x, y) coordinates
        cycle: Current clock cycle for error reporting

    Returns:
        (collision_found, error_message)
    """
    if len(active_coords) < 2:
        return False, ""

    for (x1, y1), (x2, y2) in combinations(active_coords, 2):
        dist = chebyshev_distance((x1, y1), (x2, y2))
        if dist <= 2:
            return True, (
                f"FAIL: Spatial collision detected at Clock {cycle} "
                f"between ({x1},{y1}) and ({x2},{y2}). "
                f"Chebyshev distance = {dist}"
            )

    return False, ""


def verify_dispatch_log(log_path: Path) -> bool:
    """
    Parse and verify the dispatch log for spatial mutual exclusion.

    Expected log format: [ClockCycle] [Action] [WorkerID] [X] [Y]
    Actions: LOCK or RELEASE

    Args:
        log_path: Path to dispatch_log.txt

    Returns:
        True if verification passed, False if collision detected
    """
    if not log_path.exists():
        print(f"ERROR: Log file not found: {log_path}")
        return False

    cycle_events = defaultdict(lambda: {"locks": [], "releases": []})

    with open(log_path, "r") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue

            parts = line.split()
            if len(parts) != 5:
                print(f"WARNING: Malformed line {line_num}: {line}")
                continue

            try:
                cycle = int(parts[0])
                action = parts[1].upper()
                worker_id = int(parts[2])
                x = int(parts[3])
                y = int(parts[4])
            except ValueError as e:
                print(f"WARNING: Parse error on line {line_num}: {e}")
                continue

            if action == "LOCK":
                cycle_events[cycle]["locks"].append((x, y, worker_id))
            elif action == "RELEASE":
                cycle_events[cycle]["releases"].append((x, y, worker_id))
            else:
                print(f"WARNING: Unknown action '{action}' on line {line_num}")

    active_coords: set[tuple[int, int]] = set()
    total_locks = 0
    total_releases = 0
    peak_concurrent = 0
    spurious_releases = 0

    for cycle in sorted(cycle_events.keys()):
        events = cycle_events[cycle]

        for x, y, worker_id in events["releases"]:
            coord = (x, y)
            if coord in active_coords:
                active_coords.remove(coord)
                total_releases += 1
            else:
                spurious_releases += 1

        for x, y, worker_id in events["locks"]:
            coord = (x, y)
            if coord in active_coords:
                print(
                    f"WARNING: Duplicate lock at cycle {cycle} for ({x},{y}) by Worker {worker_id}"
                )
            active_coords.add(coord)
            total_locks += 1

        peak_concurrent = max(peak_concurrent, len(active_coords))

        collision, error_msg = check_collision(active_coords, cycle)
        if collision:
            print(error_msg)
            return False

    if active_coords:
        print(f"WARNING: {len(active_coords)} coordinates still locked at end of simulation:")
        for coord in sorted(active_coords):
            print(f"  ({coord[0]},{coord[1]})")

    print(f"\nSUCCESS: 0 Spatial Collisions Detected. Routing integrity verified.")
    print(f"  Total LOCK events: {total_locks}")
    print(f"  Total RELEASE events: {total_releases}")
    print(f"  Peak concurrent locks: {peak_concurrent}")
    if spurious_releases > 0:
        print(f"  Spurious releases (no matching lock): {spurious_releases}")

    return True


def extract_syndrome_separation(log_path: Path, worker_latency: int = 5) -> dict:
    """
    Extract syndrome separation statistics from dispatch log.

    Identifies all concurrent syndrome pairs (locks with overlapping time windows)
    and measures their Chebyshev distances.

    Args:
        log_path: Path to dispatch_log.txt
        worker_latency: K (lock-hold duration in cycles, default 5)

    Returns:
        Dict with keys:
          - total_pairs: Number of concurrent syndrome pairs
          - safe_pairs: Pairs with Chebyshev distance > 2
          - unsafe_pairs: Pairs with Chebyshev distance <= 2
          - distances: List of all measured distances
          - pairs: List of dicts with details on each pair
    """
    if not log_path.exists():
        print(f"ERROR: Log file not found: {log_path}")
        return {}

    # Parse events from log
    events = []
    with open(log_path, "r") as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) != 5:
                continue
            try:
                cycle = int(parts[0])
                action = parts[1].upper()
                worker_id = int(parts[2])
                x = int(parts[3])
                y = int(parts[4])

                if action in ["LOCK", "RELEASE"]:
                    events.append({
                        'cycle': cycle,
                        'action': action,
                        'worker_id': worker_id,
                        'coord': (x, y)
                    })
            except ValueError:
                continue

    # Extract lock-hold windows for each worker
    worker_locks = defaultdict(list)
    for event in events:
        if event['action'] == 'LOCK':
            worker_id = event['worker_id']
            t_lock = event['cycle']
            t_release = t_lock + worker_latency
            coord = event['coord']

            worker_locks[worker_id].append({
                'cycle_lock': t_lock,
                'cycle_release': t_release,
                'coord': coord
            })

    # Find concurrent pairs
    concurrent_pairs = []
    for w1 in sorted(worker_locks.keys()):
        for lock1 in worker_locks[w1]:
            for w2 in sorted(worker_locks.keys()):
                if w2 <= w1:
                    continue  # Avoid duplicates
                for lock2 in worker_locks[w2]:
                    # Check time overlap: [t1_start, t1_end) overlaps with [t2_start, t2_end)
                    t1_start, t1_end = lock1['cycle_lock'], lock1['cycle_release']
                    t2_start, t2_end = lock2['cycle_lock'], lock2['cycle_release']

                    if t1_start < t2_end and t2_start < t1_end:
                        # Locks overlap in time
                        dist = chebyshev_distance(lock1['coord'], lock2['coord'])
                        concurrent_pairs.append({
                            'cycle_lock_1': t1_start,
                            'worker_1': w1,
                            'coord_1': lock1['coord'],
                            'cycle_lock_2': t2_start,
                            'worker_2': w2,
                            'coord_2': lock2['coord'],
                            'chebyshev_distance': dist,
                            'safe': dist > 2
                        })

    # Analyze results
    safe_count = sum(1 for p in concurrent_pairs if p['safe'])
    unsafe_count = len(concurrent_pairs) - safe_count
    distances = [p['chebyshev_distance'] for p in concurrent_pairs]

    return {
        'total_pairs': len(concurrent_pairs),
        'safe_pairs': safe_count,
        'unsafe_pairs': unsafe_count,
        'distances': distances,
        'pairs': concurrent_pairs,
        'worker_latency': worker_latency
    }


def write_separation_report(log_path: Path, output_dir: Path, analysis: dict) -> None:
    """
    Write separation analysis report to file.

    Args:
        log_path: Path to dispatch_log.txt (for reference)
        output_dir: Directory to write reports to
        analysis: Result dict from extract_syndrome_separation()
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "syndrome_separation_log.txt"

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("="*100 + "\n")
        f.write("SYNDROME SEPARATION ANALYSIS\n")
        f.write("="*100 + "\n\n")

        f.write(f"Dispatch Log: {log_path}\n")
        f.write(f"Worker Latency (K): {analysis['worker_latency']} cycles\n\n")

        f.write("[SUMMARY]\n")
        f.write(f"  Total concurrent syndrome pairs: {analysis['total_pairs']}\n")
        f.write(f"  Safe pairs (Chebyshev distance > 2): {analysis['safe_pairs']}\n")
        f.write(f"  Unsafe pairs (Chebyshev distance <= 2): {analysis['unsafe_pairs']}\n")

        if analysis['unsafe_pairs'] == 0:
            f.write(f"\n  [PASS] 0 spatial collisions detected\n")
        else:
            f.write(f"\n  [FAIL] {analysis['unsafe_pairs']} spatial collisions detected\n")

        if analysis['distances']:
            distances = analysis['distances']
            f.write(f"\n[DISTANCE STATISTICS]\n")
            f.write(f"  Min distance: {min(distances)}\n")
            f.write(f"  Max distance: {max(distances)}\n")
            f.write(f"  Mean distance: {mean(distances):.2f}\n")
            if len(distances) > 1:
                f.write(f"  Std dev: {stdev(distances):.2f}\n")

        f.write("\n" + "="*100 + "\n")
        f.write("DETAILED CONCURRENT PAIRS\n")
        f.write("="*100 + "\n\n")

        for i, pair in enumerate(analysis['pairs'], 1):
            status = "[SAFE]" if pair['safe'] else "[FAIL]"
            f.write(f"Pair {i}: {status}\n")
            f.write(f"  Worker {pair['worker_1']} @ cycle {pair['cycle_lock_1']}: {pair['coord_1']}\n")
            f.write(f"  Worker {pair['worker_2']} @ cycle {pair['cycle_lock_2']}: {pair['coord_2']}\n")
            f.write(f"  Chebyshev distance: {pair['chebyshev_distance']}\n")
            f.write("\n")

    print(f"[*] Separation report written to {output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Dispatch log analyzer: collision detection and separation statistics"
    )
    parser.add_argument(
        "log_file",
        nargs="?",
        default=None,
        help="Path to dispatch_log.txt (default: verification/dispatch_log.txt)"
    )
    parser.add_argument(
        "--mode",
        choices=["collision", "separation", "both"],
        default="both",
        help="Analysis mode: collision only, separation only, or both (default: both)"
    )
    parser.add_argument(
        "--worker-latency",
        type=int,
        default=5,
        help="Worker latency K in cycles (default: 5)"
    )
    parser.add_argument(
        "--output-dir",
        default=None,
        help="Output directory for reports (default: build/)"
    )

    args = parser.parse_args()

    # Resolve log file path
    if args.log_file:
        log_file = Path(args.log_file)
    else:
        log_file = Path(__file__).parent / "dispatch_log.txt"
        # Try build directory as fallback
        if not log_file.exists():
            log_file = Path(__file__).parent.parent / "build" / "dispatch_log.txt"

    # Resolve output directory
    if args.output_dir:
        output_dir = Path(args.output_dir)
    else:
        output_dir = Path(__file__).parent.parent / "build"

    print(f"[*] Analyzing dispatch log: {log_file}")

    # Run requested analyses
    success = True

    if args.mode in ["collision", "both"]:
        print("[*] Mode: COLLISION DETECTION")
        collision_success = verify_dispatch_log(log_file)
        if not collision_success:
            success = False

    if args.mode in ["separation", "both"]:
        print("[*] Mode: SEPARATION ANALYSIS")
        analysis = extract_syndrome_separation(log_file, args.worker_latency)
        if analysis:
            print(f"[*] Found {analysis['total_pairs']} concurrent syndrome pairs")
            print(f"[*] Safe pairs: {analysis['safe_pairs']}, Unsafe pairs: {analysis['unsafe_pairs']}")
            write_separation_report(log_file, output_dir, analysis)
            if analysis['unsafe_pairs'] > 0:
                success = False

    sys.exit(0 if success else 1)
