# This is a multipurpose script that will copy individual files or entire directories (not including the directory itself) and validate any md5 checksums present

import os
import shutil
import hashlib
from pathlib import Path

def md5sum(file_path, chunk_size=8192):
    hash_md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(chunk_size), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def get_expected_md5(md5_file):
    with open(md5_file, "r") as f:
        return f.read().split()[0]

def copy_and_verify_file(src_file, dest_dir):
    filename = src_file.name
    dest_file = dest_dir / filename

    # Copy file
    shutil.copy2(src_file, dest_file)

    md5_file = src_file.with_suffix(src_file.suffix + ".md5")
    dest_md5 = dest_file.with_suffix(dest_file.suffix + ".md5")

    if not md5_file.exists():
        return (filename, "No MD5 sidecar", "", "")

    # Copy md5 file
    shutil.copy2(md5_file, dest_md5)

    expected = get_expected_md5(dest_md5)
    actual = md5sum(dest_file)

    if expected == actual:
        return (filename, "VALID", expected, actual)
    else:
        return (filename, "MISMATCH", expected, actual)

def collect_files(src_path):
    if src_path.is_file():
        return [src_path]
    else:
        # Only include files that have a matching .md5
        files = []
        for f in src_path.iterdir():
            if f.is_file() and not f.name.endswith(".md5"):
                files.append(f)
        return files

def main():
    src_input = input("Enter source file or directory: ").strip()
    dest_input = input("Enter destination directory: ").strip()

    src_path = Path(src_input)
    dest_path = Path(dest_input)

    if not src_path.exists():
        print("❌ Source does not exist")
        return

    dest_path.mkdir(parents=True, exist_ok=True)

    files = collect_files(src_path)
    total = len(files)

    if total == 0:
        print("⚠️ No files found to process")
        return

    print(f"\nProcessing {total} files...\n")

    for i, file in enumerate(files, start=1):
        print(f"Working on file {i} of {total}: {file.name}")

        result = copy_and_verify_file(file, dest_path)

        filename, status, expected, actual = result

        if status == "VALID":
            print(f"  ✅ Verified")
        elif status == "MISMATCH":
            print(f"  ❌ Mismatch")
            print(f"     Expected: {expected}")
            print(f"     Actual:   {actual}")
        else:
            print(f"  ⚠️ {status}")

    print("\nDone.")

if __name__ == "__main__":
    main()
