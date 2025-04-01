#!/bin/bash

# Define your clip destination directory:
directory="/path/to/output/"

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
