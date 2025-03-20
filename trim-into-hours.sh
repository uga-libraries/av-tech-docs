#!/bin/bash

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg is not installed. Please install ffmpeg."
    exit 1
fi

# Prompt user for input video file
read -p "Please enter the path to the input video file: " input_file

output_directory="$(dirname "$input_file")"
filename=$(basename -- "$input_file")
extension="${filename##*.}"
filename="${filename%.*}"

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Input file $input_file not found."
    exit 1
fi

# Get duration of the input video
duration=$(ffprobe -i "$input_file" -show_entries format=duration -v quiet -of csv="p=0")

# Trim the video into one-hour segments
start_time=0
end_time=3600
segment_number=1

while [ $(echo "$start_time < $duration" | bc) -eq 1 ]; do
    output_file="${output_directory}/${filename}_$(printf "%02d" $segment_number).${extension}"
    ffmpeg -i "$input_file" -ss "$start_time" -to "$end_time" -c copy "$output_file"
    echo "Segment $(printf "%02d" $segment_number) created: $output_file"
    start_time=$(echo "$start_time + 3600" | bc)
    end_time=$(echo "$end_time + 3600" | bc)
    segment_number=$((segment_number + 1))
done

echo "All segments created successfully."
