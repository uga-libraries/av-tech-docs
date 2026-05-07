import csv
import os

# Written for renaming files received from George Blood as part of AAPB grant March 2026
# Files were received with the AAPB unique IDs. This script will replace the AAPB unique IDs with the BMA uniqueIDs, keeping any part suffixes intact.
# Before usage, create a CSV with the original name in the first colum and the new name in the second column

csv_path = input("Enter path to CSV mapping file: ").strip()
directory = input("Enter directory containing files: ").strip()

report_rows = []

# Load ID mappings
mapping = {}
with open(csv_path, newline="") as f:
    reader = csv.reader(f)
    for row in reader:
        if len(row) >= 2:
            mapping[row[0].strip()] = row[1].strip()

files = os.listdir(directory)

for file in files:
    for old_id, new_id in mapping.items():
        if file.startswith(old_id + "_"):
            suffix = file[len(old_id):]   # keeps _01.wav etc
            new_name = new_id + suffix

            old_path = os.path.join(directory, file)
            new_path = os.path.join(directory, new_name)

            if os.path.exists(new_path):
                status = "SKIPPED - new file exists"
                print(f"Skipping {file} → {new_name} (already exists)")
            else:
                os.rename(old_path, new_path)
                status = "RENAMED"
                print(f"{file} → {new_name}")

            report_rows.append([file, new_name, status])
            break

# Write report
report_path = os.path.join(directory, "rename_report.csv")
with open(report_path, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["Original Filename", "New Filename", "Status"])
    writer.writerows(report_rows)

print(f"\nReport written to: {report_path}")
