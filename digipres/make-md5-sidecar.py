#!/usr/bin/env python3

# Multipurpose script to create md5 sidecar files for all AV files in a particular folder
# Can update the VALID EXTENSIONS section to add more file formats (or remove file formats)
# Folder to create md5s for can be passed as an argument when running the script
# If no folder is supplied, script will prompt user to enter folder
# Script will skip any files that already have a valid non-empty md5 file


import sys
import hashlib
from pathlib import Path

# -----------------------------------
# Extensions to process
# -----------------------------------

VALID_EXTENSIONS = (
    '.mp4',
    '.mov',
    '.mxf',
    '.wav',
    '.mp3',
)

# -----------------------------------
# MD5 function
# -----------------------------------

def md5sum(file_path):
    md5 = hashlib.md5()

    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(128 * md5.block_size), b''):
            md5.update(chunk)

    return md5.hexdigest()

# -----------------------------------
# Get target folder
# -----------------------------------

if len(sys.argv) > 1:
    target_input = sys.argv[1]
else:
    target_input = input("Enter folder path: ").strip()

# Convert to Path object and expand '~' if used
target_folder = Path(target_input).expanduser()

if not target_folder.is_dir():
    print(f"\nError: '{target_folder}' is not a valid folder.\n")
    sys.exit(1)

print(f"\nCreating MD5 sidecars in:\n{target_folder}\n")

# -----------------------------------
# Walk files
# -----------------------------------

# rglob('*') recursively searches all files and folders
for file_path in target_folder.rglob('*'):
    
    # Skip directories, hidden files, or files inside hidden directories
    if not file_path.is_file() or file_path.name.startswith('.') or any(part.startswith('.') for part in file_path.parts):
        continue

    # Only process valid extensions
    if file_path.suffix.lower() not in VALID_EXTENSIONS:
        continue

    # Create the MD5 path by appending .md5 to the existing file path
    md5_path = file_path.with_name(file_path.name + '.md5')

    # -----------------------------------
    # Skip if valid MD5 already exists
    # -----------------------------------

    if md5_path.exists():
        # Check if existing md5 file is non-empty
        if md5_path.stat().st_size > 0:
            print(f"Skipping existing MD5: {file_path.name}")
            continue
        else:
            print(f"Empty MD5 found, recreating: {file_path.name}")
    else:
        print(f"Creating MD5: {file_path.name}")

    # -----------------------------------
    # Generate checksum
    # -----------------------------------

    checksum = md5sum(file_path)

    with open(md5_path, "w") as outfile:
        outfile.write(checksum)

print("\nDone.\n")