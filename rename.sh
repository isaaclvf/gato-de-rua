#!/bin/bash

# Find all files and directories recursively, process them in reverse order to handle nested paths
find . -depth -name '*-*' | while read -r path; do
    # Get the directory and basename of the file/directory
    dir=$(dirname "$path")
    base=$(basename "$path")
    
    # Replace all '-' with '_' in the basename
    newbase=${base//-/_}
    
    # Only rename if the new name is different
    if [ "$base" != "$newbase" ]; then
        # Construct the new full path
        newpath="$dir/$newbase"
        
        # Perform the rename
        mv -v "$path" "$newpath"
    fi
done
