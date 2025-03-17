#!/bin/bash

# Configuration
OUTPUT_DIR="/path"
NETWORK_DRIVES=("/path" "/path" "/path")
LTO_LOGS_DIR="/path"
LTO_MOUNT_DIR="/Volumes/lto0"

# Function to check if a command was successful
check_success() {
    if [ $? -ne 0 ]; then
        echo "An error occurred. Exiting."
        exit 1
    fi
}

# Function to calculate MD5 checksum
calculate_md5() {
    local file="$1"
    local md5=$(md5sum "$file" | awk '{print $1}')
    echo "$md5"
}

# Function to search for all matches in SharePoint and LTO logs
search_files() {
    local filename="$1"
    local matches=()
    local index=1

    for drive in "${NETWORK_DRIVES[@]}"; do
        for file in "$drive/$filename"*; do
            if [ -e "$file" ]; then
                matches+=("$file")
                echo "$index: SharePoint - $file"
                ((index++))
            fi
        done
    done

    local lto_log_result
    while IFS= read -r line; do
        local lto_number=$(echo "$line" | cut -d':' -f1 | rev | cut -d'/' -f1 | rev | sed 's/\.txt//')
        echo "$index: LTO - $line (LTO: $lto_number)"
        matches+=("LTO:$lto_number:$line")
        ((index++))
    done < <(grep -R "$filename" "$LTO_LOGS_DIR" | head -n 10)

    if [ ${#matches[@]} -eq 0 ]; then
        echo "No matches found."
        return 1
    fi

    read -p "Enter the number of the file you want to copy: " selection
    selected_match="${matches[$((selection-1))]}"

    if [[ "$selected_match" == LTO:* ]]; then
        local lto_number=$(echo "$selected_match" | cut -d':' -f2)
        echo "Please load LTO number: $lto_number"
        read -p "Press Enter to continue after loading the LTO..."
        mount_lto
        cp -nRv "$LTO_MOUNT_DIR/$filename"* "$OUTPUT_DIR"
        verify_md5 "$filename" "$LTO_MOUNT_DIR"
        unmount_lto
    else
        cp -nRv "$selected_match" "$OUTPUT_DIR"
        verify_md5 "$filename" "$selected_match"
    fi
}

# Function to mount LTO
mount_lto() {
    if [ ! -d "$LTO_MOUNT_DIR" ]; then
        sudo mkdir -p "$LTO_MOUNT_DIR"
        check_success
    fi
    if ! mount | grep -q "$LTO_MOUNT_DIR"; then
        sudo ltfs -o devname=0 "$LTO_MOUNT_DIR" >/dev/null 2>&1
        check_success
    fi
    sleep 10
}

# Function to unmount LTO
unmount_lto() {
    if mount | grep -q "$LTO_MOUNT_DIR"; then
        sudo umount "$LTO_MOUNT_DIR"
        check_success
        echo "LTO unmounted successfully."
    fi
}

# Function to verify MD5 checksums
verify_md5() {
    local filename="$1"
    local location="$2"
    for file in "$OUTPUT_DIR/$filename"*.md5; do
        base_file="${file%.md5}"
        if [ -f "$base_file" ]; then
            original_md5=$(cat "$file")
            new_md5=$(calculate_md5 "$base_file")
            echo "Original MD5 for $base_file: $original_md5"
            echo "Newly calculated MD5 for $base_file: $new_md5"
            if [ "$original_md5" != "$new_md5" ]; then
                echo "MD5 mismatch for $base_file"
            else
                echo "MD5 match for $base_file"
            fi
        else
            echo "Warning: MD5 file found without corresponding object file: $file"
        fi
    done
}

# Main script logic
echo "Welcome to the file search and copy script."


while true; do
    read -p "Enter the filename you are looking for: " filename
    search_files "$filename"
    read -p "Do you want to locate another file? (y/n): " locate_again
    [ "$locate_again" != "y" ] && break
done

echo "Exiting."
