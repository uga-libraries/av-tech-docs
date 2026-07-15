# Multipurpose script to create md5 sidecar files for all AV files in a particular folder
# Can update the VALID EXTENSIONS section to add more file formats (or remove file formats)
# Folder to create md5s for can be passed as an argument when running the script
# If no folder is supplied, script will prompt user to enter folder
# Script will skip any files that already have a valid non-empty md5 file

#!/usr/bin/env python3

import sys
import hashlib
import os


# -----------------------------------
# Extensions to process
# -----------------------------------

VALID_EXTENSIONS = (
    '.mp4',
    '.mov',
    '.mxf',
    '.wav',
    '.mp3',
    '.mxf',
)


# -----------------------------------
# MD5 function
# -----------------------------------

def md5sum(filename):
    md5 = hashlib.md5()

    with open(filename, 'rb') as f:
        for chunk in iter(lambda: f.read(128 * md5.block_size), b''):
            md5.update(chunk)

    return md5.hexdigest()


# -----------------------------------
# Get target folder
# -----------------------------------

if len(sys.argv) > 1:
    target_folder = sys.argv[1]
else:
    target_folder = input("Enter folder path: ").strip()

target_folder = os.path.expanduser(target_folder)

if not os.path.isdir(target_folder):
    print(f"\nError: '{target_folder}' is not a valid folder.\n")
    sys.exit(1)

print(f"\nCreating MD5 sidecars in:\n{target_folder}\n")


# -----------------------------------
# Walk files
# -----------------------------------

for root, dirs, files in os.walk(target_folder):

    # Skip hidden directories
    dirs[:] = [d for d in dirs if not d.startswith('.')]

    for filename in files:

        # Skip hidden files
        if filename.startswith('.'):
            continue

        # Only process valid extensions
        if not filename.lower().endswith(VALID_EXTENSIONS):
            continue

        full_path = os.path.join(root, filename)
        md5_path = full_path + '.md5'

        # -----------------------------------
        # Skip if valid MD5 already exists
        # -----------------------------------

        if os.path.isfile(md5_path):

            # Check if existing md5 file is non-empty
            if os.path.getsize(md5_path) > 0:
                print(f"Skipping existing MD5: {filename}")
                continue
            else:
                print(f"Empty MD5 found, recreating: {filename}")

        else:
            print(f"Creating MD5: {filename}")

        # -----------------------------------
        # Generate checksum
        # -----------------------------------

        checksum = md5sum(full_path)

        with open(md5_path, "w") as outfile:
            outfile.write(checksum)

print("\nDone.\n")
