# Script to copy MOV mezzanine files from film scanner RAID to a DPHub share
# Script confirms presence of md5 sidecar, copies file, verifies md5, and creates mediainfo XML (to be used in creating digital object records for CA)
# Script also creates a CSV report showing size of files and confirming whether they were successfully transferred
# After transfer, files are moved to a subfolder, which can then be deleted by user

import csv
import hashlib
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

# Look up one level to find config.py in the av-tech-docs root directory
script_dir = Path(__file__).resolve().parent 
project_root = script_dir.parent              

if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

# --- CONFIGURATION (Loaded from config.py) ---
from config import get_path_list, require_path

# 1. Reads servers as a comma-separated list of Path objects directly from the environment
MEZZ_SERVERS = get_path_list("MEZZ_SERVERS")

# 2. Reads MediaInfo base path (Aligned with LOCAL_MEDIAINFO_DIR from your .env template)
LOCAL_MEDIAINFO_DIR = require_path("LOCAL_MEDIAINFO_DIR")


def calculate_md5(filepath: Path):
    hash_md5 = hashlib.md5()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


def get_size_format(b):
    for unit in ["", "K", "M", "G", "T"]:
        if b < 1024:
            return f"{b:.2f}{unit}B"
        b /= 1024
    return f"{b:.2f}PB"


def update_csv_status(csv_path: Path, filename, status_val):
    rows = []
    with open(csv_path, "r", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            if row["Filename"] == filename:
                row["TransferConfirmed"] = status_val
            rows.append(row)
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main():
    # Capture the start date immediately for consistent folder naming
    start_date_str = date.today().strftime("%Y-%m-%d")

    # 1. Accept input directory
    input_dir_str = input("Enter input directory path: ").strip()
    input_dir = Path(input_dir_str)

    if not input_dir.is_dir():
        print("Error: Invalid directory.")
        return

    # Gathering MOV files as actual Path objects makes everything downstream cleaner
    mov_files = [
        f
        for f in input_dir.iterdir()
        if f.is_file() and f.suffix.lower() == ".mov"
    ]
    if not mov_files:
        print("No MOV files found.")
        return

    # 2. Batch MD5 Creation
    missing_md5s = [
        m for m in mov_files if not m.with_name(f"{m.name}.md5").exists()
    ]
    if missing_md5s:
        print(f"\n[!] Found {len(missing_md5s)} files missing MD5 sidecars.")
        if input("Generate all? (y/n): ").lower() == "y":
            for mov in missing_md5s:
                print(f"Generating MD5 for {mov.name}...")
                val = calculate_md5(mov)
                md5_path = mov.with_name(f"{mov.name}.md5")
                with open(md5_path, "w") as f:
                    f.write(f"{val}  {mov.name}")

    # 3. MediaInfo
    dated_mediainfo_dir = (
        LOCAL_MEDIAINFO_DIR / f"{start_date_str}_film-scan-movs"
    )
    dated_mediainfo_dir.mkdir(parents=True, exist_ok=True)
    print("\nGenerating MediaInfo XMLs...")
    for mov in mov_files:
        out = dated_mediainfo_dir / f"{mov.name}_mediainfo-pbcore2.xml"
        with open(out, "w") as xml_out:
            subprocess.run(
                [
                    "mediainfo",
                    "-f",
                    "--Output=PBCore2",
                    "--Language=raw",
                    str(mov),
                ],
                stdout=xml_out,
            )

    # 4. Initial CSV Generation
    csv_data = []
    to_move = []
    already_on_server = []
    for mov in mov_files:
        size = get_size_format(mov.stat().st_size)
        found = any((server / mov.name).exists() for server in MEZZ_SERVERS)
        csv_data.append(
            {
                "Filename": mov.name,
                "Status": "On Server" if found else "New",
                "FileSize": size,
                "TransferConfirmed": "N/A" if found else "No",
            }
        )
        if found:
            already_on_server.append(mov)
        else:
            to_move.append(mov)

    csv_path = input_dir / f"{start_date_str}_transfer_report.csv"
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["Filename", "Status", "FileSize", "TransferConfirmed"]
        )
        writer.writeheader()
        writer.writerows(csv_data)

    # 5. Move Duplicates to subfolder
    if already_on_server:
        dup_sub = input_dir / "already_on_server"
        dup_sub.mkdir(parents=True, exist_ok=True)
        for mov in already_on_server:
            shutil.move(str(mov), str(dup_sub / mov.name))
            md5_file = mov.with_name(f"{mov.name}.md5")
            if md5_file.exists():
                shutil.move(str(md5_file), str(dup_sub / md5_file.name))

    # 6. Transfer Logic
    if not to_move:
        print("\nNo new files to transfer.")
        return

    if not MEZZ_SERVERS:
        print("\nError: No Mezzanine Servers are configured in your environment.")
        return

    print("\nAvailable Servers:")
    for i, s in enumerate(MEZZ_SERVERS, 1):
        print(f"{i}. {s}")
    try:
        dest_server = MEZZ_SERVERS[int(input(f"\nSelect server (1-{len(MEZZ_SERVERS)}): ")) - 1]
    except:
        print("Invalid selection.")
        return

    # --- MEZZANINE SERVER CONNECTION CHECK ---
    if not dest_server.exists() or not dest_server.is_dir():
        print(f"\n✕  ERROR: Cannot reach destination '{dest_server}'.")
        print("Please verify the drive is mounted, then run the script again.")
        return
    # -----------------------------------

    # Create the folder for successful copies
    archive_dir = input_dir / f"moved-to-dphub-{start_date_str}"
    archive_dir.mkdir(parents=True, exist_ok=True)

    total_bytes = sum(mov.stat().st_size for mov in to_move)
    print(
        f"\nMoving {len(to_move)} MOVs | Total size: {get_size_format(total_bytes)}"
    )

    if input("Proceed? (y/n): ").lower() == "y":
        total_files = len(to_move)
        for index, mov in enumerate(to_move, 1):
            src_mov = mov
            src_md5 = mov.with_name(f"{mov.name}.md5")
            dest_mov = dest_server / mov.name
            dest_md5 = dest_server / f"{mov.name}.md5"

            print(f"\n[{index}/{total_files}] Copying to server: {mov.name}...")

            try:
                # Use copy2 to preserve metadata during transfer
                shutil.copy2(src_mov, dest_mov)
                if src_md5.exists():
                    shutil.copy2(src_md5, dest_md5)

                    # Verification on server
                    print("    Verifying integrity on server...")
                    with open(dest_md5, "r") as f:
                        expected = f.read().split()[0]

                    if calculate_md5(dest_mov) == expected:
                        print(
                            "    ✓ Verified. Moving local file to archive folder..."
                        )
                        # Move the LOCAL files to the archive folder after verification
                        shutil.move(str(src_mov), str(archive_dir / mov.name))
                        shutil.move(
                            str(src_md5), str(archive_dir / src_md5.name)
                        )

                        update_csv_status(csv_path, mov.name, "Yes")
                    else:
                        print(
                            "    ✕ HASH MISMATCH! Local file remains in input folder."
                        )
                        update_csv_status(csv_path, mov.name, "FAILED")
                else:
                    update_csv_status(csv_path, mov.name, "No MD5 Sidecar")
            except Exception as e:
                print(f"    ✕ Error: {e}")

        print(
            f"\nProcess complete. Successful files archived in: {archive_dir}"
        )


if __name__ == "__main__":
    main()