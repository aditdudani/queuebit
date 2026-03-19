#!/usr/bin/env python3
"""
Mutual Exclusion Grader for Hardware Verification

Parses chronological dispatch logs from SystemVerilog simulation and verifies
that no two active workers held overlapping 3x3 bounding box regions.
"""

import sys
from collections import defaultdict
from itertools import combinations
from pathlib import Path


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


if __name__ == "__main__":
    if len(sys.argv) > 1:
        log_file = Path(sys.argv[1])
    else:
        log_file = Path(__file__).parent / "dispatch_log.txt"

    success = verify_dispatch_log(log_file)
    sys.exit(0 if success else 1)
