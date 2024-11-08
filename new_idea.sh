#!/bin/bash

# new_idea.sh
# 
# A script to initialize a new Odoo project environment by cloning a specified project 
# repository and setting up the required IntelliJ IDEA project files (.idea).
#
# Usage:
#   ./new_idea.sh [<version_number>] [<project_name>] [<folder_name>]
#
# Arguments:
#   <version_number> : Optional. The Odoo version
#   <project_name>   : Optional. Name of the specific project to clone from the callista-tools GitHub
#   <folder_name>    : Optional. Directory under "$HOME/Development"
#
# Example:
#   ./new_idea.sh                     
#   ./new_idea.sh 17                
#   ./new_idea.sh 17 cim          
#   ./new_idea.sh 17 cim customers
#
# Notes:
# - Also works with existing project folders


DEV_DIR="$HOME/Development"
REPOS_URL="git@github.com:callista-tools/"
IDEA_REPO_URL="git@github.com:Liam-Callista/odoo_idea.git"

#######################################
#
#	DEFINE HELPER FUNCTIONS
#
#######################################
pause() {
    read -n 1 -s -r -p $'\nPress any key to continue...'
    echo
}

check_success() {
    # Use the provided argument or default to $? (exit status of the last command)
    local exit_status=${1:-$?}

    if [ "$exit_status" -ne 0 ]; then
        pause
        exit 1
    fi
}

list_folders() {
    local dir="$1"
    find "$dir" -mindepth 1 -maxdepth 1 -type d -printf "%f\n"
}

rename_files() {
    local dir="$1"
    local search="$2"
    local replace="$3"

    find "$dir" -depth -name "*$search*" | while read -r filename; do
        new_filename=$(echo "$filename" | sed "s/$search/$replace/")
        mv "$filename" "$new_filename"
    done
}


###########################################
#
#	DEFINE ARGUMENTS/PARAMETERS
#
###########################################
echo "# SETUP"
# Loop until a valid version number is provided
while true; do
    # Check if a version number is provided as an argument or prompt the user
    if [[ $# -ge 1 ]]; then
        version_input="$1"
    else
        read -r -p "Enter a version number: " version_input
    fi

    # Validate input: it should be a number or a number with one decimal place
    if [[ ! "$version_input" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "You must provide a valid version number (e.g., 18 or 18.0).\n"
        set -- # Clear the arguments
    else
        # Extract the major version number (integer part)
        version_input=${version_input%%.*}
        break
    fi
done

# Loop until a valid folder name is provided
while true; do
    # Check if a project name is provided as a second argument or prompt the user
    if [[ $# -ge 3 ]]; then
        folder_name="$3"
    else
    	echo -e "Available folders:\n$(list_folders "$HOME/Development")"
        read -r -p "Enter the folder name (empty for \"customers\"): " folder_name
    fi

    # Validate folder name: it should only contain a-Z or be empty
    if [[ ! "$folder_name" =~ ^[a-z]*$ ]]; then
        echo -e "You must provide a valid folder name containing only letters.\n"
        set -- # Clear the arguments
    # Check if folder exists
    elif [[ ! -d "$HOME/Development/$folder_name" ]]; then
        echo -e "The folder '$folder_name' does not exist in $HOME/Development.\n"
    else
        folder_name=${folder_name:-"customers"}
        break
    fi
done

# Loop until a valid project name is provided
while true; do
    # Check if a project name is provided as a second argument or prompt the user
    if [[ $# -ge 2 ]]; then
        project_name="$2"
    else
        read -r -p "Enter the project name: " project_name
    fi

    # Validate project name: it should only contain a-Z and not be empty
    if [[ ! "$project_name" =~ ^[a-z-]+$ ]]; then
        echo -e "You must provide a valid project name containing only letters.\n"
        set -- # Clear the arguments
    else
        break
    fi
done

# Set destination directory (multiversion)
if [ "$folder_name" == "customers" ]; then
    DEST_DIR="$DEV_DIR/${folder_name}/${project_name}"
else
    DEST_DIR="$DEV_DIR/${folder_name}/${project_name}${version_input}"
fi

###################################################
#
#	GETTING CALLISTA PROJECT FROM GIT
#
###################################################
echo
echo "# GIT CALLISTA PROJECT"
# Clone the GitHub repository into the destination directory (multiversion)
if [ "$folder_name" == "customers" ]; then
    git clone "$REPOS_URL${project_name}.git" "$DEST_DIR"
else
    git clone "$REPOS_URL${project_name}.git" "$DEST_DIR" --branch ${version_input}.0
fi

# Check if the clone was successful
if [ $? -ne 0 ]; then
    echo
    read -p "Do you want to continue by adding .idea? (Y/N): " user_choice
    if [[ ! "$user_choice" =~ ^[Yy]((E|e)(S|s)?)?$ ]]; then
        exit 1
    fi
fi

###############################################
#
#	GETTING IDEA TEMPLATE FROM GIT
#
###############################################
echo
echo "# GIT IDEA TEMPLATE"
TEMP_DIR="${DEST_DIR}/temp"

# Clone the GitHub repository into the destination directory
git clone "$IDEA_REPO_URL" "$TEMP_DIR"
check_success

# Extract the .idea directory from TEMP_DIR to DEST_DIR
mv "$TEMP_DIR/.idea" "$DEST_DIR"
mv_status=$?

# Clean up by removing the temporary directory
rm -rf "$TEMP_DIR"

# TODO maybe prompt to delete existing .idea folder (warn about possibly losing project settings and git shelf)
check_success $mv_status

#############################
#
#	TEXT REPLACES
#
#############################
echo "## TEXT REPLACES"
# Add version number to projectname (multiversion)
if [ "$folder_name" != "customers" ]; then
    find "$DEST_DIR/.idea" -type f | while read -r file; do
        sed -i "s/#multi_version_input#/${version_input}/g" "$file"
    done
fi

# Replace all place_holders with actual data inside files (multiversion)
find "$DEST_DIR/.idea" -type f | while read -r file; do
    sed -i "s/#version_input#/${version_input}/g" "$file"
    sed -i "s/#project_name#/${project_name}/g" "$file"
    sed -i "s/#folder_name#/${folder_name}/g" "$file"
    sed -i "s/#multi_version_input#//g" "$file"
done

#############################
#
#	FILE RENAMES
#
#############################
echo "## FILE RENAMES"
# Replace all place_holders with actual data in file names (multiversion)
rename_files "$DEST_DIR/.idea" "#version_input#" "$version_input"
rename_files "$DEST_DIR/.idea" "#project_name#" "$project_name"
rename_files "$DEST_DIR/.idea" "#multi_version_input#" "$version_input"

#############################
#
#	PRE-COMMIT
#
#############################
echo
echo "# PRE-COMMIT"
cd $DEST_DIR
pre-commit install

##################
#
#	END
#
##################
echo
echo "# END"
echo "New .idea folder created in $DEST_DIR."
pause

