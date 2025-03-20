#!/bin/bash

# Define your clip destination directory:
directory="/path/"

# Instruct user to provide path to input file.
echo
echo "Use this script to create a clip from any video file."
echo "-------------------------------------------------------"
echo "Drag the file path to the Terminal window and hit ENTER."
read input_file

# Define the file info of the input file for bash.
filename=$(basename -- "$input_file")
extension="${filename##*.}"
filename="${filename%.*}"

# Get clip info from User.
echo "Enter start timecode (hh:mm:ss or mm:ss)."
read start_time
echo "Enter end timecode (hh:mm:ss or mm:ss)."
read end_time

# Remove colons from timecodes to create the desired output filename format.
start_time_nocolon=$(echo "$start_time" | sed 's/://g')
end_time_nocolon=$(echo "$end_time" | sed 's/://g')

# Create output filename using original filename and timecodes.
output_name="${filename}_${start_time_nocolon}-${end_time_nocolon}"

# Create clip with ffmpeg.
ffmpeg -i "$input_file" -ss $start_time -to $end_time -map 0 -c copy "$directory""$output_name"."$extension"

# Run mediainfo on output file to define variables to provide metrics in report.
filesize=$(mediainfo --Output=General\;%FileSize/String% "$directory""$output_name"."$extension")
fileduration=$(mediainfo --Output=Video\;%Duration/String4% "$directory""$output_name"."$extension")
framerate=$(mediainfo --Output=Video\;%FrameRate% "$directory""$output_name"."$extension")

# Provide final report.
echo "-------------------------------------------------------"
echo "Clip creation complete."
echo ""$output_name"."$extension" written to "$directory" with a framerate of "$framerate", size of "$filesize", and duration of "$fileduration"."
echo "-------------------------------------------------------"
