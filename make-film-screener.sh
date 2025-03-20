#!/bin/bash

# Define your clip destination directory:
directory="/path/"

# Define your file path for the BMA watermark:
watermark="/path/to/file.png"

# Define your file path for the timecode font:
tcfont="/path/to/font."

# Prompt the user for input (either a file or folder)
echo
echo "Use this script to create a screener for a film file or a folder of film files."
echo "-------------------------------------------------------"
echo "Drag the file or folder path to the Terminal window and hit ENTER."
read input_path

# Validate the input
if [ -f "$input_path" ]; then
    # Single file mode
    files_to_process=("$input_path")
elif [ -d "$input_path" ]; then
    # Folder mode - find all video files (modify extensions as needed)
    mapfile -t files_to_process < <(find "$input_path" -type f \( -iname "*.mov" -o -iname "*.mp4" -o -iname "*.mkv" \))
else
    echo "Error: Provided path is neither a valid file nor a directory."
    exit 1
fi

# Process each file
for input_file in "${files_to_process[@]}"; do
    # Use mediainfo to define the framerate
    framerate=$(mediainfo --Output=Video\;%FrameRate% "$input_file")

    # Define the file info of the input/output file for bash
    filename=$(basename -- "$input_file")
    extension="mp4"
    filename="${filename%.*}"

    # Use ffmpeg to create the output file
    ffmpeg -i "$input_file" -i "$watermark" -filter_complex "[0:v] scale=640:480 [scale];[scale][1:v] overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2,drawtext=fontfile=$tcfont : timecode='00\\:00\\:00\\:00': r=$framerate : x=((w-tw)/2): y=((h-th)-30): fontsize=48: fix_bounds=0: fontcolor=white: box=0: boxcolor=0x00000000@1" -c:v libx264 -profile:v baseline -vb 2000k -pix_fmt yuv420p -movflags +faststart -c:a aac -ab 192k -ar 48000 -ac 2 "$directory$filename.$extension"

    # Run mediainfo on output file to define variables to provide metrics in report
    filesize=$(mediainfo --Output=General\;%FileSize/String% "$directory$filename.$extension")
    fileduration=$(mediainfo --Output=Video\;%Duration/String4% "$directory$filename.$extension")

    # Provide final report for each file
    echo "-------------------------------------------------------"
    echo "Screener creation complete."
    echo "$filename.$extension written to $directory with a framerate of $framerate, size of $filesize, and duration of $fileduration."
    echo "-------------------------------------------------------"
done

echo "All processing complete."
