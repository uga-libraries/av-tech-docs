import sys
import subprocess
import argparse
from pathlib import Path

# Look up one level to find config.py in the av-tech-docs root directory
script_dir = Path(__file__).resolve().parent
project_root = script_dir.parent

if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

# Import the required path helper directly from your suite's central config
from config import require_path

# Use the require_path as set up in the config file (No fallbacks)[cite: 3]
XSL = require_path("XSL_STYLESHEET_PATH")
SAXON = require_path("SAXON_JAR_PATH")

#############################################
# Parse options using argparse
#############################################
parser = argparse.ArgumentParser(
    description="PBCore Transformation Script",
    formatter_class=argparse.RawTextHelpFormatter
)

parser.add_argument(
    "--creator", 
    default="brownMediaArchives", 
    help="Override instantiationCreator"
)
parser.add_argument(
    "--generation", 
    default="digitalPreservationMaster", 
    help="digitalPreservationMaster, mezzanine, or archivalOriginal"
)
parser.add_argument(
    "--share", 
    default="", 
    help="Mezzanine share name (for DPHub, ex. mezzanine_1)"
)
parser.add_argument(
    "--lto", 
    default="", 
    help="Primary LTO Tape ID"
)
parser.add_argument(
    "--lto2", 
    default="", 
    help="Backup LTO Tape ID"
)
parser.add_argument(
    "input_path", 
    nargs="?", 
    default="", 
    help="Input file or folder"
)

# Parse the arguments
args = parser.parse_args()

CREATOR = args.creator
GENERATION = args.generation
MEZZ_SHARE = args.share
LTO_ID = args.lto
LTO_ID_2 = args.lto2
INPUT_PATH_STR = args.input_path

print()
print("Default values:")
print("  instantiationCreator: brownMediaArchives")
print("  instantiationGeneration: digitalPreservationMaster")
print()
print("Override with:")
print("  --creator <value>")
print("  --generation <value>")
print("  --share <value>         Mezzanine share name (for DPHub)")
print("  --lto <value>           Primary LTO Tape ID")
print("  --lto2 <value>          Backup LTO Tape ID (optional)")
print()

#############################################
# Prompt if no input supplied
#############################################
if not INPUT_PATH_STR:
    INPUT_PATH_STR = input("Input file or folder: ")

# Turn input into a sanitized Path object[cite: 3]
INPUT_PATH = Path(INPUT_PATH_STR.strip()).expanduser()

#############################################
# Determine file list
#############################################
if INPUT_PATH.is_file():
    INPUT_DIR = INPUT_PATH.parent
    FILE_LIST = [INPUT_PATH]
else:
    INPUT_DIR = INPUT_PATH
    FILE_LIST = sorted(INPUT_DIR.glob("*.xml"))[cite: 1]

#############################################
# Output directory
#############################################
DEFAULT_OUTPUT = INPUT_DIR / "transformed"[cite: 1]

user_output = input(f"Output folder [{DEFAULT_OUTPUT}]: ")
if user_output.strip():
    OUTPUT_DIR = Path(user_output.strip()).expanduser()
else:
    OUTPUT_DIR = DEFAULT_OUTPUT

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)[cite: 1]

#############################################
# Summary
#############################################
print()
print(f"Input:        {INPUT_PATH}")
print(f"Output:       {OUTPUT_DIR}")
print(f"Creator:      {CREATOR}")
print(f"Generation:   {GENERATION}")

if GENERATION == "mezzanine":
    if LTO_ID:
        print(f"Primary LTO:  {LTO_ID}")
        if LTO_ID_2:
            print(f"Backup LTO:   {LTO_ID_2}")
    else:
        print(f"Location:     Mezzanine share {MEZZ_SHARE}")

print()

#############################################
# Processing loop
#############################################
if not FILE_LIST or not FILE_LIST[0].exists():[cite: 1]
    print(f"ERROR: No XML files found in {INPUT_PATH}")
    sys.exit(1)

TOTAL = len(FILE_LIST)
COUNT = 0

print(f"Found {TOTAL} file(s) to process.")
print()

for FILE in FILE_LIST:
    COUNT += 1
    # Pure pathlib properties: name gives filename, stem gives filename without extension
    FILENAME = FILE.name
    BASE = FILE.stem
    OUTFILE = OUTPUT_DIR / f"{BASE}-ca.xml"[cite: 1]

    print(f"Processing {COUNT} of {TOTAL}: {FILENAME}")

    # ERROR VALIDATION: Ensure mezzanine has a location defined
    if GENERATION == "mezzanine":
        if not MEZZ_SHARE and not LTO_ID:
            print(f"  ERROR: Mezzanine generation requires either --share or --lto for {FILENAME}")
            sys.exit(1)

    # Skip if output already exists
    if OUTFILE.exists():[cite: 1]
        print("  Skipping (already exists)")
        continue

    # Construct java subprocess call matching original tool args
    cmd = [
        "java", "-cp", str(SAXON), "net.sf.saxon.Transform",
        f"-s:{FILE}",
        f"-xsl:{XSL}",
        f"-o:{OUTFILE}",
        f"creator={CREATOR}",
        f"generation={GENERATION}",
        f"mezzanine_share={MEZZ_SHARE}",
        f"lto_id={LTO_ID}",
        f"lto_id_2={LTO_ID_2}"
    ]

    result = subprocess.run(cmd)[cite: 1]

    if result.returncode != 0:[cite: 1]
        print(f"  ERROR: Saxon failed on {FILENAME}")
        sys.exit(1)

print()
print(f"Finished processing {COUNT} file(s).")