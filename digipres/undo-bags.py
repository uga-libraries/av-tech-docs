# Script to undo bags when something went wrong

import os
import shutil
import sys

def undo_bags(root_directory):
    # Iterate over each directory in the root directory
    for dir_name in os.listdir(root_directory):
        # Only process directories with the _bag suffix
        if dir_name.endswith("_bag"):
            dir_path = os.path.join(root_directory, dir_name)
            if os.path.isdir(dir_path):
                # The unique ID is the directory name minus the _bag suffix
                unique_id = dir_name[:-4]
                new_dir_path = os.path.join(root_directory, unique_id)

                # Create a new directory with the unique ID name
                os.makedirs(new_dir_path, exist_ok=True)

                # Path to the 'data' folder inside the bag
                data_folder_path = os.path.join(dir_path, 'data')

                # Move all files and subdirectories from the 'data' folder to the new directory
                if os.path.exists(data_folder_path) and os.path.isdir(data_folder_path):
                    for item_name in os.listdir(data_folder_path):
                        item_path = os.path.join(data_folder_path, item_name)
                        shutil.move(item_path, new_dir_path)

                # Remove the bagit manifest and tag files from the root of the bag directory
                for item_name in os.listdir(dir_path):
                    item_path = os.path.join(dir_path, item_name)
                    if os.path.isfile(item_path):
                        os.remove(item_path)

                # Finally, remove the original bag directory
                shutil.rmtree(dir_path)

if __name__ == "__main__":
    # Check if the root_directory is provided as an argument
    if len(sys.argv) != 2:
        print("Usage: python3 /path/to/script.py [root_directory]")
        sys.exit(1)

    # Get the root directory from the command line argument
    root_directory = sys.argv[1]

    # Call the function to undo the bags
    undo_bags(root_directory)
