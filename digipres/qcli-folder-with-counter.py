# Multipurpose script to create QCTools reports for an entire folder of files. The primary benefit of using this script is that it includes a counter to show progress.

#!/usr/bin/env python3

import os
import subprocess
from pathlib import Path

def main():
    folder_input = input("Enter path to folder containing MKV files: ").strip()
    folder = Path(folder_input).expanduser().resolve()

    if not folder.exists() or not folder.is_dir():
        print("Invalid folder path.")
        return

    mkv_files = sorted(folder.glob("*.mkv"))
    total = len(mkv_files)

    if total == 0:
        print("No MKV files found in that folder.")
        return

    print(f"Found {total} MKV files.\n")

    for count, file_path in enumerate(mkv_files, start=1):
        print(f"Working on file {count} of {total}: {file_path.name}")
        subprocess.run(["qcli", "-i", str(file_path)])

    print("\nDone.")

if __name__ == "__main__":
    main()
