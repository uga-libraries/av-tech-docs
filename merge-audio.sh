#!/bin/bash

# --- SMART ENVIRONMENT LOADER ---
# This climbs up folders until it finds your master .env file and loads it line-by-line
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [[ "$current_dir" != "" && "$current_dir" != "/" ]]; do
  if [[ -f "$current_dir/.env" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ "$line" =~ ^[[:space:]]*$ ]] && continue
      key="${line%%=*}"
      val="${line#*=}"
      val="${val%\"}"
      val="${val#\"}"
      val="${val%\'}"
      val="${val#\'}"
      export "$key"="$val"
    done < "$current_dir/.env"
    break
  fi
  current_dir="$(dirname "$current_dir")"
done

# Define your destination directory using the shared CLIP_DEST_DIR variable:
directory="${CLIP_DEST_DIR:-/path/to/output/}"

# Instruct user to provide path to input file.
echo
echo "Use this script to fix audio split between Track 1 and 2."
echo "-------------------------------------------------------"
echo "Drag the file path to the Terminal window and hit ENTER."
read input_file

# Use mediainfo to define the framerate.
framerate=$(mediainfo --Output=Video\;%FrameRate% "$input_file")

# Define the file info of the input/output file for bash.
filename=$(basename -- "$input_file")
extension="${filename##*.}"
filename="${filename%.*}"

# Use ffmpeg to create the output file.
ffmpeg -i $input_file -filter_complex "[0:a:0][0:a:1]amix=2:longest[aout]" -map 0:v:0 -map "[aout]" -c:v copy "$directory""$filename"."$extension"

# Run mediainfo on output file to define variables to provide metrics in report.
filesize=$(mediainfo --Output=General\;%FileSize/String% "$directory""$filename"."$extension")
fileduration=$(mediainfo --Output=Video\;%Duration/String4% "$directory""$filename"."$extension")

# Provide final report.
echo "-------------------------------------------------------"
echo "Audio merging complete."
echo ""$filename"."$extension" written to "$directory" with a framerate of "$framerate", size of "$filesize", and duration of "$fileduration"."
echo "-------------------------------------------------------"