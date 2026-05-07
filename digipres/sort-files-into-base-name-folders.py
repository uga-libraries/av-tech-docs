# The primary purpose of this script is to sort digitized audio into folders with the base object name, so that these can be batch imported into Collective Access


#!/usr/bin/env python3

import os
import shutil
import re

def get_base_name(filename):
    name, ext = os.path.splitext(filename)
    # Remove trailing _NN (e.g., _01, _02)
    if re.search(r'_\d{2}$', name):
        return re.sub(r'_\d{2}$', '', name)
    else:
        return name

def get_files(input_dir):
    return [
        f for f in os.listdir(input_dir)
        if os.path.isfile(os.path.join(input_dir, f))
        and not f.startswith('.')   # ignore .DS_Store / hidden files
    ]

def process_files(input_dir, files, dry_run=True):
    total = len(files)
    for idx, file in enumerate(files, start=1):
        base = get_base_name(file)
        src = os.path.join(input_dir, file)
        dest_dir = os.path.join(input_dir, base)
        dest = os.path.join(dest_dir, file)

        if os.path.exists(dest_dir) and not os.path.isdir(dest_dir):
            print(f"[{idx}/{total}] Skipping (conflict - not a directory): {dest_dir}")
            continue

        if dry_run:
            print(f"[{idx}/{total}] Would move: {file} -> {base}/")
        else:
            os.makedirs(dest_dir, exist_ok=True)
            shutil.move(src, dest)
            print(f"[{idx}/{total}] Moved: {file} -> {base}/")

def main():
    input_dir = input("Enter the directory containing files: ").strip()
    if not os.path.isdir(input_dir):
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
