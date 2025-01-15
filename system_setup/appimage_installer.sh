#!/bin/bash

###################
# Initialize variables
###################

## Colors
RC='\033[0m'
RED='\033[31m'      # failure
YELLOW='\033[33m'   # info
GREEN='\033[32m'    # success
BLUE='\033[34m'     # other
MAGENTA='\033[35m'  # file contents

## System variables
LOG_FILE="$HOME/logs/appimage-installer/install.log"
LOG_DIR=$(dirname "$LOG_FILE")

# Check for sudo/doas
if command -v sudo >/dev/null 2>&1; then
    SUDO_CMD="sudo"
elif command -v doas >/dev/null 2>&1 && [ -f "/etc/doas.conf" ]; then
    SUDO_CMD="doas"
else
    echo "${RED}Neither sudo nor doas is available. This script requires elevated privileges.${RC}"
    exit 1
fi

###################
# Logging Functions
###################

log() {
    local level="${1:-INFO}"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$level] - $message" | tee -a "$LOG_FILE"
}

log_step() {
    log "STEP" "${BLUE}$1${RC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$1${RC}"
}

log_file_info() {
    local file="$1"
    local description="$2"
    log "FILE" "${YELLOW}$description: $file${RC}"

    if [ -e "$file" ]; then
        log "FILE" "  - Size: $(du -h "$file" | cut -f1)"
        log "FILE" "  - Permissions: $(stat -c %A "$file")"
        log "FILE" "  - Owner: $(stat -c %U:%G "$file")"
    else
        log "WARNING" "File not found: $file"
    fi
}

init_logging() {
    # Create log directory if it doesn't exist
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        log "INFO" "Created log directory: $LOG_DIR"
    fi

    # Initialize log with system information
    echo -e "\n=== New Installation Session: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"
    log "INFO" "System Information:"
    log "INFO" "  - OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
    log "INFO" "  - Kernel: $(uname -r)"
    log "INFO" "  - Architecture: $(uname -m)"
    log "INFO" "  - User: $USER"
    log "INFO" "  - Elevation command: $SUDO_CMD"
}

###################
# Utility Functions
###################

verify_appimage() {
    local file="$1"
    log_step "Verifying AppImage file"

    # Check if file exists
    if [ ! -f "$file" ]; then
        log "ERROR" "${RED}File does not exist: $file${RC}"
        return 1
    fi

    log_file_info "$file" "AppImage file"

    # Check if file is executable or can be made executable
    if [ ! -x "$file" ]; then
        log_step "Making AppImage executable"
        chmod +x "$file" || {
            log "ERROR" "${RED}Cannot make file executable: $file${RC}"
            return 1
        }
        log_success "Successfully made AppImage executable"
    fi

    log_success "AppImage verification completed"
    return 0
}

prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local response

    read -p "$prompt [$default]: " response
    echo "${response:-$default}"
}

###################
# Main Installation Function
###################

install_appimage() {
    local appimage_path desktop_name icon_path category

    # Prompt for AppImage location
    log_step "Requesting AppImage location"
    while true; do
        read -p "Enter the path to the AppImage file: " appimage_path
        if [ -f "$appimage_path" ]; then
            if verify_appimage "$appimage_path"; then
                break
            fi
        else
            log "ERROR" "${RED}File not found: $appimage_path${RC}"
        fi
        echo -e "${YELLOW}Please provide a valid AppImage file path${RC}"
    done

    # Get application name
    log_step "Setting up application name"
    desktop_name=$(prompt_with_default "Enter the application name" "$(basename "$appimage_path" .AppImage)")
    log "INFO" "Using application name: $desktop_name"

    # Extract AppImage
    log_step "Extracting AppImage"

    # Create temporary directory for extraction
    local temp_dir=$(mktemp -d)
    log "INFO" "Created temporary directory: $temp_dir"
    cd "$temp_dir" || {
        log "ERROR" "${RED}Failed to create temporary directory${RC}"
        return 1
    }

    # Extract the AppImage
    log_step "Running AppImage extraction"
    if ! "$appimage_path" --appimage-extract; then
        log "ERROR" "${RED}Failed to extract AppImage${RC}"
        cd - >/dev/null
        rm -rf "$temp_dir"
        return 1
    fi
    log_success "AppImage extracted successfully"
    log_file_info "$temp_dir/squashfs-root" "Extracted contents"

    # Move to /opt
    log_step "Moving extracted contents to /opt"
    ${SUDO_CMD} mv squashfs-root "/opt/$desktop_name" || {
        log "ERROR" "${RED}Failed to move extracted contents to /opt${RC}"
        cd - >/dev/null
        rm -rf "$temp_dir"
        return 1
    }
    log_success "Moved contents to /opt/$desktop_name"
    log_file_info "/opt/$desktop_name" "Installation directory"

    cd - >/dev/null
    rm -rf "$temp_dir"
    log "INFO" "Cleaned up temporary directory"

    # Find icon in extracted directory
    log_step "Locating application icon"
    if [ -z "$icon_path" ]; then
        # Look for .png or .svg files in the extracted directory
        icon_path=$(find "/opt/$desktop_name" -type f \( -name "*.png" -o -name "*.svg" \) -print -quit)
        if [ -n "$icon_path" ]; then
            log "INFO" "Found icon automatically: $icon_path"
        fi
    fi

    # If no icon found, ask user
    if [ -z "$icon_path" ]; then
        while true; do
            read -p "Enter the path to the icon file: " icon_path
            if [ -f "$icon_path" ]; then
                break
            else
                log "WARNING" "Icon file not found: $icon_path"
                echo -e "${YELLOW}Icon file not found. Please provide a valid path${RC}"
            fi
        done
    fi
    log_file_info "$icon_path" "Icon file"

    # Get category
    log_step "Setting application category"
    read -p "Enter the application category (e.g., Utility, Development, Office): " category
    category=${category:-Utility}
    log "INFO" "Using category: $category"

    # Create desktop file
    log_step "Creating desktop entry file"
    local desktop_file="/tmp/${desktop_name}.desktop"

    cat > "$desktop_file" << EOF
[Desktop Entry]
Name=$desktop_name
Exec=/opt/$desktop_name/AppRun
Icon=$icon_path
Type=Application
Categories=$category;
Terminal=false
EOF

    log_file_info "$desktop_file" "Desktop entry file"

    # Show desktop file contents and confirm
    echo -e "\n${BLUE}Review the desktop file contents:${RC}"
    echo -e "${MAGENTA}"
    cat "$desktop_file"
    echo -e "${RC}"

    read -p "Does this look correct? (y/n): " confirm
    if [[ $confirm != [yY]* ]]; then
        rm "$desktop_file"
        log "INFO" "Desktop file creation cancelled by user"
        return 1
    fi

    # Install desktop file
    log_step "Installing desktop entry file"
    ${SUDO_CMD} desktop-file-install "$desktop_file" || {
        log "ERROR" "${RED}Failed to install desktop file${RC}"
        rm "$desktop_file"
        return 1
    }
    log_success "Desktop file installed successfully"
    log_file_info "/usr/share/applications/${desktop_name}.desktop" "Installed desktop entry"

    # Clean up
    rm "$desktop_file"
    log "INFO" "Cleaned up temporary desktop file"

    # Update desktop database
    log_step "Updating desktop database"
    ${SUDO_CMD} update-desktop-database
    log_success "Desktop database updated"

    # Final success message with installation details
    echo -e "\n${GREEN}Installation Summary:${RC}"
    echo -e "${BLUE}Application Name:${RC} $desktop_name"
    echo -e "${BLUE}Installed Location:${RC} /opt/$desktop_name"
    echo -e "${BLUE}Desktop Entry:${RC} /usr/share/applications/${desktop_name}.desktop"
    echo -e "${BLUE}Icon Location:${RC} $icon_path"
    echo -e "${BLUE}Log File:${RC} $LOG_FILE"

    log_success "Installation completed successfully"
    return 0
}

###################
# Main Script
###################

main() {
    init_logging

    echo -e "${BLUE}AppImage Installer${RC}"
    echo -e "${YELLOW}This script will help you install an AppImage application${RC}"
    log "INFO" "Starting AppImage installation process"

    install_appimage

    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "\n${GREEN}Installation completed successfully!${RC}"
        log_success "Script completed successfully"
    else
        echo -e "\n${RED}Installation failed. Check the log at $LOG_FILE${RC}"
        log "ERROR" "Script failed with exit code $exit_code"
    fi

    exit $exit_code
}

# Trap errors
trap 'log "ERROR" "Error occurred at line $LINENO: $BASH_COMMAND"' ERR

# Run main function
main

# TODO: provide list of icon files to choose from

# TODO: add batch functionality or option at end to run again for anther appimage

# TODO: GUI?

# TODO: browse files?
