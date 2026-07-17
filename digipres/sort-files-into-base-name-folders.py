#!/usr/bin/env python3

# The primary purpose of this script is to sort digitized audio into folders with the base object name, so that these can be batch imported into Collective Access

import re
import shutil
from pathlib import Path

def get_base_name(file_path):
    # .stem gets the filename without the extension
    name = file_path.stem 
    # Remove trailing _NN (e.g., _01, _02)
    if re.search(r'_\d{2}$', name):
        return re.sub(r'_\d{2}$', '', name)
    else:
        return name

def get_files(input_dir):
    return [
        f for f in input_dir.iterdir()
        if f.is_file()
        and not f.name.startswith('.')   # ignore .DS_Store / hidden files
    ]

def process_files(input_dir, files, dry_run=True):
    total = len(files)
    for idx, file_path in enumerate(files, start=1):
        base = get_base_name(file_path)
        dest_dir = input_dir / base
        dest = dest_dir / file_path.name

        if dest_dir.exists() and not dest_dir.is_dir():
            print(f"[{idx}/{total}] Skipping (conflict - not a directory): {dest_dir}")
            continue

        if dry_run:
            print(f"[{idx}/{total}] Would move: {file_path.name} -> {base}/")
        else:
            dest_dir.mkdir(parents=True, exist_ok=True)
            shutil.move(file_path, dest)
            print(f"[{idx}/{total}] Moved: {file_path.name} -> {base}/")

def main():
    dir_input = input("Enter the directory containing files: ").strip()
    input_dir = Path(dir_input).resolve()

    if not input_dir.is_dir():
        print("Error: Not a valid directory.")
        return

    files = get_files(input_dir)
    if not files:
        print("No valid files found.")
        return

    dry_run_input = input("Run as dry run? (y/n): ").strip().lower()
    dry_run = dry_run_input == "y"

    # First pass (dry run)
    if dry_run:
        print("\n--- DRY RUN ---")
        process_files(input_dir, files, dry_run=True)
        print("\nDry run complete.")

        run_for_real = input("Do you want to execute the moves FOR REAL? (y/n): ").strip().lower()
        if run_for_real == "y":
            print("\n--- EXECUTING ---")
            process_files(input_dir, files, dry_run=False)
        else:
            print("Exiting without moving files.")
    else:
        process_files(input_dir, files, dry_run=False)

    print("\nDone.")

if __name__ == "__main__":
    main()