#!/bin/bash

# Usage: ./new_idea.sh <version_number>
# Example: ./new_idea.sh 17

# Loop until a valid version number is provided
while true; do
    # Check if a version number is provided as an argument or prompt the user
    if [[ $# -eq 1 ]]; then
        version_input="$1"
    else
        read -r -p "Enter a version number: " version_input
    fi

    # Validate input: it should be a number or a number with one decimal place
    if [[ -z "$version_input" || ! "$version_input" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "You must provide a valid version number (e.g., 18 or 18.0)."
        set -- # Clear the arguments
    else
        # Extract the major version number (integer part)
        version_input=${version_input%%.*}
        break
    fi
done

# Set repository URL and destination directory
REPO_URL="git@github.com:Liam-Callista/odoo_idea.git"
DEST_DIR="$HOME/Development/0_setups/pycharm_ideas/${version_input}.0"

# Clone the GitHub repository into the destination directory
git clone "$REPO_URL" "$DEST_DIR"

# Check if the clone was successful
if [ $? -ne 0 ]; then
    echo "Failed to clone repository: $REPO_URL"
    exit 1
fi

# Remove the .git directory
rm -rf "$DEST_DIR/.git"

# Find all files in the destination directory and process each one
find "$DEST_DIR" -type f | while read -r file; do
    # Replace text within files
    sed -i "s/odoo18/odoo$version_input/g" "$file"
    sed -i "s/Odoo 18/Odoo $version_input/g" "$file"
    sed -i "s/rename18/rename$version_input/g" "$file"
    sed -i "s/testlib18/testlib$version_input/g" "$file"
done

# Rename files containing 'Odoo_18' in their names
find "$DEST_DIR" -depth -name '*Odoo_18*' | while read -r filename; do
    new_filename=$(echo "$filename" | sed "s/Odoo_18/Odoo_$version_input/g")
    mv "$filename" "$new_filename"
done

echo "New .idea folder created in $DEST_DIR."

