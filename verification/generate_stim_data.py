#!/usr/bin/env python3
"""
Quantum Noise Generator for Hardware Verification

Generates realistic, spatially clustered quantum error coordinates using Stim.
Outputs a text file of normalized (x, y) coordinates for SystemVerilog testbench ingestion.
"""

import stim
import numpy as np
from pathlib import Path


def generate_stim_data(
    distance: int = 11,
    rounds: int = 10,
    error_rate: float = 0.001,
    min_detectors_per_shot: int = 2,
    target_valid_shots: int = 10,
    max_attempts: int = 500,
    fallback_error_rate: float = 0.005,
    output_path: Path = Path("stim_errors.txt"),
) -> None:
    """
    Generate quantum error coordinates from a rotated surface code.

    Args:
        distance: Code distance (d)
        rounds: Number of measurement rounds
        error_rate: Physical error rate (p)
        min_detectors_per_shot: Minimum triggered detectors for a valid shot
        target_valid_shots: Number of valid shots to accumulate
        max_attempts: Maximum shots before fallback
        fallback_error_rate: Higher error rate if primary yields insufficient data
        output_path: Output file path
    """
    circuit = stim.Circuit.generated(
        "surface_code:rotated_memory_z",
        distance=distance,
        rounds=rounds,
        after_clifford_depolarization=error_rate,
        after_reset_flip_probability=error_rate,
        before_measure_flip_probability=error_rate,
        before_round_data_depolarization=error_rate,
    )

    detector_coords = circuit.get_detector_coordinates()
    sampler = circuit.compile_detector_sampler()

    all_coordinates = []
    valid_shot_count = 0
    total_shots = 0
    current_error_rate = error_rate

    print(f"Generating syndrome data: d={distance}, rounds={rounds}, p={current_error_rate}")
    print(f"Target: {target_valid_shots} valid shots (>={min_detectors_per_shot} detectors each)")

    while valid_shot_count < target_valid_shots:
        batch_size = 100
        samples = sampler.sample(shots=batch_size)
        total_shots += batch_size

        for shot in samples:
            triggered_indices = np.where(shot)[0]

            if len(triggered_indices) >= min_detectors_per_shot:
                for idx in triggered_indices:
                    coords = detector_coords[idx]
                    x, y = int(coords[0]), int(coords[1])
                    all_coordinates.append((x, y))

                valid_shot_count += 1
                if valid_shot_count >= target_valid_shots:
                    break

        if total_shots >= max_attempts and valid_shot_count == 0:
            print(f"WARNING: {max_attempts} shots yielded no valid data at p={current_error_rate}")
            print(f"Falling back to p={fallback_error_rate}")

            circuit = stim.Circuit.generated(
                "surface_code:rotated_memory_z",
                distance=distance,
                rounds=rounds,
                after_clifford_depolarization=fallback_error_rate,
                after_reset_flip_probability=fallback_error_rate,
                before_measure_flip_probability=fallback_error_rate,
                before_round_data_depolarization=fallback_error_rate,
            )
            sampler = circuit.compile_detector_sampler()
            current_error_rate = fallback_error_rate
            total_shots = 0

    if not all_coordinates:
        print("ERROR: Failed to generate any valid coordinates")
        return

    coords_array = np.array(all_coordinates)
    min_x, min_y = coords_array[:, 0].min(), coords_array[:, 1].min()
    normalized = coords_array - np.array([min_x, min_y])

    with open(output_path, "w") as f:
        for x, y in normalized:
            f.write(f"{x} {y}\n")

    unique_coords = len(set(map(tuple, normalized)))
    max_x, max_y = normalized[:, 0].max(), normalized[:, 1].max()

    print(f"\nGeneration complete:")
    print(f"  Total shots sampled: {total_shots}")
    print(f"  Valid shots collected: {valid_shot_count}")
    print(f"  Total coordinates: {len(normalized)}")
    print(f"  Unique coordinates: {unique_coords}")
    print(f"  Grid bounds: X=[0, {max_x}], Y=[0, {max_y}]")
    print(f"  Output: {output_path}")


if __name__ == "__main__":
    output_file = Path(__file__).parent / "stim_errors.txt"
    generate_stim_data(output_path=output_file)
