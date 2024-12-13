#!/bin/bash

###################
# Logging & Debugging
###################

LOG_FILE="~/Desktop/script.log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Initialize log
log "starting script... \n"

# Debugging: Uncomment the following line if you want to log all terminal output (bash -x is preferred)
# exec > >(tee -a "$LOG_FILE")

# Trap error and write to log file
trap 'log "\n$(date) - Error occurred in ${BASH_SOURCE[0]} at line ${LINENO}: $? - $BASH_COMMAND\n" >> "$LOG_FILE"' ERR

# Debugging: Test the error trap by using a failing command
log "Testing the error trap..."
false


###################
# Configuration
###################

#TODO: re-write for multiple package managers

#TODO: detect desktop environment instead of declaring it
# Set the desktop environment: "gnome" or "kde"
# DESKTOP_ENV="gnome"

# Server details for downloading files
SERVER_ADDRESS="user@192.168.1.100"
SERVER_PATH="/path/to/files/on/server"

# Items to download from the server
DOWNLOAD_ITEMS=(
    "elegoo_kit"
    "code"
    "desktop"
    "3d_models"
    "Ai_models"
    "jupyter_notebooks"
    "books"
    "downloaded_websites"
)

# Packages to install
PACKAGES=(
    "build-essential"
    "arduino"
    "freecad"
    "darktable"
    "rsync"
    "code"
    "opera-stable"
    "virt-manager"
    "git"
    "htop"
    "cantor" 
    "labplot"
    "tree"
)

# TODO: do i want to change this to be a separate environment for small projects? if so i may need to change my .desktop files and make sure jupyter runs in the new env
# Pip packages to install
PIP_PACKAGES=(
    "selenium"
    "webdriver-manager"
    "beautifulsoup4"
    "PySimpleGUI"
)


# Snap packages to install
SNAP_PACKAGES=(
    "jupyterlab-desktop"
    "vlc"
    "spotify"
)

# Flatpak packages to install
FLATPAK_PACKAGES=(
    "com.slack.Slack"
    "org.telegram.desktop"
)

# Anaconda version to install
ANACONDA_VERSION="2023.09-0"

# Bookmarks to add
BOOKMARKS=(
    "$HOME/scripts"
    "$HOME/jupyter_notebooks"
    "$HOME/3d_models"
    "$HOME/Ai_models"
)

# Favorite apps for dock
GNOME_FAVORITE_APPS="[
    'org.gnome.Nautilus.desktop', 
    'mailspring.desktop', 
    'google-chrome.desktop', 
    'opera.desktop', 
    'org.gnome.Terminal.desktop', 
    'jupyter-lab.desktop', 
    'code.desktop', 
    'arduino.desktop', 
    'botango.desktop', 
    'org.gnome.gedit.desktop', 
    'freecad.desktop', 
    'cura.desktop', 
    'darktable.desktop'
]"

KDE_FAVORITE_APPS="
    org.kde.dolphin.desktop;
    mailspring.desktop;
    google-chrome.desktop;
    opera.desktop;
    org.kde.konsole.desktop;
    jupyter-lab.desktop;
    code.desktop;
    arduino.desktop;
    botango.desktop;
    org.kde.kate.desktop;
    freecad.desktop;
    cura.desktop;
    darktable.desktop
"

# AppImage configurations
declare -A APPIMAGE_CONFIGS
APPIMAGE_CONFIGS=(
    ["cura"]="https://github.com/Ultimaker/Cura/releases/download/5.7.2-RC2/UltiMaker-Cura-5.7.2-linux-X64.AppImage|Ultimaker Cura|cura-icon.png|Graphics"
    ["krita"]="https://download.kde.org/stable/krita/5.1.5/krita-5.1.5-x86_64.appimage|Krita|krita.png|Graphics"
)

#TODO: vscode extensions and IDs

# Conda environment names and their repositories
declare -A CONDA_ENVS
CONDA_ENVS=(
    ["stable_diffusion"]="https://github.com/Stability-AI/stablediffusion.git"
    ["code_llama"]="https://github.com/meta-llama/codellama.git"
    ["mistral_RAG"]="https://github.com/mistralai/mistral-inference.git"
)

# URLs for .deb files
declare -A DEB_URLS
DEB_URLS=(
    ["google-chrome"]="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    ["mailspring"]="https://updates.getmailspring.com/download?platform=linuxDeb"
    ["marktext"]="https://github.com/marktext/marktext/releases/latest/download/marktext-amd64.deb"
)

###################
# Script Functions
###################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

handle_error() {
    local error_message="$1"
    local is_critical="${2:-false}"
    
    log "Error: $error_message"
    
    if [ "$is_critical" = true ]; then
        log "Critical error. Exiting script."
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_anaconda() {
    if command_exists conda; then
        log "Anaconda is already installed."
    else
        log "Installing Anaconda..."
        wget "https://repo.anaconda.com/archive/Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh" -O anaconda.sh || handle_error "Failed to download Anaconda" false
        bash anaconda.sh -b -p "$HOME/anaconda3" || handle_error "Failed to install Anaconda" true
        rm anaconda.sh
        "$HOME/anaconda3/bin/conda" init || handle_error "Failed to initialize Conda" false
    fi
}

# TODO: pull from github as_well/instead?

download_items() {
    log "Downloading items from server..."
    for item in "${DOWNLOAD_ITEMS[@]}"; do
        log "Downloading $item..."
        scp -r "$SERVER_ADDRESS:$SERVER_PATH/$item" "$HOME/" || handle_error "Failed to download $item" false
    done
    log "All items downloaded successfully."
}

install_packages() {
    log "Installing packages..."
    sudo apt-get update || handle_error "Failed to update package lists" false
    for package in "${PACKAGES[@]}"; do
        log "Installing $package..."
        sudo apt-get install -y "$package" || handle_error "Failed to install $package" false
    done

    # desktop-specific customization
#     if [ "$DESKTOP_ENV" = "gnome" ]; then
#         sudo apt-get install -y gnome-tweak-tool chrome-gnome-shell || handle_error "Failed to install GNOME-specific packages" false
#     fi
}



#TODO: install docker and configure
# install_docker() {

# }

install_pip_on_base_env() {
    log "Installing pip packages in base environment..."
    for pip_package in "${PIP_PACKAGES[@]}"; do
        log "Installing $pip_package..."
        pip install -y "$pip_package" || handle_error "Failed to install $pip_package" false
    done

    log "pip package installation complete."
}

install_third_party_apps() {
    log "Installing third-party apps..."
    
    for app_name in "${!DEB_URLS[@]}"; do
        local deb_url="${DEB_URLS[$app_name]}"
        local deb_file="${app_name}.deb"
        
        log "Downloading and installing $app_name..."
        wget "$deb_url" -O "$deb_file" || handle_error "Failed to download $app_name" false
        sudo dpkg -i "$deb_file" || handle_error "Failed to install $app_name" false
        sudo apt-get install -f -y || handle_error "Failed to resolve $app_name dependencies" false
        rm "$deb_file"
    done

    log "Third-party apps installation complete."
}

install_snap_packages() {
    log "Checking for Snap package manager..."
    if ! command_exists snap; then
        log "Snap package manager not found. Installing Snap..."
        sudo apt-get install -y snapd || handle_error "Failed to install Snap package manager" false
    fi

    log "Installing Snap packages..."
    for snap_package in "${SNAP_PACKAGES[@]}"; do
        log "Installing $snap_package..."
        sudo snap install "$snap_package" || handle_error "Failed to install Snap package $snap_package" false
    done
    log "Snap packages installation complete."
}

install_flatpak_packages() {
    log "Checking for Flatpak package manager..."
    if ! command_exists flatpak; then
        log "Flatpak package manager not found. Installing Flatpak..."
        sudo apt-get install -y flatpak || handle_error "Failed to install Flatpak package manager" false
    fi

    log "Installing Flatpak packages..."
    for flatpak_package in "${FLATPAK_PACKAGES[@]}"; do
        log "Installing $flatpak_package..."
        flatpak install flathub "$flatpak_package" -y || handle_error "Failed to install Flatpak package $flatpak_package" false
    done
    log "Flatpak packages installation complete."
}

install_appimage() {
    local app_key="$1"
    local app_config="${APPIMAGE_CONFIGS[$app_key]}"
    
    if [ -z "$app_config" ]; then
        handle_error "No configuration found for $app_key" false
        return
    fi
    
    IFS='|' read -r app_url app_name icon_name category <<< "$app_config"
    
    log "Installing $app_name..."
    local appimage_file="$HOME/${app_key}.AppImage"
    
    # Download AppImage
    wget "$app_url" -O "$appimage_file" || handle_error "Failed to download $app_name" false
    chmod +x "$appimage_file"
    
    # Extract AppImage
    log "Extracting $app_name AppImage..."
    "$appimage_file" --appimage-extract || handle_error "Failed to extract $app_name AppImage" false
    
    # Move extracted contents to /opt
    sudo mv squashfs-root "/opt/$app_key" || handle_error "Failed to move $app_name to /opt" false
    
    # Create .desktop file
    log "Creating $app_name desktop entry..."
    cat << EOF > "$HOME/${app_key}.desktop"
[Desktop Entry]
Name=$app_name
Exec=/opt/$app_key/AppRun
Icon=/opt/$app_key/$icon_name
Type=Application
Categories=$category;
EOF

    sudo mv "$HOME/${app_key}.desktop" /usr/share/applications/ || handle_error "Failed to move $app_key.desktop to /usr/share/applications" false
    log "$app_name installation complete."
}

#TODO: install vscode extensions

#TODO: sign in to google? (promt for username / password)

setup_arduino_permissions() {
    log "Setting up Arduino permissions..."
    sudo usermod -a -G dialout "$USER" || handle_error "Failed to add user to dialout group" false
    sudo chmod a+rw /dev/ttyACM0 || handle_error "Failed to set permissions for /dev/ttyACM0" false
}

setup_conda_environments() {
    conda update -n base -c defaults conda
    for env_name in "${!CONDA_ENVS[@]}"; do
        local git_repo="${CONDA_ENVS[$env_name]}"
        log "Setting up Conda environment: $env_name"
        conda create --name "$env_name" python=3.8 -y || handle_error "Failed to create Conda environment $env_name" false
        source "$HOME/anaconda3/etc/profile.d/conda.sh"
        conda activate "$env_name" || handle_error "Failed to activate Conda environment $env_name" false
        conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia -y || handle_error "Failed to install PyTorch in Conda environment $env_name" false
        pip install diffusers transformers accelerate || handle_error "Failed to install Python packages in Conda environment $env_name" false
        conda install -c conda-forge jupyter ipykernel -y || handle_error "Failed to install Jupyter in Conda environment $env_name" false
        python -m ipykernel install --user --name="$env_name" --display-name "Python ($env_name)" || handle_error "Failed to install IPython kernel for $env_name" false

        # Clone the GitHub repository
        if [ -n "$git_repo" ]; then
            git clone "$git_repo" || handle_error "Failed to clone repository $git_repo" false
            cd "$(basename "$git_repo" .git)" || handle_error "Failed to change directory to repository $(basename "$git_repo" .git)" false
            pip install -e . || handle_error "Failed to install repository $(basename "$git_repo" .git)" false
        fi
    done
}

#TODO: configure browsers
# configure_browser_settings() {
    #google sign in (promt for username and password)
    #open previous tabs after closed
    #sidebar / top bar
# }

setup_dock_desktop() {
    if [ "$DESKTOP_ENV" = "gnome" ]; then
        gsettings set org.gnome.shell favorite-apps "$GNOME_FAVORITE_APPS" || handle_error "Failed to set GNOME favorite apps" false
    elif [ "$DESKTOP_ENV" = "kde" ]; then
        #TODO: if KDE, kwriteconfig5 configuration statements
        handle_error "KDE favorite apps setup is not implemented" false
    fi
}

add_bookmarks() {
    if [ "$DESKTOP_ENV" = "gnome" ]; then
        for bookmark in "${BOOKMARKS[@]}"; do
            echo "file://$bookmark" >> "$HOME/.config/gtk-3.0/bookmarks"
        done
    elif [ "$DESKTOP_ENV" = "kde" ]; then
        for bookmark in "${BOOKMARKS[@]}"; do
            echo "file://$bookmark" >> "$HOME/.local/share/user-places.xbel"
        done
    fi
}

open_in_text_editor() {
    if [ "$DESKTOP_ENV" = "gnome" ]; then
        xdg-open "$1" || gedit "$1" || nano "$1" || log "Failed to open $1 in text editor"
    elif [ "$DESKTOP_ENV" = "kde" ]; then
        kate "$1" || kwrite "$1" || nano "$1" || log "Failed to open $1 in text editor"
    else
        xdg-open "$1" || nano "$1" || log "Failed to open $1 in text editor"
    fi
}

###################
# Main Execution
###################

log "Starting setup for $DESKTOP_ENV environment..."

#install anaconda then restart script from beginning (allows for the conda and pip commands to be used in the script)
echo "Checking for Conda"
if command_exists conda; then
    log "Anaconda is already installed."
else
    echo "installing Anaconda"
    install_anaconda
    exec bash "$(dirname "$0")"
fi

# Check if server is reachable for download_items
echo "Checking for server"
ping -c 1 -W 1 "$SERVER_ADDRESS" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    log "Server is reachable. Downloading items..."
    download_items
else
    log "Server is not reachable. Skipping download_items..."
    echo "Server is not reachable. Skipping download_items..."
fi

install_packages
setup_conda_environments
install_third_party_apps
install_snap_packages
install_flatpak_packages

# Install AppImages
for app_key in "${!APPIMAGE_CONFIGS[@]}"; do
    install_appimage "$app_key"
done

setup_arduino_permissions
setup_dock_desktop
add_bookmarks

# Ask user if they want to verify the installation
read -p "Do you want to open the installed .desktop files, /opt directory, and log file for verification? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Opening created .desktop files, /opt directory, and log file for verification..."

    # Open each created .desktop file
    for app_key in "${!APPIMAGE_CONFIGS[@]}"; do
        desktop_file="/usr/share/applications/${app_key}.desktop"
        if [ -f "$desktop_file" ];then
            open_in_text_editor "$desktop_file"
        else
            log "Warning: .desktop file for $app_key not found at $desktop_file"
        fi
    done

    # Open /opt directory in file manager
    if [ "$DESKTOP_ENV" = "gnome" ]; then
        nautilus "/opt" || log "Failed to open /opt in file manager"
    elif [ "$DESKTOP_ENV" = "kde" ]; then
        dolphin "/opt" || log "Failed to open /opt in file manager"
    else
        xdg-open "/opt" || log "Failed to open /opt in file manager"
    fi

    # Open log file
    open_in_text_editor "$LOG_FILE"

    log "Verification files and directories have been opened. Please review them."
else
    log "Skipping verification step."
fi

log "Setup complete! If you didn't verify the installation now, you can find the log file at $LOG_FILE"


# TODO: failed to set permissions for arduino: different location for each distro? need arduino plugged in?
# TODO: mistral inference folder in downloads?
<< 'COMMENT_BLOCK'
Error: Failed to install freecad
Error: Failed to install code
Error: Failed to install opera-stable
Error: Failed to clone repository https://github.com/mistralai/mistral-inference.git
Error: Failed to install repository mistral-inference
Error: Failed to clone repository https://github.com/Stability-AI/stablediffusion.git
Error: Failed to install repository stablediffusion
Error: Failed to clone repository https://github.com/meta-llama/codellama.git
Error: Failed to install repository codellama
Error: Failed to download google-chrome
Error: Failed to install google-chrome
Error: Failed to download marktext
Error: Failed to download mailspring
Error: Failed to install Snap package jupyterlab-desktop
Error: Failed to install Flatpak package com.slack.Slack
Error: Failed to install Flatpak package org.telegram.desktop
Error: Failed to extract Krita AppImage
Error: Failed to move Krita to /opt
Error: Failed to extract Ultimaker Cura AppImage
Error: Failed to move Ultimaker Cura to /opt
Error: Failed to set permissions for /dev/ttyACM0
COMMENT_BLOCK