#!/bin/bash

# Define your clip destination directory:
output_directory="/path/"

# Define your file path for the BMA watermark:
watermark="/path/to/watermark.png"

# Define your file path for the timecode font:
tcfont=/path/to/font.ttc

# Instruct user to provide path to input file or directory.
echo
echo "Use this script to create screeners for video files of any framerate."
echo "-------------------------------------------------------"
echo "Drag the file path (file or directory) to the Terminal window and hit ENTER."
read input_path

# Check if input is a file or directory
if [[ -f "$input_path" ]]; then
    files=("$input_path")
elif [[ -d "$input_path" ]]; then
    # Find all video files in the directory
    files=($(find "$input_path" -type f -name "*.mp4" -o -name "*.mov" -o -name "*.avi" -o -name "*.mkv"))
else
    echo "Invalid input. Please provide a valid file or directory."
    exit 1
fi

# Process each file
for input_file in "${files[@]}"; do
    # Use mediainfo to define the framerate.
    framerate=$(mediainfo --Output=Video\;%FrameRate% "$input_file")

    # Define the file info of the input/output file for bash.
    filename=$(basename -- "$input_file")
    extension="mp4"
    filename="${filename%.*}"

    # Use ffmpeg to create the output file.
    ffmpeg -i "$input_file" -vf "movie=$watermark [watermark];[in][watermark]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2,drawtext=fontfile=$tcfont: timecode='00\:00\:00\:00': r=$framerate: x=((w-tw)/2): y=((h-th)-30): fontsize=48: fix_bounds=0: fontcolor=white: box=0: boxcolor=0x00000000@1[out]" -c:v libx264 -profile:v baseline -b:v 1500k -pix_fmt yuv420p -movflags +faststart -c:a aac -ab 192k -ar 48000 -ac 2 "$output_directory$filename.$extension"

    # Run mediainfo on output file to define variables to provide metrics in report.
    filesize=$(mediainfo --Output=General\;%FileSize/String% "$output_directory$filename.$extension")
    fileduration=$(mediainfo --Output=Video\;%Duration/String4% "$output_directory$filename.$extension")

    # Provide final report for each file.
    echo "-------------------------------------------------------"
    echo "Screener creation complete for:"
    echo "\"$filename.$extension\" written to \"$output_directory\" with a framerate of \"$framerate\", size of \"$filesize\", and duration of \"$fileduration\"."
    echo "-------------------------------------------------------"
done
