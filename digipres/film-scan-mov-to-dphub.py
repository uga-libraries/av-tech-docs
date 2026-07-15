# Script to copy MOV mezzanine files from film scanner RAID to a DPHub share
# Script confirms presence of md5 sidecar, copies file, verifies md5, and creates mediainfo XML (to be used in creating digital object records for CA)
# Script also creates a CSV report showing size of files and confirming whether they were successfully transferred
# After transfer, files are moved to a subfolder, which can then be deleted by user

import os
import shutil
import subprocess
import csv
import hashlib
from datetime import date

# --- SMART ENVIRONMENT LOADER ---
# This climbs up your folders until it finds your master .env file
def load_env():
    # Start looking in the folder where this script lives
    current_dir = os.path.dirname(os.path.abspath(__file__))
    
    while current_dir:
        env_file = os.path.join(current_dir, ".env")
        if os.path.exists(env_file):
            with open(env_file, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" in line:
                        key, val = line.split("=", 1)
                        os.environ[key.strip()] = val.strip().strip('"').strip("'")
            return # Found it and loaded it, stop looking!
        
        # If not found, move up one directory level (closer to the root)
        parent_dir = os.path.dirname(current_dir)
        if parent_dir == current_dir:  # Reached the ultimate root of the computer
            break
        current_dir = parent_dir

# Execute env loader
load_env()

# --- CONFIGURATION (Loaded from .env) ---
# Reads servers as a comma-separated list from your .env file
env_servers = os.environ.get("MEZZ_SERVERS")
if env_servers:
    MEZZ_SERVERS = [s.strip() for s in env_servers.split(",") if s.strip()]
else:
    # Fallback defaults if .env file is missing
    MEZZ_SERVERS = [
        "/Volumes/mezzanine_1",
        "/Volumes/mezzanine_2",
        "/Volumes/mezzanine_3",
        "/Volumes/mezzanine_4",
        "/Volumes/mezzanine_5"
    ]

# Reads MediaInfo base path from your .env file
LOCAL_MEDIAINFO_FOLDER = os.environ.get("LOCAL_MEDIAINFO_FOLDER", "/PATH/WHERE/YOU/WANT/MEDIAINFO/TO/GO")


def calculate_md5(filepath):
    hash_md5 = hashlib.md5()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b''):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def get_size_format(b):
    for unit in ["", "K", "M", "G", "T"]:
        if b < 1024: return f"{b:.2f}{unit}B"
        b /= 1024
    return f"{b:.2f}PB"

def update_csv_status(csv_path, filename, status_val):
    rows = []
    with open(csv_path, 'r', newline='') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            if row['Filename'] == filename:
                row['TransferConfirmed'] = status_val
            rows.append(row)
    with open(csv_path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

def main():
    # Capture the start date immediately for consistent folder naming
    start_date_str = date.today().strftime("%Y-%m-%d")

    # 1. Accept input directory
    input_dir = input("Enter input directory path: ").strip()
    if not os.path.isdir(input_dir):
        return print("Error: Invalid directory.")

    mov_files = [f for f in os.listdir(input_dir) if f.lower().endswith('.mov')]
    if not mov_files:
        return print("No MOV files found.")

    # 2. Batch MD5 Creation
    missing_md5s = [m for m in mov_files if not os.path.exists(os.path.join(input_dir, m + ".md5"))]
    if missing_md5s:
        print(f"\n[!] Found {len(missing_md5s)} files missing MD5 sidecars.")
        if input("Generate all? (y/n): ").lower() == 'y':
            for mov in missing_md5s:
                print(f"Generating MD5 for {mov}...")
                val = calculate_md5(os.path.join(input_dir, mov))
                with open(os.path.join(input_dir, mov + ".md5"), "w") as f:
                    f.write(f"{val}  {mov}")

    # 3. MediaInfo
    dated_mediainfo_dir = os.path.join(LOCAL_MEDIAINFO_FOLDER, f"{start_date_str}_film-scan-movs")
    os.makedirs(dated_mediainfo_dir, exist_ok=True)
    print("\nGenerating MediaInfo XMLs...")
    for mov in mov_files:
        out = os.path.join(dated_mediainfo_dir, f"{mov}_mediainfo-pbcore2.xml")
        with open(out, 'w') as xml_out:
            subprocess.run(["mediainfo", "-f", "--Output=PBCore2", "--Language=raw", os.path.join(input_dir, mov)], stdout=xml_out)

    # 4. Initial CSV Generation
    csv_data = []
    to_move = []
    already_on_server = []
    for mov in mov_files:
        size = get_size_format(os.path.getsize(os.path.join(input_dir, mov)))
        found = any(os.path.exists(os.path.join(s, mov)) for s in MEZZ_SERVERS)
        csv_data.append({
            'Filename': mov, 
            'Status': "On Server" if found else "New", 
            'FileSize': size,
            'TransferConfirmed': "N/A" if found else "No"
        })
        if found: already_on_server.append(mov)
        else: to_move.append(mov)

    csv_path = os.path.join(input_dir, f"{start_date_str}_transfer_report.csv")
    with open(csv_path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['Filename', 'Status', 'FileSize', 'TransferConfirmed'])
        writer.writeheader()
        writer.writerows(csv_data)

    # 5. Move Duplicates to subfolder
    if already_on_server:
        dup_sub = os.path.join(input_dir, "already_on_server")
        os.makedirs(dup_sub, exist_ok=True)
        for mov in already_on_server:
            shutil.move(os.path.join(input_dir, mov), os.path.join(dup_sub, mov))
            if os.path.exists(os.path.join(input_dir, mov + ".md5")):
                shutil.move(os.path.join(input_dir, mov + ".md5"), os.path.join(dup_sub, mov + ".md5"))

    # 6. Transfer Logic
    if not to_move: return print("\nNo new files to transfer.")

    print("\nAvailable Servers:")
    for i, s in enumerate(MEZZ_SERVERS, 1): print(f"{i}. {s}")
    try:
        dest_server = MEZZ_SERVERS[int(input("\nSelect server (1-5): ")) - 1]
    except: return print("Invalid selection.")

    # Create the folder for successful copies
    archive_dir = os.path.join(input_dir, f"moved-to-dphub-{start_date_str}")
    os.makedirs(archive_dir, exist_ok=True)

    total_bytes = sum(os.path.getsize(os.path.join(input_dir, f)) for f in to_move)
    print(f"\nMoving {len(to_move)} MOVs | Total size: {get_size_format(total_bytes)}")
    
    if input("Proceed? (y/n): ").lower() == 'y':
        total_files = len(to_move)
        for index, mov in enumerate(to_move, 1):
            src_mov = os.path.join(input_dir, mov)
            src_md5 = src_mov + ".md5"
            dest_mov = os.path.join(dest_server, mov)
            dest_md5 = dest_mov + ".md5"
            
            print(f"\n[{index}/{total_files}] Copying to server: {mov}...")
            
            try:
                # Use copy2 to preserve metadata during transfer
                shutil.copy2(src_mov, dest_mov)
                if os.path.exists(src_md5):
                    shutil.copy2(src_md5, dest_md5)
                    
                    # Verification on server
                    print(f"    Verifying integrity on server...")
                    with open(dest_md5, 'r') as f:
                        expected = f.read().split()[0]
                    
                    if calculate_md5(dest_mov) == expected:
                        print("    ✓ Verified. Moving local file to archive folder...")
                        # Move the LOCAL files to the archive folder after verification
                        shutil.move(src_mov, os.path.join(archive_dir, mov))
                        shutil.move(src_md5, os.path.join(archive_dir, mov + ".md5"))
                        
                        update_csv_status(csv_path, mov, "Yes")
                    else:
                        print(f"    ✕ HASH MISMATCH! Local file remains in input folder.")
                        update_csv_status(csv_path, mov, "FAILED")
                else:
                    update_csv_status(csv_path, mov, "No MD5 Sidecar")
            except Exception as e:
                print(f"    ✕ Error: {e}")
        
        print(f"\nProcess complete. Successful files archived in: {archive_dir}")

if __name__ == "__main__":
    main()