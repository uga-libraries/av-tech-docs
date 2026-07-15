#!/bin/bash

echo
echo "Default values:"
echo "  instantiationCreator: brownMediaArchives"
echo "  instantiationGeneration: digitalPreservationMaster"
echo
echo "Override with:"
echo "  --creator <value>"
echo "  --generation <value>"
echo "  --share <value>         Mezzanine share name (for DPHub)"
echo "  --lto <value>           Primary LTO Tape ID"
echo "  --lto2 <value>          Backup LTO Tape ID (optional)"
echo


#############################################
# Default values
#############################################

CREATOR="brownMediaArchives"
GENERATION="digitalPreservationMaster"
MEZZ_SHARE=""
LTO_ID=""
LTO_ID_2=""

XSL="/Users/ceholmes/CA-stylesheets/ca-dig-obj-05-14.xsl"
SAXON="/Applications/SaxonHE9-8-0-12J/saxon9he.jar"

INPUT_PATH=""

#############################################
# Help text
#############################################

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo
  echo "PBCore Transformation Script"
  echo
  echo "Options:"
  echo "  --creator <value>       Override instantiationCreator"
  echo "  --generation <value>    digitalPreservationMaster, mezzanine, or archivalOriginal"
  echo "  --share <value>         Mezzanine share name (for DPHub)"
  echo "  --lto <value>           Primary LTO Tape ID"
  echo "  --lto2 <value>          Backup LTO Tape ID"
  echo
  echo "Examples:"
  echo "  ./transform_pbcore_batch.sh folder --generation mezzanine --lto 000121L7 --lto2 000122L7"
  exit 0
fi

#############################################
# Parse options
#############################################

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --creator)
      CREATOR="$2"
      shift 2
      ;;
    --generation)
      GENERATION="$2"
      shift 2
      ;;
    --share)
      MEZZ_SHARE="$2"
      shift 2
      ;;
    --lto)
      LTO_ID="$2"
      shift 2
      ;;
    --lto2)
      LTO_ID_2="$2"
      shift 2
      ;;
    *)
      INPUT_PATH="$1"
      shift
      ;;
  esac
done

#############################################
# Prompt if no input supplied
#############################################

if [[ -z "$INPUT_PATH" ]]; then
  read -p "Input file or folder: " INPUT_PATH
fi

#############################################
# Determine file list
#############################################

if [[ -f "$INPUT_PATH" ]]; then
  INPUT_DIR=$(dirname "$INPUT_PATH")
  FILE_LIST=("$INPUT_PATH")
else
  INPUT_DIR="$INPUT_PATH"
  FILE_LIST=("$INPUT_DIR"/*.xml)
fi

#############################################
# Output directory
#############################################

DEFAULT_OUTPUT="${INPUT_DIR}/transformed"

read -p "Output folder [${DEFAULT_OUTPUT}]: " OUTPUT_DIR
OUTPUT_DIR=${OUTPUT_DIR:-$DEFAULT_OUTPUT}

mkdir -p "$OUTPUT_DIR"

#############################################
# Summary
#############################################

echo
echo "Input:        $INPUT_PATH"
echo "Output:       $OUTPUT_DIR"
echo "Creator:      $CREATOR"
echo "Generation:   $GENERATION"

if [[ "$GENERATION" == "mezzanine" ]]; then
  if [[ -n "$LTO_ID" ]]; then
    echo "Primary LTO:  $LTO_ID"
    [[ -n "$LTO_ID_2" ]] && echo "Backup LTO:   $LTO_ID_2"
  else
    echo "Location:     Mezzanine share $MEZZ_SHARE"
  fi
fi

echo

#############################################
# Processing loop
#############################################

if [ ! -e "${FILE_LIST[0]}" ]; then
  echo "ERROR: No XML files found in $INPUT_PATH"
  exit 1
fi

TOTAL=${#FILE_LIST[@]}
COUNT=0

echo "Found $TOTAL file(s) to process."
echo

for FILE in "${FILE_LIST[@]}"; do

  ((COUNT++))

  FILENAME=$(basename "$FILE")
  BASE="${FILENAME%.xml}"
  OUTFILE="$OUTPUT_DIR/${BASE}-ca.xml"

  echo "Processing $COUNT of $TOTAL: $FILENAME"

  # ERROR VALIDATION: Ensure mezzanine has a location defined
  if [[ "$GENERATION" == "mezzanine" ]]; then
    if [[ -z "$MEZZ_SHARE" && -z "$LTO_ID" ]]; then
      echo "  ERROR: Mezzanine generation requires either --share or --lto for $FILENAME"
      exit 1
    fi
  fi

  # Skip if output already exists
  if [[ -f "$OUTFILE" ]]; then
    echo "  Skipping (already exists)"
    continue
  fi

  java -cp "$SAXON" net.sf.saxon.Transform \
    -s:"$FILE" \
    -xsl:"$XSL" \
    -o:"$OUTFILE" \
    creator="$CREATOR" \
    generation="$GENERATION" \
    mezzanine_share="$MEZZ_SHARE" \
    lto_id="$LTO_ID" \
    lto_id_2="$LTO_ID_2"

  if [[ $? -ne 0 ]]; then
  echo "  ERROR: Saxon failed on $FILENAME"
  exit 1
  fi

done

echo
echo "Finished processing $COUNT file(s)."
echo