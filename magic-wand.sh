#!/bin/bash

# DEFINABLE variables
topdirectory="magic-wand/"
backup="backup/magic-wand" # Do not put a / on the end of the backup path or it will not sync properly.
logfile="/magic-wand-log.txt"

# MACHINE-CREATABLE DIRECTORIES
mkdir -p "$topdirectory""mezz-movs/"
mkdir -p "$topdirectory""mkvs-qc-sorted/"
mkdir -p "$topdirectory""mp4s/"

# NOW DEFINE THEM
md5directory="$topdirectory""mkvs-qc-sorted/"
mezzaninemovdirectory="$topdirectory""mezz-movs/"
mkvdirectory="$topdirectory""mkvs-qc-sorted/"
qcdirectory="$topdirectory""mkvs-qc-sorted/"
mp4directory="$topdirectory""mp4s/"

# DEFAULT variables
files="$topdirectory""*"
mkvfiles="$mkvdirectory""*"
mezzmovfiles="$mezzaninemovdirectory""*"
#the text to look for in a filename to verify that an mkv file is a qctools file
qctoolverify="qctools"

# COUNTING VARIABLES (for status updates at the end)
movcounter=0
mp4counter=0
md5counter=0
qccounter=0

echo -e "\n--\nNEW ------------------------------------------------------------------------------------------------\nLOG ------------------------------------------------------------------------------------------------\n--" >>"$logfile"
date >> "$logfile"
echo -e "\nBEGINNING INITIAL SORT." | tee -a "$logfile"

for f in in $files
do
  filename=$(basename -- "$f")
  extension="${filename##*.}"
  filename="${filename%.*}"
echo "extension for this file is $extension and the filename is $filename"
    if [[ -s "$f" ]] # Check to see if the file is not empty, otherwise we delete it. This is important so that we don't have an empty md5 or mov holding the place of a real one.
    then
      if [ -f "$f" ]
      then
        echo "-Processing $filename file..." | tee -a "$logfile"
        echo "--Initiating $extension routine";

          # QCTools routine

          if [[ $extension == "mkv" ]] && [[ $filename == *"$qctoolverify"* ]]
          then
            smartfilename=${filename::-8}
            echo "the filename without the trashsuffix is $smartfilename"
            if [[ -f "$topdirectory""$smartfilename" ]] || [[ -f "$mkvdirectory""$smartfilename" ]]
            then
              echo "---Moving QCTools data to the correct subfolder." | tee -a "$logfile"
              mv "$f" "$qcdirectory""$filename"".""$extension"
            else
              echo "---This QCTools data does not have a parent. Removing orphan." | tee -a "$logfile"
              rm "$f"
            fi
          fi

          # MOV routine

          if [ $extension == "mov" ]
          then
            if [[ -f "$topdirectory""$filename"".mkv" ]] || [[ -f "$mkvdirectory""$filename"".mkv" ]]
            then
              echo "---Moving mezzanine mov to the correct subfolder." | tee -a "$logfile"
              mv "$f" "$mezzaninemovdirectory""$filename"".""$extension"
            else
              echo "---Removing unattached mov." | tee -a "$logfile"
              rm "$f"
            fi
          fi

          # MKV routine

          if [ $extension == "mkv" ]
          then
            echo "---Checking for md5..." | tee -a "$logfile"
            if [[ -f "$md5directory""$filename"".mkv.md5" ]] || [[ -f "$topdirectory""$filename"".mkv.md5" ]]
            then
              echo "----This has an md5!" | tee -a "$logfile"
            else
              echo "----This does not have an md5!" | tee -a "$logfile"
              echo "----Creating an md5 for "$filename"" | tee -a "$logfile"
              md5 "$f" | awk '{print $4}' > "$md5directory""$filename"".mkv.md5"
              echo "-----md5 for "$filename" has been created" | tee -a "$logfile"
              md5counter=$((md5counter+1))
            fi
            mv "$f" "$mkvdirectory""$filename"".""$extension"
          fi

          # MD5 routine

          if [ $extension == "md5" ]
          then
            if [[ -f "$mkvdirectory""$filename" ]] || [[ -f "$mezzaninemovdirectory""$filename" ]]
            then
              echo "---Moving md5 to the correct subfolder." | tee -a "$logfile"
              mv "$f" "$md5directory""$filename"".""$extension"
            else
              echo "---This md5 does not have a parent. Removing orphan." | tee -a "$logfile"
              rm "$f"
            fi
          fi
        fi
      else
        rm "$f"
      fi
done

# Clean-up stages (Make mezzanine files, proxy files, and syncing.)

echo -e "\nCLEANING UP AND MAKING ACCESSORY FILES." | tee -a "$logfile"

echo "-Trolling through MKVs to make accessory files." | tee -a "$logfile"
for f in $mkvfiles
do
  filename=$(basename -- "$f")
  extension="${filename##*.}"
  filename="${filename%.*}"
  if [ -s "$f" ]  && [ $extension == "mkv" ]
  then
    echo "--Checking "$filename"..." | tee -a "$logfile"

    # Checking for QCTools
    if [[ -f "$qcdirectory""$filename"".gz" ]]
    then
      echo "---This QCTools is already created." | tee -a "$logfile"
    else
      echo "---No QCTools created yet, making now..." | tee -a "$logfile"
      qcli -i "$f"
      echo "----QCTools has been made." | tee -a "$logfile"
      qccounter=$((qccounter+1))
    fi

    # Checking for an md5
    if [[ -f "$md5directory""$filename"".mkv.md5" ]]
    then
      echo "---This md5 is already created." | tee -a "$logfile"
    else
      echo "---No md5 created yet, making now..." | tee -a "$logfile"
      md5 "$f" | awk '{print $4}' > "$md5directory""$filename"".mkv.md5"
      echo "----MD5 has been made." | tee -a "$logfile"
      md5counter=$((md5counter+1))
    fi

    # Checking for an mov
    if [[ -f "$mezzaninemovdirectory""$filename"".mov" ]]
    then
      echo "---This mov is already created. Exiting." | tee -a "$logfile"
    else
      echo "---Mezzanine mov does not yet exist. Creating." | tee -a "$logfile"
      ffmpeg -i "$f" -c:v prores -profile:v 3 -vf yadif -c:a pcm_s16le -hide_banner -loglevel error "$mezzaninemovdirectory""$filename"".mov"
      movcounter=$((movcounter+1))
    fi

  fi
done

echo "-Trolling through mezzanine MOVs to create md5s." | tee -a "$logfile"
for f in $mezzmovfiles
do
  filename=$(basename -- "$f")
  extension="${filename##*.}"
  filename="${filename%.*}"
  if [[ -s "$f" ]] && [ $extension == "mov" ]
  then
    echo "--Checking "$filename""
    if [[ -f "$mezzaninemovdirectory""$filename"".mov.md5" ]]
    then
      echo "---This md5 is already created." | tee -a "$logfile"
    else
      echo "---No md5 created yet, making now..." | tee -a "$logfile"
      md5 "$f" | awk '{print $4}' > "$mezzaninemovdirectory""$filename"".mov.md5"
      echo "----MD5 has been made." | tee -a "$logfile"
      md5counter=$((md5counter+1))
    fi
  fi
done

# Define an array for all mov files.
movfiles=(""$mezzaninemovdirectory""*"")

echo "-Trolling through MOVs to make MP4 streaming files." | tee -a "$logfile"
for f in ${movfiles[@]} # This for loop must be written this way to iterate over every file in the movfiles array.
do
  filename=$(basename -- "$f")
  extension="${filename##*.}"
  filename="${filename%.*}"
  if [[ -s "$f" ]] && [ $extension == "mov" ]
  then
    echo "--Checking "$filename"..." | tee -a "$logfile"
    if [[ -f "$mp4directory""$filename"".mp4" ]]
    then
      echo "---This mp4 is already created. Exiting." | tee -a "$logfile"
    else
      echo "---Access mp4 does not yet exist. Creating." | tee -a "$logfile"
      ffmpeg -i "$f" -c:v libx264 -pix_fmt yuv420p -c:a aac -hide_banner -loglevel error "$mp4directory""$filename"".mp4"
      mp4counter=$((mp4counter+1))
    fi
  fi
done

# Copy files to a backup drive.

echo -e "\nSYNCING FILES TO BACKUP DESTINATION." | tee -a "$logfile"
rsync -au --delete --stats "$mkvdirectory" "$mezzaninemovdirectory" "$backup" | tee -a "$logfile"

echo -e "\nMAGIC WAND HAS DONE ITS MAGICK" | tee -a "$logfile"
echo "WAND CREATED "$mp4counter" access mp4(s), "$movcounter" mezzanine mov(s), and "$md5counter" md5 checksum(s)." | tee -a "$logfile"

# can add halt here if start script with 'sudo bash script'
shutdown -h now
