#!/bin/bash

echo
echo "Default values:"
echo "  instantiationCreator: brownMediaArchives"
echo "  instantiationGeneration: digitalPreservationMaster"
echo
echo "Override with:"
echo "  --creator <value>"
echo "  --generation <value>"
echo


#############################################
# Default values
#############################################

CREATOR="brownMediaArchives"
GENERATION="digitalPreservationMaster"
# Added to help track born-digital logic if needed later
MEZZ_SHARE=""

XSL="/INSERT/PATH/TO/ca-dig-obj.xsl"
SAXON="/INSERT/PATH/TO/SaxonHE9-8-0-12J/saxon9he.jar"

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
  echo "  --share <value>         Mezzanine share name (required for mezzanine)"
  echo
  echo "Examples:"
  echo "  ./transform_pbcore_batch.sh folder --generation archivalOriginal"
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
  echo "Mezzanine share: $MEZZ_SHARE"
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
    mezzanine_share="$MEZZ_SHARE"

  if [[ $? -ne 0 ]]; then
  echo "  ERROR: Saxon failed on $FILENAME"
  exit 1
  fi

  if [[ ! -f "$OUTFILE" ]]; then
  echo "  ERROR: Output file not created for $FILENAME"
  exit 1
  fi

done

echo
echo "Finished processing $COUNT file(s)."
echo
