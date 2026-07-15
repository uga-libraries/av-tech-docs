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

# Define the output directory (Falls back to default if .env is missing)
OUTPUT_DIR="${MP3_OUTPUT_DIR:-/path/to/output}"

# Function to convert an audio file to mp3
convert_to_mp3() {
    local input_file="$1"
    local output_file="${OUTPUT_DIR}/$(basename "${input_file%.*}.mp3")"

    # Convert the file using ffmpeg
    ffmpeg -i "$input_file" -write_id3v1 1 -id3v2_version 3 -dither_method triangular -out_sample_rate 48k -qscale:a 1 "$output_file"

    # Check if ffmpeg command was successful
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to convert '${input_file}' to MP3."
        return 1
    else
        echo "Successfully converted '${input_file}' to '${output_file}'."
    fi
}

# Main function to process input
process_input() {
    local input_path="$1"
    local extensions=("wav" "aiff" "aif" "flac" "ogg" "m4a")

    # Check if the input path exists
    if [[ ! -e "$input_path" ]]; then
        echo "Error: The input path '${input_path}' does not exist."
        exit 1
    fi

    # Function to process a single file
    process_file() {
        local file="$1"
        for ext in "${extensions[@]}"; do
            if [[ "${file##*.}" == "$ext" ]]; then
                convert_to_mp3 "$file"
                return
            fi
        done
        echo "Error: '${file}' is not a supported audio file."
    }

    # Check if the input path is a directory
    if [[ -d "$input_path" ]]; then
        # Process each supported audio file in the directory
        for ext in "${extensions[@]}"; do
            for file in "$input_path"/*."$ext"; do
                # Check if there are no files with the current extension
                if [[ ! -e "$file" ]]; then
                    continue
                fi
                process_file "$file"
            done
        done
    elif [[ -f "$input_path" ]]; then
        # Process a single file
        process_file "$input_path"
    else
        echo "Error: The input path '${input_path}' is neither a file nor a directory."
        exit 1
    fi
}

# Ask the user for the input file or directory
read -p "Enter the input file or directory path: " input_path

# Process the input
process_input "$input_path"