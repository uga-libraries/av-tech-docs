# This script was created to validate the sha256 sidecar files that were received from George Blood as part of the AAPB grant digitization
# Script creates a CSV showing results of file validation

#!/usr/bin/env python3

import hashlib
import csv
from pathlib import Path

def calculate_sha256(file_path, chunk_size=8192):
    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(chunk_size):
            sha256.update(chunk)
    return sha256.hexdigest()

def read_sidecar_hash(sidecar_path):
    # Handles formats like:
    # <hash>
    # <hash> filename
    with open(sidecar_path, "r") as f:
        return f.read().strip().split()[0]

def main():
    input_dir = input("Enter the directory containing files and .sha256 sidecars: ").strip()
    directory = Path(input_dir).expanduser()

    if not directory.exists() or not directory.is_dir():
        print("Error: That path does not exist or is not a directory.")
        return

    output_csv = directory / "sha256_validation_results.csv"
    rows = []

    # Look for MKV and WAV files
    media_files = list(directory.glob("*.mkv")) + list(directory.glob("*.wav"))

    for media_file in sorted(media_files):
        sidecar = media_file.with_suffix(media_file.suffix + ".sha256")

        if not sidecar.exists():
            rows.append([
                media_file.name,
                "",
                "Did Not Validate (Missing .sha256)",
                ""
            ])
            continue

        original_hash = read_sidecar_hash(sidecar)
        calculated_hash = calculate_sha256(media_file)

        status = (
            "Validated"
            if original_hash.lower() == calculated_hash.lower()
            else "Did Not Validate"
        )

        rows.append([
            media_file.name,
            original_hash,
            status,
            calculated_hash
        ])

    with open(output_csv, "w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow([
            "File Name",
            "Original Hash",
            "Hash Validated",
            "Calculated Hash"
        ])
        writer.writerows(rows)

    print(f"\nValidation complete.")
    print(f"Results written to: {output_csv}")

if __name__ == "__main__":
    main()
