#!/bin/bash

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ -d "./templates/Skills" ]; then
    SOURCE_DIR="./templates/Skills"
elif [ -d "$HOME/.ai-shadow-vault/templates/Skills" ]; then
    SOURCE_DIR="$HOME/.ai-shadow-vault/templates/Skills"
elif [ -d "$SCRIPT_DIR/../templates/Skills" ]; then
    SOURCE_DIR="$SCRIPT_DIR/../templates/Skills"
else
    echo -e "${RED}Error: Could not locate templates/Skills directory.${NC}"
    exit 1
fi
TARGET_BASE_DIR="$HOME/.gemini/skills"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}AI Shadow Vault - Skills Installer${NC}"
echo "=================================="

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Error: Source directory '$SOURCE_DIR' not found.${NC}"
    exit 1
fi

# Ensure target directory exists for Gemini
if [ ! -d "$TARGET_BASE_DIR" ]; then
    mkdir -p "$TARGET_BASE_DIR"
fi

# Array to store available skills
declare -a skill_files
declare -a skill_names
declare -a skill_descriptions

# Read skills
echo -e "Scanning available skills in ${YELLOW}$SOURCE_DIR${NC}..."
count=0
for file in "$SOURCE_DIR"/*.md; do
    [ -e "$file" ] || continue
    
    # Extract name from frontmatter
    name=$(sed -n '/^---$/,/^---$/p' "$file" | grep "^name:" | head -n 1 | sed 's/name: *//' | tr -d '"' | tr -d "'")
    desc=$(sed -n '/^---$/,/^---$/p' "$file" | grep "^description:" | head -n 1 | sed 's/description: *//')
    
    # If no name in frontmatter, use filename (lowercase, no ext)
    if [ -z "$name" ]; then
        filename=$(basename -- "$file")
        name="${filename%.*}"
        name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    fi

    # Trim whitespace
    name=$(echo "$name" | xargs)
    
    skill_files[$count]="$file"
    skill_names[$count]="$name"
    skill_descriptions[$count]="$desc"
    ((count++))
done

if [ $count -eq 0 ]; then
    echo -e "${RED}No skill files found in $SOURCE_DIR${NC}"
    exit 0
fi

# Function to get content without frontmatter
get_clean_content() {
    local file=$1
    # Sed command to print lines starting from the line after the second '---'
    # If no frontmatter (no starting ---), print whole file.
    if head -n 1 "$file" | grep -q "^---"; then
        sed '1,/^---$/d' "$file"
    else
        cat "$file"
    fi
}

# Function to install a skill to Gemini (Global)
install_gemini_skill() {
    local index=$1
    local file="${skill_files[$index]}"
    local name="${skill_names[$index]}"
    local target_dir="$TARGET_BASE_DIR/$name"
    local target_file="$target_dir/SKILL.md"

    echo -e "  [Gemini] Installing $name..."

    # Create directory
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
    fi

    # Check for overwrite
    if [ -f "$target_file" ]; then
        # Silent overwrite or backup could be better, but sticking to simple overwrite for batch ops
        # or prompt if running individually. For 'Install All' we might want to be quieter.
        # For now, let's just overwrite for simplicity in this refactor.
        true
    fi

    # Copy file
    cp "$file" "$target_file"
}

# Function to append skill to a config file
append_skill_to_file() {
    local index=$1
    local target_file=$2
    local ia_name=$3
    
    local file="${skill_files[$index]}"
    local name="${skill_names[$index]}"
    local desc="${skill_descriptions[$index]}"
    
    echo -e "  [$ia_name] Adding $name to $target_file..."

    # Create file if it doesn't exist
    if [ ! -f "$target_file" ]; then
        mkdir -p "$(dirname "$target_file")"
        touch "$target_file"
        echo -e "# $ia_name Rules\n" > "$target_file"
    fi

    # Check if skill is already present (simple grep)
    if grep -q "Skill: $name" "$target_file"; then
        echo -e "    Skipping $name (already in file)."
        return
    fi

    # Append Content
    {
        echo -e "\n\n"
        echo "---"
        echo "## Skill: $name"
        echo "> $desc"
        echo ""
        get_clean_content "$file"
    } >> "$target_file"
}

# ---------------------------------------------------------
# Step 1: Select AI Assistants
# ---------------------------------------------------------
echo -e "\n${BLUE}Which AI Assistants are you using?${NC}"
declare -a available_ias=("Gemini CLI (Global)" "Cursor (.cursorrules)" "Windsurf (.windsurfrules)" "GitHub Copilot" "Claude (CLAUDE.md)")
declare -a selected_ias_indices

for ((i=0; i<${#available_ias[@]}; i++)); do
    echo -e "  $((i+1)). ${available_ias[$i]}"
done

echo -e "\nEnter numbers separated by space (e.g., '1 2 4') or 'all':"
read -p "> " ia_selection

if [[ "$ia_selection" == "all" ]]; then
    selected_ias_indices=(0 1 2 3 4)
else
    for num in $ia_selection; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#available_ias[@]}" ]; then
            selected_ias_indices+=($((num-1)))
        fi
    done
fi

if [ ${#selected_ias_indices[@]} -eq 0 ]; then
    echo -e "${RED}No AI Assistants selected. Exiting.${NC}"
    exit 0
fi

# ---------------------------------------------------------
# Step 2: Select Skills
# ---------------------------------------------------------
echo -e "\n${BLUE}Available Skills:${NC}"
for ((i=0; i<count; i++)); do
    echo -e "  $((i+1)). ${GREEN}${skill_names[$i]}${NC}"
done

echo -e "\nEnter numbers of skills to install (e.g., '1 3') or 'all':"
read -p "> " skill_selection

declare -a selected_skills_indices

if [[ "$skill_selection" == "all" ]]; then
    for ((i=0; i<count; i++)); do
        selected_skills_indices+=($i)
    done
else
    for num in $skill_selection; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$count" ]; then
            selected_skills_indices+=($((num-1)))
        fi
    done
fi

if [ ${#selected_skills_indices[@]} -eq 0 ]; then
    echo -e "${RED}No skills selected. Exiting.${NC}"
    exit 0
fi

# ---------------------------------------------------------
# Step 3: Installation
# ---------------------------------------------------------
echo -e "\n${BLUE}Starting Installation...${NC}"

for skill_idx in "${selected_skills_indices[@]}"; do
    skill_name="${skill_names[$skill_idx]}"
    echo -e "\nProcessing Skill: ${YELLOW}$skill_name${NC}"

    for ia_idx in "${selected_ias_indices[@]}"; do
        case $ia_idx in
            0) # Gemini
                install_gemini_skill "$skill_idx"
                ;;
            1) # Cursor
                append_skill_to_file "$skill_idx" ".cursorrules" "Cursor"
                ;;
            2) # Windsurf
                append_skill_to_file "$skill_idx" ".windsurfrules" "Windsurf"
                ;;
            3) # Copilot
                append_skill_to_file "$skill_idx" ".github/copilot-instructions.md" "GitHub Copilot"
                ;;
            4) # Claude
                append_skill_to_file "$skill_idx" "CLAUDE.md" "Claude"
                ;;
        esac
    done
done

echo -e "\n${GREEN}Done!${NC}"
