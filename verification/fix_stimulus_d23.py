#!/usr/bin/env python3
"""
Regenerate stim_errors_d23.txt with correct coordinate scaling.

Problem: Original scaling (47/31) produced coordinates up to 47,
         exceeding d=23 grid bounds [0-46].

Solution: Scale using (46/22) for Y and (46/20) for X to fit within [0-46].

Input:  verification/stim_errors.txt (d=11 stimulus, Y range [0-22], X range [0-20])
Output: verification/stim_errors_d23.txt (d=23 stimulus, both ranges [0-46])
"""

from pathlib import Path
import sys

def scale_coordinate(coord, old_max, new_max):
    """Scale coordinate from old range [0,old_max] to new range [0,new_max]."""
    if coord < 0 or coord > old_max:
        return None
    scaled = round(coord * new_max / old_max)
    return min(scaled, new_max)  # Clamp to ensure within bounds

def main():
    input_file = Path('verification/stim_errors.txt')
    output_file = Path('verification/stim_errors_d23.txt')

    if not input_file.exists():
        print(f"❌ ERROR: {input_file} not found")
        sys.exit(1)

    print(f"📖 Reading stimulus from {input_file}...")

    # Read d=11 stimulus
    with open(input_file, 'r') as f:
        lines = f.readlines()

    # Parse and scale coordinates
    d23_syndromes = []
    errors = []

    for i, line in enumerate(lines, 1):
        line = line.strip()
        if not line:
            continue

        try:
            parts = line.split()
            if len(parts) != 2:
                errors.append(f"Line {i}: Invalid format (expected 2 values): {line}")
                continue

            x_old = int(parts[0])
            y_old = int(parts[1])

            # Scale: d=11 has X∈[0-20], Y∈[0-22] → d=23 has both ∈[0-46]
            x_new = scale_coordinate(x_old, 20, 46)
            y_new = scale_coordinate(y_old, 22, 46)

            if x_new is None or y_new is None:
                errors.append(f"Line {i}: Out of bounds ({x_old},{y_old})")
                continue

            d23_syndromes.append((x_new, y_new))

        except ValueError as e:
            errors.append(f"Line {i}: Parse error: {line}")

    if errors:
        print(f"⚠️  {len(errors)} warnings during parsing:")
        for err in errors[:5]:  # Show first 5
            print(f"   {err}")
        if len(errors) > 5:
            print(f"   ... and {len(errors)-5} more")

    # Validate scaled coordinates
    print(f"\n📊 Scaling validation:")
    print(f"   Input syndromes: {len(d23_syndromes)}")

    x_coords = [x for x, y in d23_syndromes]
    y_coords = [y for x, y in d23_syndromes]

    x_min, x_max = min(x_coords), max(x_coords)
    y_min, y_max = min(y_coords), max(y_coords)

    print(f"   X range: [{x_min}-{x_max}]")
    print(f"   Y range: [{y_min}-{y_max}]")

    # Check for out-of-bounds
    oob = [(x, y) for x, y in d23_syndromes if x < 0 or x > 46 or y < 0 or y > 46]
    if oob:
        print(f"❌ ERROR: {len(oob)} coordinates out of bounds [0-46]:")
        for x, y in oob[:5]:
            print(f"   ({x}, {y})")
        sys.exit(1)

    print(f"✅ All coordinates within [0-46]")

    # Write d=23 stimulus file
    print(f"\n📝 Writing stimulus to {output_file}...")
    with open(output_file, 'w') as f:
        for x, y in d23_syndromes:
            f.write(f"{x} {y}\n")

    print(f"✅ Wrote {len(d23_syndromes)} syndromes to {output_file}")
    print(f"\n✨ Stimulus regeneration COMPLETE")

if __name__ == '__main__':
    main()
