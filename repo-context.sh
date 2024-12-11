#!/bin/bash

# Maximum repository size in MB (default 1GB)
MAX_REPO_SIZE=1000

# Add this near the top with other constants
BASE_OUTPUT_DIR="$HOME/Documents/VSC/repo-context/repo-contexts"

# Function to show help message
show_help() {
    cat << EOF
Usage: $0 [options] <github_repo_url>

Options:
    -h, --help                Show this help message
    -s, --max-size SIZE       Maximum repository size in MB (default: ${MAX_REPO_SIZE}MB)
    -o, --output FILE         Output file name (default: repo_name_context.md)
    -y, --yes                 Skip interactive extension selection

Example:
    $0 https://github.com/user/repo
    $0 --max-size 2000 https://github.com/user/repo
EOF
    exit 0
}

# Function to show progress
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local progress=$((current * width / total))
    
    printf "\rProgress: ["
    printf "%${progress}s" | tr ' ' '#'
    printf "%$((width - progress))s" | tr ' ' '-'
    printf "] %d%%" $((current * 100 / total))
}

# Function to process files
process_files() {
    local repo_dir="$1"
    shift
    local selected_extensions=("$@")
    
    echo "# Repository Contents" > "$output_file"
    echo "" >> "$output_file"
    
    for ext in "${selected_extensions[@]}"; do
        # Skip if extension is empty or invalid
        if [[ -z "$ext" || ! "$ext" =~ ^[a-zA-Z0-9]+$ ]]; then
            continue
        fi
        
        cd "$repo_dir"
        # First check if any files exist with this extension
        local file_list=$(find . -type f -name "*.$ext" -not -path '*/\.*' 2>/dev/null | sed 's|^./||' | sort)
        
        # Only proceed if file_list is not empty
        if [ -n "$file_list" ]; then
            echo "## Files with .$ext extension" >> "$output_file"
            echo "" >> "$output_file"
            
            # File structure
            echo "### File Structure" >> "$output_file"
            echo "" >> "$output_file"
            echo "\`\`\`plaintext" >> "$output_file"
            while IFS= read -r file; do
                echo "├── $file" >> "$output_file"
            done <<< "$file_list"
            echo "\`\`\`" >> "$output_file"
            echo "" >> "$output_file"
            
            # File contents
            echo "### File Contents" >> "$output_file"
            echo "" >> "$output_file"
            
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    echo "#### 📄 $file" >> "$output_file"
                    echo "" >> "$output_file"
                    echo "\`\`\`$ext" >> "$output_file"
                    cat "$file" >> "$output_file"
                    echo "\`\`\`" >> "$output_file"
                    echo "" >> "$output_file"
                    echo "---" >> "$output_file"
                    echo "" >> "$output_file"
                fi
            done <<< "$file_list"
        fi
    done
}

# Function to scan repository for file extensions
scan_extensions() {
    local repo_dir=$1
    
    cd "$repo_dir"
    
    # Find all files and extract unique extensions, excluding hidden files and directories
    local extensions=$(find . -type f \
        -not -path '*/\.*' \
        -not -path '*/venv/*' \
        -name '*.*' 2>/dev/null | 
        sed -n 's/.*\.\([^.]*\)$/\1/p' | # Only get the last extension
        sort -u)
    
    # Print header
    echo ""
    
    # Print extensions in a numbered list
    local i=1
    local ext_array=()
    while read -r ext; do
        # Skip empty lines and invalid extensions
        if [[ -n "$ext" && "$ext" =~ ^[a-zA-Z0-9]+$ ]]; then
            echo "[$i] $ext"
            ext_array+=("$ext")
            ((i++))
        fi
    done <<< "$extensions"
    
    echo ""
    echo "Select extensions to print (number of extension, space between extensions):"
    
    # Print the extensions space-separated (this is still needed for internal processing)
    echo "${ext_array[@]}"
}

# Function to select extensions
select_extensions() {
    local extensions=("$@")
    local selected=()
    
    echo -e "\nSelect extensions to process (enter numbers separated by space, or 'all' for all extensions):"
    read -r input
    
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    if [ "$input" = "all" ]; then
        echo "${extensions[@]}"
        return
    fi
    
    # Validate input is only numbers and spaces
    if ! [[ "$input" =~ ^[0-9[:space:]]+$ ]]; then
        echo "Invalid input. Using all extensions."
        echo "${extensions[@]}"
        return
    fi
    
    for num in $input; do
        if [ $num -ge 1 ] && [ $num -le ${#extensions[@]} ]; then
            selected+=("${extensions[$((num-1))]}")
        fi
    done
    
    if [ ${#selected[@]} -eq 0 ]; then
        echo "No valid extensions selected. Using all extensions."
        echo "${extensions[@]}"
        return
    fi
    
    echo "${selected[@]}"
}

# Function to check repository size
check_repo_size() {
    local repo_url=$1
    local max_size_bytes=$((MAX_REPO_SIZE * 1024 * 1024))
    
    echo "Checking repository size..."
    local size=$(git ls-remote --get-url $repo_url | xargs git ls-remote --refs | awk '{total += $2} END {print total}')
    
    if [ $size -gt $max_size_bytes ]; then
        echo "Error: Repository size ($(($size / 1024 / 1024))MB) exceeds maximum allowed size (${MAX_REPO_SIZE}MB)"
        echo "Use --max-size option to increase the limit if needed."
        exit 1
    fi
}

# Parse command line arguments
output_file=""
skip_selection=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -s|--max-size)
            MAX_REPO_SIZE=$2
            shift 2
            ;;
        -o|--output)
            output_file="$2"
            shift 2
            ;;
        -y|--yes)
            skip_selection=true
            shift
            ;;
        *)
            repo_url="$1"
            shift
            ;;
    esac
done

# Check if a repository URL is provided
if [ -z "$repo_url" ]; then
    echo "Error: No repository URL provided"
    show_help
fi

# Check if required tools are installed
for tool in git fd; do
    if ! command -v $tool &> /dev/null; then
        echo "Error: $tool is not installed. Please install $tool and try again."
        exit 1
    fi
done

# Extract repository name from URL if output file not specified
if [ -z "$output_file" ]; then
    repo_name=$(basename -s .git "$repo_url")
    output_file="${BASE_OUTPUT_DIR}/${repo_name}_context.md"
else
    # If output file is specified but doesn't include a path, add the base directory
    if [[ "$output_file" != /* && "$output_file" != ~* ]]; then
        output_file="${BASE_OUTPUT_DIR}/${output_file}"
    fi
fi

# Add these debug lines after the output_file is set
# echo "DEBUG: Base output directory: ${BASE_OUTPUT_DIR}"
# echo "DEBUG: Full output file path: ${output_file}"
# echo "DEBUG: Checking if base directory exists..."
# if [ -d "${BASE_OUTPUT_DIR}" ]; then
#     echo "DEBUG: Base directory exists"
#     ls -la "${BASE_OUTPUT_DIR}"
# else
#     echo "DEBUG: Base directory does not exist"
# fi

# Create the base directory if it doesn't exist
mkdir -p "${BASE_OUTPUT_DIR}"

# Remove the output file if it already exists
rm -f "$output_file"

# Check repository size
check_repo_size "$repo_url"

# Create a temporary directory for cloning
temp_dir=$(mktemp -d)
echo "Cloning repository..."

# Clone the repository with progress
git clone --progress "$repo_url" "$temp_dir" 2>&1 | grep -E 'Receiving objects|Resolving deltas'
echo "Clone completed. Starting extension scan..."

# # Debug: List directory contents
# echo "DEBUG: Repository cloned to: $temp_dir"
# echo "DEBUG: Directory contents:"
# ls -la "$temp_dir"

# Scan for extensions - store output in a variable first
echo "Scanning extensions in: $temp_dir"
extensions_output=$(scan_extensions "$temp_dir")
echo "Raw extensions output: $extensions_output"
echo ""

# Convert to array
IFS=' ' read -r -a available_extensions <<< "$(echo "$extensions_output" | tail -n 1)"

# Select extensions to process
if [ "$skip_selection" = false ]; then
    selected_extensions=($(select_extensions "${available_extensions[@]}"))
else
    selected_extensions=("${available_extensions[@]}")
fi

# echo "Processing files with extensions: ${selected_extensions[*]}"
process_files "$temp_dir" "${selected_extensions[@]}"

# Before cleanup, move the output file to its final destination
if [ -f "$temp_dir/$(basename "$output_file")" ]; then
    mv "$temp_dir/$(basename "$output_file")" "$output_file"
    echo "DEBUG: Moved file from temp directory to final destination"
fi

# Change back to the original directory
cd "$OLDPWD"

# Debug output BEFORE cleanup
# echo "DEBUG: Repository cloned to: $temp_dir"
# echo "DEBUG: Directory contents:"
# ls -la "$temp_dir"

# Clean up: remove the temporary directory
rm -rf "$temp_dir"

echo -e "\nRepository contents have been processed and combined into $output_file"

# After the mv command
echo "Checking if output file was created..."
if [ -f "$output_file" ]; then
    echo "Output file exists at: $output_file"
else
    echo "Output file was not created"
fi