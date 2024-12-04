#!/bin/bash

#################
#
#	CONSTANTS
#
#################
DEV_DIR="$HOME/Development"
CUS_DIR="customers"
THIRD_PARTY_DIR="3rdparty"
TEST_DIR="testing"

REPOS_URL="git@github.com:callista-tools/"
IDEA_REPO_URL="git@github.com:Liam-Callista/odoo_idea.git"

ODOO_VERSION_REGEX='[0-9]+(\.[0-9]+)?'

REQUIRED_DEPENDENCIES=("git" "pre-commit" "sed")

#################
#
#	HELP OPTION
#
#################
if [[ " $* " == *" --help "* || " $* " == *" -h "* ]]; then
    echo
    echo "Usage: $0 [<project_name>] [<folder_name>] [<version_number>]"
    echo ""
    echo "Initialize a new Odoo project environment by cloning a project repository"
    echo "and setting up IntelliJ IDEA project files (.idea)."
    echo ""
    echo "Arguments:"
    echo "  <project_name>   (Optional) Name of the specific project to clone."
    echo "  <folder_name>    (Optional) Directory under '~/Development'."
    echo "  <version_number> (Optional) Odoo version number to set up the environment."
    echo ""
    echo "Examples (Missing args are prompted):"
    echo "  $0"
    echo "  $0 cim"
    echo "  $0 cim customers"
    echo "  $0 cim customers 17"
    echo ""
    echo "Notes:"
    echo "  - Also works with existing project folders."
    echo ""
    echo "Options:"
    echo "  [-h, --help]       Show this help message and exit."
    echo
    exit 0
fi

#######################################
#
#	DEFINE HELPER FUNCTIONS
#
#######################################
pause() {
    read -n 1 -s -r -p $'\nPress any key to continue...'
    echo
}

handle_exit() {
    local message="$1"
    echo
    echo "Operation aborted"
    if [ -n "$message" ]; then
        echo "$message"
    fi
    read -n 1 -s -r -p 'Press any key to exit...'
    echo
    exit 1
}

list_folders() {
    local dir="$1"
    find "$dir" -mindepth 1 -maxdepth 1 -type d -printf "%f\n"
}

##########################
#
#   DEPENDENCY CHECK
#
##########################
echo "# CHECKING DEPENDENCIES"
missing_dependencies=()

# Check each dependency
for dep in "${REQUIRED_DEPENDENCIES[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        missing_dependencies+=("$dep")
    fi
done

# Handle missing dependencies
if [ ${#missing_dependencies[@]} -gt 0 ]; then
    echo "The following dependencies are missing and need to be installed:"
    for dep in "${missing_dependencies[@]}"; do
        echo "  - $dep"
    done
    handle_exit
fi

###########################################
#
#	DEFINE ARGUMENTS/PARAMETERS
#
###########################################
echo "# ARGUMENTS"
# Loop until a valid project name is provided
while true; do
    # Check if a project name is provided as a second argument or prompt the user
    project_name="$1"
    if [[ -z "$project_name" ]]; then
        read -r -p "Enter the project name: " project_name
    fi

    # Validate project name
    if [[ ! "$project_name" =~ ^[a-z0-9_-]+$ ]]; then
        echo -e "You must provide a valid project name.\n"
        set -- # Clear the arguments
    else
        break
    fi
done

# Loop until a valid folder name is provided
while true; do
    # Check if a project name is provided as a second argument or prompt the user
    folder_name="$2"
    if [[ -z "$folder_name" ]]; then
        echo -e "Available folders:\n$(list_folders "$HOME/Development")"
        read -r -p "Enter the folder name (empty for '$CUS_DIR'): " folder_name
    fi

    # Fill in default if $version_input is empty and $CUS_DIR is available
    if [[ -z "$folder_name" && -n "$CUS_DIR" ]]; then
        folder_name="$CUS_DIR"
        echo "Selected default directory: $folder_name"
        echo
    fi

    # Validate folder name: Check if folder exists
    if [[ ! -d "$HOME/Development/$folder_name" ]]; then
        echo -e "The folder '$folder_name' does not exist in $HOME/Development.\n"
        set -- # Clear the arguments
    else
        folder_name=${folder_name}
        break
    fi
done

# Check for main branch
PROJECT_REPO_URL="$REPOS_URL${project_name}.git"
DEFAULT_VERSION=$(git ls-remote --symref "$PROJECT_REPO_URL" HEAD 2>/dev/null | grep -oP "(?<=refs/heads/)$ODOO_VERSION_REGEX")

# Loop until a valid version number is provided
while true; do
    # Check if a version number is provided as an argument or prompt the user
    version_input="$3"
    if [[ -z "$version_input" ]]; then
        read -r -p "Enter a version number${DEFAULT_VERSION:+" (empty for '$DEFAULT_VERSION')"}: " version_input
    fi

    # Fill in default if $version_input is empty and $DEFAULT_VERSION is available
    if [[ -z "$version_input" && -n "$DEFAULT_VERSION" ]]; then
        version_input="$DEFAULT_VERSION"
        echo "Selected default version: $version_input"
    fi

    # Validate input: it should be a number or a number with one decimal place
    if [[ ! "$version_input" =~ ^$ODOO_VERSION_REGEX$ ]]; then
        echo -e "You must provide a valid version number (e.g., 18 or 18.0).\n"
        set -- # Clear the arguments
    else
        # Extract the major version number (integer part)
        version_input=${version_input%%.*}
        break
    fi
done

###################################################
#
#	GETTING CALLISTA PROJECT FROM GIT
#
###################################################
echo
echo "# GIT CALLISTA PROJECT"
# Set destination directory (multiversion)
if [ "$folder_name" == "$CUS_DIR" ]; then
    DEST_DIR="$DEV_DIR/${folder_name}/${project_name}"
else
    DEST_DIR="$DEV_DIR/${folder_name}/${project_name}${version_input}"
fi

{
    # Clone the GitHub repository into the destination directory
    git clone "$PROJECT_REPO_URL" "$DEST_DIR" --branch ${version_input}.0
} || {
    # Check if the clone was successful
    echo
    read -p "Do you want to continue by adding .idea? [Y/N]: " user_choice
    if [[ ! "$user_choice" =~ ^[Yy]((E|e)(S|s)?)?$ ]]; then
        handle_exit
    fi
}

###############################################
#
#	GETTING IDEA TEMPLATE FROM GIT
#
###############################################
echo
echo "# GIT IDEA TEMPLATE"
TEMP_DIR="${DEST_DIR}/temp"

# Clone the GitHub repository into the destination directory
git clone "$IDEA_REPO_URL" "$TEMP_DIR" || handle_exit "There was an error during template cloning."

# Check if the .idea folder already exists
if [ -d "$DEST_DIR/.idea" ]; then
    echo
    echo "WARNING"
    echo "The .idea folder already exists in $DEST_DIR."
    echo "Overwriting it may result in the loss of project settings or git shelves."
    read -p "Do you want to overwrite it? [Y/N]: " user_choice
    if [[ "$user_choice" =~ ^[Yy]((E|e)(S|s)?)?$ ]]; then
        # Remove existing .idea folder
        rm -rf "$DEST_DIR/.idea"
    else
        # Clean up and exit
        rm -rf "$TEMP_DIR"
        handle_exit "The .idea folder was not replaced."
    fi
fi

# Extract the .idea directory from TEMP_DIR to DEST_DIR
mv "$TEMP_DIR/idea" "$DEST_DIR/.idea" && {
    # If success, Clean up
    rm -rf "$TEMP_DIR"
} || handle_exit "There was an error when moving the temp folder."
echo "New .idea folder created in $DEST_DIR."

###################################
#
#	PLACEHOLDER REPLACES
#
###################################
echo "## PLACEHOLDER REPLACES"
{
    # Go through all files
    find "$DEST_DIR/.idea" -type f | while read -r filename; do
        new_filename=$filename

        # Add version number to text and filename if multiversion (multiversion)
        if [[ "$folder_name" == "$CUS_DIR" || "$folder_name" == "$THIRD_PARTY_DIR" ]]; then
            sed -i "s/#multi_version_input#/${version_input}/g" "$filename"
            new_filename=$(echo "$filename" | sed "s/#multi_version_input#/$version_input/")
        else
            sed -i "s/#multi_version_input#//g" "$filename"
            new_filename=$(echo "$filename" | sed "s/#multi_version_input#//")
        fi

        # Remove or handle testing code blocks
        if [ "$folder_name" == "$TEST_DIR" ]; then
            # Delete all text between #testing_code_start# and #testing_code_end#
            sed -i ':a;N;$!ba;s/#testing_code_start#.*#testing_code_end#//g' "$filename"
        else
            # Only delete lines containing the markers #testing_code_start# and #testing_code_end#
            sed -i 's/#testing_code_start#//g' "$filename"
            sed -i 's/#testing_code_end#//g' "$filename"
        fi

        # Text replaces
        sed -i "s/#version_input#/${version_input}/g" "$filename"
        sed -i "s/#project_name#/${project_name}/g" "$filename"
        sed -i "s/#folder_name#/${folder_name}/g" "$filename"
        sed -i "s/#testing_folder#/${TEST_DIR}/g" "$filename"

        # File renames
        new_filename=$(echo "$new_filename" | sed "s/#version_input#/$version_input/")
        new_filename=$(echo "$new_filename" | sed "s/#project_name#/$project_name/")
        if [ "$filename" != $new_filename ]; then
            mv "$filename" "$new_filename"
        fi
    done
} || {
    # Remove faulty .idea folder if replaces failed
    rm -rf "$DEST_DIR/.idea"
    handle_exit "There was an error when replacing the placeholders."
}

#############################
#
#	PRE-COMMIT
#
#############################
echo
echo "# PRE-COMMIT"
{
    cd $DEST_DIR
    pre-commit install
} || handle_exit "There was an error during the pre-commit."

##################
#
#	END
#
##################
echo
echo "# END"
echo "Project setup completed at $DEST_DIR."
pause
