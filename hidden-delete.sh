#!/bin/bash

echo -n "Enter directory path: "
read directory

hidden_files=$(find "$directory" -name ".*" -print -delete)
ds_store_files=$(find "$directory" -name ".DS_Store" -print -delete)
underscore_files=$(find "$directory" -name "._*" -print -delete)

total_files=$(echo "$hidden_files$ds_store_files$underscore_files" | wc -l)

if [ "$total_files" -eq "0" ]; then
  echo "No hidden files found."
else
  echo "Deleted $total_files hidden files:"
  echo "$hidden_files$ds_store_files$underscore_files" | sed 's|^'"$directory"'/||'
fi
