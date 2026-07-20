#!/bin/bash

# Configuration file location
CONFIG_FILE="$HOME/.retrieve_file.conf"

# ANSI Colors for a Friendlier UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Enable nullglob so unmatched patterns evaluate to empty arrays
shopt -s nullglob

# Automatic LTO cleanup on unexpected exits/interruptions
cleanup() {
    if type unmount_lto &>/dev/null; then
        unmount_lto
    fi
}
trap cleanup EXIT

print_header() {
    echo -e "\n${BLUE}${BOLD}================================================================${NC}"
    echo -e "${CYAN}${BOLD}  $1 ${NC}"
    echo -e "${BLUE}${BOLD}================================================================${NC}"
}

run_config_wizard() {
    print_header "CONFIGURATION WIZARD"

    echo -e "${YELLOW}${BOLD}⚠️  PRE-SETUP CHECKLIST:${NC}"
    echo -e " Please ensure all Mezzanine network drives are currently ${BOLD}MOUNTED${NC}"
    echo -e " in macOS Finder before continuing (e.g., mezzanine_1, mezzanine_2, etc.)."
    echo -e " Having them mounted ensures the retrieval system functions correctly."
    echo ""
    read -p " Press [Enter] once your network drives are mounted to begin setup..."
    echo -e "\n----------------------------------------------------------------"

    read -p "Enter local OUTPUT directory path [/path]: " input_out
    OUTPUT_DIR="${input_out:-/path}"

    NETWORK_DRIVES=()
    echo ""
    local num_drives
    while true; do
        read -p "How many mezzanine drives are there right now? " num_drives
        if [[ "$num_drives" =~ ^[0-9]+$ ]] && [ "$num_drives" -gt 0 ]; then
            break
        else
            echo -e "${RED}[!] Please enter a valid number greater than 0.${NC}"
        fi
    done

    for ((i=1; i<=num_drives; i++)); do
        local default_mezz_path="/Volumes/mezzanine_$i"
        read -p "  ➔ Enter path for Mezzanine Drive #$i [$default_mezz_path]: " mezz_path
        if [[ -z "$mezz_path" ]]; then
            mezz_path="$default_mezz_path"
        fi
        NETWORK_DRIVES+=("$mezz_path")
    done

    echo ""
    read -p "Are these the ONLY network drives? (y/n - choose 'n' to add a custom path): " only_mezz
    if [[ "$only_mezz" =~ ^[nN] ]]; then
        read -p "  ➔ Enter the additional custom location path: " custom_path
        if [[ -n "$custom_path" ]]; then
            NETWORK_DRIVES+=("$custom_path")
            echo -e "    ${GREEN}[✓] Added custom location: \"$custom_path\"${NC}"
        else
            echo -e "    ${YELLOW}No custom path entered. Skipping.${NC}"
        fi
    fi

    echo ""
    read -p "Enter LTO LOGS directory path [/path]: " input_logs
    LTO_LOGS_DIR="${input_logs:-/path}"

    read -p "Enter LTO MOUNT point directory [/Volumes/lto0]: " input_mount
    LTO_MOUNT_DIR="${input_mount:-/Volumes/lto0}"

    cat << EOF > "$CONFIG_FILE"
OUTPUT_DIR="$OUTPUT_DIR"
LTO_LOGS_DIR="$LTO_LOGS_DIR"
LTO_MOUNT_DIR="$LTO_MOUNT_DIR"
EOF

    echo "NETWORK_DRIVES=(" >> "$CONFIG_FILE"
    for drive in "${NETWORK_DRIVES[@]}"; do
        echo "  \"$drive\"" >> "$CONFIG_FILE"
    done
    echo ")" >> "$CONFIG_FILE"

    echo -e "\n${GREEN}[✓] Configuration saved successfully to: $CONFIG_FILE${NC}"
    sleep 1.5
}

load_configuration() {
    if [[ "$1" == "--config" ]] || [ ! -f "$CONFIG_FILE" ]; then
        run_config_wizard
    else
        source "$CONFIG_FILE"
    fi
}

check_success() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}[✗] An error occurred execution halted. Exiting.${NC}"
        exit 1
    fi
}

# Advanced Hashing Function
calculate_hash() {
    local file="$1"
    local algo="$2"

    if [ "$algo" == "sha256" ]; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif [ "$algo" == "sha512" ]; then
        shasum -a 512 "$file" | awk '{print $1}'
    elif command -v md5sum >/dev/null 2>&1; then
        md5sum "$file" | awk '{print $1}'
    else
        md5 -q "$file"
    fi
}

# Extended BagIt Verification
verify_bag() {
    local bag_dir="$1"

    # Check if this actually resembles a bag before running complex logic
    if ls "$bag_dir"/manifest-*.txt 1> /dev/null 2>&1; then
        echo -e "\n${BOLD}BagIt structure detected. Performing extended validation...${NC}"
        local all_match=true

        # 1. Verify Payload-Oxum (Fast Check)
        if [ -f "$bag_dir/bag-info.txt" ]; then
            local oxum=$(grep -i "Payload-Oxum" "$bag_dir/bag-info.txt" | cut -d':' -f2 | tr -d ' ')
            if [ -n "$oxum" ]; then
                local expected_bytes=$(echo "$oxum" | cut -d'.' -f1)
                local expected_files=$(echo "$oxum" | cut -d'.' -f2)

                # Native macOS compatible file and byte counting
                local actual_files=$(find "$bag_dir/data" -type f 2>/dev/null | wc -l | tr -d ' ')
                local actual_bytes=$(find "$bag_dir/data" -type f -exec stat -f "%z" {} + 2>/dev/null | awk '{s+=$1} END {print s}')
                [ -z "$actual_bytes" ] && actual_bytes=0

                if [ "$expected_files" == "$actual_files" ] && [ "$expected_bytes" == "$actual_bytes" ]; then
                    echo -e "  ${GREEN}[✓] Payload-Oxum matched! (${actual_files} files, ${actual_bytes} bytes)${NC}"
                else
                    echo -e "  ${RED}[✗] Payload-Oxum MISMATCH!${NC}"
                    echo "      Expected: $expected_files files, $expected_bytes bytes"
                    echo "      Actual:   $actual_files files, $actual_bytes bytes"
                    all_match=false
                fi
            fi
        fi

        # 2. Check for Stowaways (Unlisted payload files)
        if [ -d "$bag_dir/data" ]; then
            find "$bag_dir/data" -type f | while read -r payload_file; do
                local rel_path="${payload_file#$bag_dir/}"
                # Use -F for fixed string search to safely handle special characters in paths
                if ! grep -Fq "$rel_path" "$bag_dir"/manifest-*.txt 2>/dev/null; then
                    echo -e "  ${RED}[✗] STOWAWAY DETECTED:${NC} $rel_path is not listed in any payload manifest!"
                    all_match=false
                fi
            done
        fi

        # 3. Verify ALL Manifests (Payload and Tag manifests)
        for manifest_file in "$bag_dir"/manifest-*.txt "$bag_dir"/tagmanifest-*.txt; do
            [ ! -f "$manifest_file" ] && continue
            local manifest_name=$(basename "$manifest_file")
            echo -e "  Verifying ${CYAN}$manifest_name${NC}..."

            # Determine algorithm from filename
            local algo="md5"
            [[ "$manifest_name" == *sha256.txt ]] && algo="sha256"
            [[ "$manifest_name" == *sha512.txt ]] && algo="sha512"

            while read -r expected_hash filepath; do
                [ -z "$expected_hash" ] && continue

                filepath="${filepath//$'\r'/}"
                filepath="${filepath#\*}"
                local full_file_path="$bag_dir/$filepath"

                if [ -f "$full_file_path" ]; then
                    local computed_hash=$(calculate_hash "$full_file_path" "$algo")
                    if [ "$expected_hash" != "$computed_hash" ]; then
                        echo -e "    ${RED}[✗] MISMATCH:${NC} $filepath"
                        all_match=false
                    fi
                else
                    echo -e "    ${RED}[✗] MISSING FILE:${NC} $filepath"
                    all_match=false
                fi
            done < "$manifest_file"
        done

        # 4. Handle fetch.txt gracefully
        if [ -f "$bag_dir/fetch.txt" ]; then
            echo -e "  ${YELLOW}[⚠️] Notice: fetch.txt detected. This bash script does not resolve remote network files.${NC}"
        fi

        if [ "$all_match" = true ]; then
            echo -e "  ${GREEN}[✓] Extended BagIt validation complete. Bag is intact!${NC}"
        else
            echo -e "  ${RED}[✗] BagIt validation failed. See errors above.${NC}"
        fi
    fi
}

search_files() {
    local filename="$1"
    local matches=()
    local index=1

    echo -e "\n${BOLD}Scanning locations for: ${YELLOW}$filename${NC}..."

    # Search Network Drives
    for drive in "${NETWORK_DRIVES[@]}"; do
        for file in "$drive/$filename"*; do
            if [ -e "$file" ] && [[ "$file" != *.md5 ]]; then
                matches+=("$file")
                echo -e "  ${GREEN}[$index] SharePoint${NC} ➔ $file"
                ((index++))
            fi
        done
    done

    # Search LTO Logs
    while IFS= read -r line; do
        if [[ "$line" != *.md5 ]]; then
            local log_filepath="${line%%:*}"
            local log_filename="${log_filepath##*/}"
            local lto_number="${log_filename%.txt}"

            echo -e "  ${BLUE}[$index] LTO Tape ($lto_number)${NC} ➔ $line"
            matches+=("LTO:$lto_number:$line")
            ((index++))
        fi
    done < <(grep -R "$filename" "$LTO_LOGS_DIR" | head -n 100)

    if [ ${#matches[@]} -eq 0 ]; then
        echo -e "${RED}[!] No matching files found in logs or network storage.${NC}"
        return 1
    fi

    local selection
    echo ""
    while true; do
        read -p "Enter the index number of the item to copy (or 'c' to cancel): " selection
        if [[ "$selection" == "c" || "$selection" == "C" ]]; then
            echo "Operation cancelled."
            return 0
        fi
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#matches[@]}" ]; then
            break
        else
            echo -e "${RED}Invalid selection. Provide a number between 1 and ${#matches[@]}.${NC}"
        fi
    done

    local selected_match="${matches[$((selection-1))]}"

    local target_basename
    if [[ "$selected_match" == LTO:* ]]; then
        local relative_path=$(echo "$selected_match" | cut -d':' -f4-)
        target_basename=$(basename "$relative_path")
    else
        target_basename=$(basename "$selected_match")
    fi
    local copied_target="$OUTPUT_DIR/$target_basename"

    if [[ "$selected_match" == LTO:* ]]; then
        local lto_number=$(echo "$selected_match" | cut -d':' -f2)
        local relative_path=$(echo "$selected_match" | cut -d':' -f4-)

        echo -e "\n${YELLOW}[!] Attention: Please load tape target LTO number: ${BOLD}$lto_number${NC}"
        read -p "Press [Enter] to continue once the LTO tape is ready..."

        mount_lto
        echo -e "${CYAN}Copying asset from tape...${NC}"
        cp -nRv "$LTO_MOUNT_DIR/$relative_path" "$OUTPUT_DIR/"

        verify_bag "$copied_target"
        verify_md5 "$filename"

        unmount_lto
    else
        echo -e "${CYAN}Copying asset from Network Drive...${NC}"
        cp -nRv "$selected_match" "$OUTPUT_DIR/"

        verify_bag "$copied_target"
        verify_md5 "$filename"
    fi
}

mount_lto() {
    if mount | grep -q " on $LTO_MOUNT_DIR "; then
        echo -e "${GREEN}[✓] LTO is already mounted at $LTO_MOUNT_DIR.${NC}"
        return 0
    fi

    if ps aux | grep -i "[l]tfs" >/dev/null 2>&1; then
        echo -e "${RED}[✗] An LTFS process is already running. Not starting another mount.${NC}"
        ps aux | grep -i "[l]tfs"
        return 1
    fi

    if [ ! -d "$LTO_MOUNT_DIR" ]; then
        echo "Creating mount point: $LTO_MOUNT_DIR"
        mkdir -p "$LTO_MOUNT_DIR"
        check_success
    fi

    echo "Mounting HPE LTFS file system using macFUSE FSKit backend..."
    ltfs -o devname=0,backend=fskit,noalerts "$LTO_MOUNT_DIR"
    check_success

    sleep 5

    if mount | grep -q " on $LTO_MOUNT_DIR "; then
        echo -e "${GREEN}[✓] LTO mounted successfully at $LTO_MOUNT_DIR.${NC}"
        mount | grep " on $LTO_MOUNT_DIR "
    else
        echo -e "${RED}[✗] LTFS command completed, but mount was not detected at $LTO_MOUNT_DIR.${NC}"
        return 1
    fi
}

unmount_lto() {
    if mount | grep -q " on $LTO_MOUNT_DIR "; then
        echo "Safely unmounting LTO tape system..."

        if pwd | grep -q "^$LTO_MOUNT_DIR"; then
            cd "$HOME" || cd /
        fi

        sync
        diskutil unmount "$LTO_MOUNT_DIR" || umount "$LTO_MOUNT_DIR"
        check_success

        if mount | grep -q " on $LTO_MOUNT_DIR "; then
            echo -e "${RED}[✗] $LTO_MOUNT_DIR still appears mounted.${NC}"
            return 1
        else
            echo -e "${GREEN}[✓] LTO unmounted successfully.${NC}"
        fi
    fi
}

verify_md5() {
    local filename="$1"
    local sidecar_found=false

    for file in "$OUTPUT_DIR/$filename"*.md5; do
        if [ "$sidecar_found" = false ]; then
             echo -e "\n${BOLD}Running integrity checksum checks (sidecars)...${NC}"
        fi
        sidecar_found=true

        local base_file="${file%.md5}"
        if [ -f "$base_file" ]; then
            local original_md5=$(awk '{print $1}' "$file")
            local new_md5=$(calculate_hash "$base_file" "md5")

            echo "  File: $(basename "$base_file")"
            if [ "$original_md5" != "$new_md5" ]; then
                echo -e "  ${RED}[✗] MD5 MISMATCH detected for $base_file${NC}"
            else
                echo -e "  ${GREEN}[✓] Integrity verified. MD5 match!${NC}"
            fi
        else
            echo -e "  ${YELLOW}[⚠️] Warning: Sidecar checksum found without matching tracking asset: $file${NC}"
        fi
    done
}

load_configuration "$1"

while true; do
    print_header "AV DIGITAL FILE RETRIEVAL SYSTEM"
    echo -e "Current Target Output: ${GREEN}$OUTPUT_DIR${NC}"
    echo -e "1) Search and Retrieve File"
    echo -e "2) Run Path Configuration Setup"
    echo -e "3) Exit System"
    echo "----------------------------------------------------------------"
    read -p "Select choice [1-3]: " main_choice

    case "$main_choice" in
        1)
            read -p "Enter the search filename: " search_target
            if [[ -n "$search_target" ]]; then
                search_files "$search_target"
            else
                echo -e "${RED}Filename cannot be blank.${NC}"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        2)
            run_config_wizard
            ;;
        3)
            echo -e "\nExiting pipeline. Goodbye!"
            break
            ;;
        *)
            echo -e "${RED}Invalid menu choice selection.${NC}"
            sleep 1
            ;;
    esac
done
