# This script was created to fix the audio filenames for digital files received from George Blood via the AAPB Digitization in 2025
# BMA naming practice is to only use the suffix _01 if an _02 exists
# Files received from GB use _01 even when it's the only file
# This script checks for an _02, and if none exists, removes the _01
# Script creates a CSV change log

import os
import csv
from collections import defaultdict

# 👇 Configure allowed extensions here
VALID_EXTENSIONS = (".wav", ".mp3")


def get_safe_filename(directory, filename):
    """
    Prevent overwriting by appending _v2, _v3, etc. if needed
    """
    base, ext = os.path.splitext(filename)
    counter = 2
    new_filename = filename

    while os.path.exists(os.path.join(directory, new_filename)):
        new_filename = f"{base}_v{counter}{ext}"
        counter += 1

    return new_filename


def build_csv_path(input_dir, extensions):
    """
    Build CSV path using:
    parent directory name (HD name) + extensions present
    """
    parent_dir = os.path.dirname(input_dir)
    hd_name = os.path.basename(parent_dir)

    ext_list = sorted(set(ext.lower().lstrip('.') for ext in extensions))
    ext_part = "-".join(ext_list) if ext_list else "unknown"

    csv_name = f"{hd_name}_{ext_part}-audio-suffix-rename.csv"
    return os.path.join(parent_dir, csv_name)


def process_files(directory, csv_path=None, dry_run=True):
    groups = defaultdict(list)
    log_rows = []
    extensions_found = set()

    # 🔍 Scan directory
    for filename in os.listdir(directory):
        if not filename.lower().endswith(VALID_EXTENSIONS):
            continue

        name, ext = os.path.splitext(filename)
        extensions_found.add(ext)

        if name.endswith("_01") or name.endswith("_02"):
            base = name[:-3]
            suffix = name[-3:]
            groups[(base, ext)].append((filename, suffix, ext))

    # ⚙️ Process groups
    for (base, ext), files in groups.items():
        suffixes = [s for _, s, _ in files]

        # Only _01 exists → rename
        if "_01" in suffixes and "_02" not in suffixes:
            for filename, suffix, ext in files:
                if suffix == "_01":
                    new_name = base + ext
                    safe_name = get_safe_filename(directory, new_name)

                    if dry_run:
                        print(f"{filename} -> {safe_name}")
                    else:
                        print(f"Renaming {filename} -> {safe_name}")
                        os.rename(
                            os.path.join(directory, filename),
                            os.path.join(directory, safe_name)
                        )

                    log_rows.append([filename, safe_name, "RENAME"])

        # Both exist OR only _02 → no rename
        else:
            for filename, _, _ in files:
                if dry_run:
                    print(f"{filename} -> NOT RENAMED")
                log_rows.append([filename, filename, "UNCHANGED"])

    # 📄 Write CSV (only on real run)
    if csv_path:
        with open(csv_path, "w", newline="") as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(["original_filename", "new_filename", "action"])
            writer.writerows(log_rows)

        print(f"\nCSV log written to: {csv_path}")

    return extensions_found


if __name__ == "__main__":
    folder = input("Enter directory path: ").strip()

    print("\n--- DRY RUN ---\n")
    extensions = process_files(folder, csv_path=None, dry_run=True)

    csv_output = build_csv_path(folder, extensions)

    print(f"\nCSV will be written to:\n{csv_output}\n")

    confirm = input("Proceed with actual renaming? (y/n): ").lower()

    if confirm == "y":
        process_files(folder, csv_output, dry_run=False)
    else:
        print("No changes made.")
