#!/usr/bin/env python3

import argparse
import subprocess
import sys
import os
from pathlib import Path

# Import your centralized config to load .env variables
import config

def main():
    # Set up argument parsing to replace the bash case/shift loop
    parser = argparse.ArgumentParser(
        description="PBCore Transformation Script",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog="Examples:\n  python transform_pbcore_batch.py folder --generation mezzanine --lto 000121L7 --lto2 000122L7"
    )
    parser.add_argument("input_path", nargs="?", default="", help="Input file or folder")
    parser.add_argument("--creator", default="brownMediaArchives", help="Override instantiationCreator")
    parser.add_argument("--generation", default="digitalPreservationMaster", help="digitalPreservationMaster, mezzanine, or archivalOriginal")
    parser.add_argument("--share", default="", help="Mezzanine share name (for DPHub, ex. mezzanine_1)")
    parser.add_argument("--lto", default="", help="Primary LTO Tape ID")
    parser.add_argument("--lto2", default="", help="Backup LTO Tape ID")

    args = parser.parse_args()

    # Prompt if no input supplied
    input_str = args.input_path
    if not input_str:
        input_str = input("Input file or folder: ").strip()
        if not input_str:
            print("No input provided. Exiting.")
            return
    
    input_path = Path(input_str).resolve()

    # Determine file list
    if input_path.is_file():
        input_dir = input_path.parent
        file_list = [input_path]
    elif input_path.is_dir():
        input_dir = input_path
        file_list = sorted(input_dir.glob("*.xml"))
    else:
        print(f"ERROR: Invalid input path: {input_path}")
        return

    if not file_list:
        print(f"ERROR: No XML files found in {input_path}")
        return

    # Output directory prompt
    default_output = input_dir / "transformed"
    out_str = input(f"Output folder [{default_output}]: ").strip()
    output_dir = Path(out_str).resolve() if out_str else default_output
    output_dir.mkdir(parents=True, exist_ok=True)

    # Print Summary
    print(f"\nInput:        {input_path}")
    print(f"Output:       {output_dir}")
    print(f"Creator:      {args.creator}")
    print(f"Generation:   {args.generation}")

    if args.generation == "mezzanine":
        if args.lto:
            print(f"Primary LTO:  {args.lto}")
            if args.lto2:
                print(f"Backup LTO:   {args.lto2}")
        else:
            print(f"Location:     Mezzanine share {args.share}")
    print()

    # Retrieve paths from your config.py environment setup
    # If they don't exist in config yet, it gracefully falls back to os.environ
    xsl_path = getattr(config, 'XSL_STYLESHEET_PATH', os.environ.get("XSL_STYLESHEET_PATH", "/PATH/TO/XSL/STYLESHEET"))
    saxon_path = getattr(config, 'SAXON_JAR_PATH', os.environ.get("SAXON_JAR_PATH", "/PATH/TO/SAXON.jar"))

    total = len(file_list)
    print(f"Found {total} file(s) to process.\n")

    for count, file_path in enumerate(file_list, start=1):
        filename = file_path.name
        base = file_path.stem
        outfile = output_dir / f"{base}-ca.xml"

        print(f"Processing {count} of {total}: {filename}")

        # ERROR VALIDATION: Ensure mezzanine has a location defined
        if args.generation == "mezzanine":
            if not args.share and not args.lto:
                print(f"  ERROR: Mezzanine generation requires either --share or --lto for {filename}")
                sys.exit(1)

        # Skip if output already exists
        if outfile.exists():
            print("  Skipping (already exists)")
            continue

        # Build and execute the Java command
        java_cmd = [
            "java", "-cp", str(saxon_path), "net.sf.saxon.Transform",
            f"-s:{file_path}",
            f"-xsl:{xsl_path}",
            f"-o:{outfile}",
            f"creator={args.creator}",
            f"generation={args.generation}",
            f"mezzanine_share={args.share}",
            f"lto_id={args.lto}",
            f"lto_id_2={args.lto2}"
        ]

        result = subprocess.run(java_cmd)
        
        if result.returncode != 0:
            print(f"  ERROR: Saxon failed on {filename}")
            sys.exit(1)

    print(f"\nFinished processing {total} file(s).\n")

if __name__ == "__main__":
    main()