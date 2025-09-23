#!/bin/bash
#
# make-screener.sh
# Create watermarked screeners for one file OR every supported video in a folder.

# ------------------ Default settings ------------------
default_directory="/Volumes/Tritonia/media-orders/outbox/video-screeners/"
watermark="/Volumes/Tritonia/watermarks/bmac-watermark_600x197.png"
tcfont="/Volumes/Tritonia/watermarks/LucidaGrande.ttc"

echo
echo "Use this script to create a screener for a video file (or a whole folder)."
echo "-------------------------------------------------------------------------"

# ------------------ Get input ------------------
if [[ -n "$1" ]]; then
    input_path="$1"
else
    echo "Drag a video file or folder to the Terminal window and hit ENTER:"
    read input_path
fi

if [[ ! -e "$input_path" ]]; then
    echo "Error: '$input_path' not found."
    exit 1
fi

# ------------------ Destination directory ------------------
echo
echo "Enter a new destination directory (press Enter to use default):"
read user_directory
if [[ -n "$user_directory" ]]; then
    directory="${user_directory%/}/"
else
    directory="$default_directory"
fi
mkdir -p "$directory"

# ------------------ Function to process a single file ------------------
process_file() {
    local input_file="$1"

    # Only process if it’s a regular file
    [[ -f "$input_file" ]] || return

    # Get framerate
    framerate=$(mediainfo --Output=Video\;%FrameRate% "$input_file")

    # File naming
    filename=$(basename -- "$input_file")
    extension="mp4"
    filename="${filename%.*}"

    echo "Processing: $filename"

    ffmpeg -i "$input_file" \
    -vf "movie=$watermark [watermark];[in][watermark]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2,\
drawtext=fontfile=$tcfont: timecode='00\\:00\\:00\\:00': r=$framerate: \
x=((w-tw)/2): y=((h-th)-30): fontsize=48: fix_bounds=0: \
fontcolor=white: box=0: boxcolor=0x00000000@1[out]" \
    -c:v libx264 -profile:v baseline -b:v 1500k -pix_fmt yuv420p \
    -movflags +faststart -c:a aac -ab 192k -ar 48000 -ac 2 \
    "$directory$filename.$extension"

    # Report
    filesize=$(mediainfo --Output=General\;%FileSize/String% "$directory$filename.$extension")
    fileduration=$(mediainfo --Output=Video\;%Duration/String4% "$directory$filename.$extension")
    echo "✔ $filename.$extension written to $directory ($filesize, $fileduration)"
    echo
}

# ------------------ Single file vs. directory ------------------
if [[ -d "$input_path" ]]; then
    echo "Input is a directory. Looping through video files…"
    shopt -s nullglob
    for f in "$input_path"/*.{mp4,mov,mxf,avi,mpg,mpeg,mkv}; do
        process_file "$f"
    done
    shopt -u nullglob
else
    process_file "$input_path"
fi

echo "All processing complete."
