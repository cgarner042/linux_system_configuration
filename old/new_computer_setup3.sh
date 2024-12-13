#!/bin/bash

###################
# Configuration
###################

# Set the desktop environment: "gnome" or "kde"
DESKTOP_ENV="gnome"

# Server details for downloading files
SERVER_ADDRESS="user@192.168.1.100"
SERVER_PATH="/path/to/files/on/server"

# Items to download from the server
DOWNLOAD_ITEMS=(
    "elegoo_kit"
    "scripts"
    "desktop_files"
    "3d_models"
    "Ai_models"
    "jupyter_notebooks"
    "books"
    "downloaded_websites"
)

# Packages to install
PACKAGES=(
    "build-essential"
    "libgl1-mesa-glx"
    "libegl1-mesa"
    "libxrandr2"
    "libxss1"
    "libxcursor1"
    "libxcomposite1"
    "libasound2"
    "libxi6"
    "libxtst6"
    "arduino"
    "freecad"
    "darktable"
    "rsync"
    "code"
    "opera-stable"
    "virt-manager"
    "git"
    "htop"
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
GNOME_FAVORITE_APPS="['org.gnome.Nautilus.desktop', 'mailspring.desktop', 'google-chrome.desktop', 'opera.desktop', 'org.gnome.Terminal.desktop', 'jupyter-lab.desktop', 'code.desktop', 'arduino.desktop', 'botango.desktop', 'org.gnome.gedit.desktop', 'freecad.desktop', 'cura.desktop', 'darktable.desktop']"
KDE_FAVORITE_APPS="org.kde.dolphin.desktop;mailspring.desktop;google-chrome.desktop;opera.desktop;org.kde.konsole.desktop;jupyter-lab.desktop;code.desktop;arduino.desktop;botango.desktop;org.kde.kate.desktop;freecad.desktop;cura.desktop;darktable.desktop"

# AppImage configurations
declare -A APPIMAGE_CONFIGS
APPIMAGE_CONFIGS=(
    ["cura"]="https://github.com/Ultimaker/Cura/releases/download/5.7.2-RC2/UltiMaker-Cura-5.7.2-linux-X64.AppImage|Ultimaker Cura|cura-icon.png|Graphics"
    ["krita"]="https://download.kde.org/stable/krita/5.1.5/krita-5.1.5-x86_64.appimage|Krita|krita.png|Graphics"
    
    # Add more AppImages here as needed
)
# Conda environment names
ENV_NAMES=(
    "stable_diffusion"
    "code_llama"
    "mistral_RAG"
)

# Git source repositories
GIT_REPOS=(
    "https://github.com/Stability-AI/stablediffusion.git"
    "https://github.com/meta-llama/codellama.git"
    "https://github.com/mistralai/mistral-inference.git"
)

# Log file
LOG_FILE="$HOME/setup_log.txt"

###################
# Script Functions
###################

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    local error_message="$1"
    local is_critical="${2:-false}"
    
    log "Error: $error_message"
    
    if [ "$is_critical" = true ]; then
        log "Critical error. Exiting script."
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to download files/folders from a local server
download_items() {
    log "Downloading items from server..."
    for item in "${DOWNLOAD_ITEMS[@]}"; do
        log "Downloading $item..."
        scp -r "$SERVER_ADDRESS:$SERVER_PATH/$item" "$HOME/" || handle_error "Failed to download $item" true
    done
    log "All items downloaded successfully."
}

# Function to install packages
install_packages() {
    log "Installing packages..."
    sudo apt update || handle_error "Failed to update package lists" true
    for package in "${PACKAGES[@]}"; do
        log "Installing $package..."
        sudo apt install -y "$package" || handle_error "Failed to install $package" true
    done

    # Install desktop-specific packages
    if [ "$DESKTOP_ENV" = "gnome" ]; then
        sudo apt install -y gnome-tweak-tool chrome-gnome-shell || handle_error "Failed to install GNOME-specific packages" true
    fi

    # Install Anaconda
    if command_exists conda; then
        log "Anaconda is already installed."
    else
        log "Installing Anaconda..."
        wget "https://repo.anaconda.com/archive/Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh" -O anaconda.sh || handle_error "Failed to download Anaconda" true
        # SILENT MODE (-b)—Batch mode with no PATH modifications to ~/.bashrc. Assumes that you agree to the license agreement. Does not edit the .bashrc or .bash_profile files.(-p)—Installation prefix/path.
        bash anaconda.sh -b -p "$HOME/anaconda3" || handle_error "Failed to install Anaconda" true
        rm anaconda.sh
        "$HOME/anaconda3/bin/conda" init || handle_error "Failed to initialize Conda" true
    fi

    # Install JupyterLab-Desktop (snap for ease of launcher in dock / panel. install with [conda install -c conda-forge jupyterlab] and setup .desktop file?)
    sudo snap install jupyterlab-desktop


    # TODO: Implement setup_conda_environments function
    # Conda environment creation with general tools for AI including CUDA
    setup_conda_environments() {
        for i in "${!ENV_NAMES[@]}"; do
            ENV_NAME=${ENV_NAMES[$i]}
            GIT_REPO=${GIT_REPOS[$i]}
            conda create --name $ENV_NAME python=3.8
            conda activate $ENV_NAME
            conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia -y
            pip install diffusers transformers accelerate
            conda install -c conda-forge jupyter ipykernel
            python -m ipykernel install --user --name=$ENV_NAME --display-name "Python ($ENV_NAME)"

            # Clone the GitHub repository
            if [ -n "$GIT_REPO" ]; then
                git clone $GIT_REPO
                cd $(basename $GIT_REPO .git)
                pip install -e .
            fi
        done
    }

    # Install Google-Chrome
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo dpkg -i google-chrome-stable_current_amd64.deb || handle_error "Failed to install Chrome" true
    sudo apt install -f -y || handle_error "Failed to resolve Chrome dependencies" true
    rm google-chrome-stable_current_amd64.deb    

    # Install Mailspring
    log "Installing Mailspring..."
    wget https://updates.getmailspring.com/download?platform=linuxDeb -O mailspring.deb || handle_error "Failed to download Mailspring" true
    sudo dpkg -i mailspring.deb || handle_error "Failed to install Mailspring" true
    sudo apt install -f -y || handle_error "Failed to resolve Mailspring dependencies" true
    rm mailspring.deb

    # Install MarkText
    log "Installing MarkText..."
    wget https://github.com/marktext/marktext/releases/latest/download/marktext-amd64.deb -O marktext.deb || handle_error "Failed to download MarkText" true
    sudo dpkg -i marktext.deb || handle_error "Failed to install MarkText" true
    sudo apt install -f -y || handle_error "Failed to resolve MarkText dependencies" true
    rm marktext.deb

    # Install Cantor and LabPlot
    log "Installing Cantor and LabPlot..."
    sudo apt install -y cantor labplot || handle_error "Failed to install Cantor and LabPlot" false
}

# Function to install AppImage
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
    wget "$app_url" -O "$appimage_file" || handle_error "Failed to download $app_name" true
    chmod +x "$appimage_file"
    
    # Extract AppImage
    log "Extracting $app_name AppImage..."
    "$appimage_file" --appimage-extract || handle_error "Failed to extract $app_name AppImage" true
    
    # Move extracted contents to /opt
    sudo mv squashfs-root "/opt/$app_key" || handle_error "Failed to move $app_name to /opt" true
    
    # Create .desktop file
    log "Creating $app_name desktop entry..."
    cat << EOF > "$HOME/${app_key}.desktop"
[Desktop Entry]
Name=$app_name
Type=Application
Categories=$category;
Exec=/opt/$app_key/AppRun %F
Icon=/opt/$app_key/$icon_name
Terminal=false
StartupNotify=true
EOF
    
    # Install .desktop file
    sudo desktop-file-install "$HOME/${app_key}.desktop" || handle_error "Failed to install $app_name desktop file" false
    
    # Clean up
    rm "$appimage_file"
    rm "$HOME/${app_key}.desktop"
    
    log "$app_name installation complete."
}

# Function to set up Arduino permissions
setup_arduino_permissions() {
    sudo usermod -a -G dialout "$USER" || handle_error "Failed to add user to dialout group" true
    sudo chmod a+rw /dev/ttyACM0 || handle_error "Failed to set permissions for /dev/ttyACM0" false
}

# Function to set up dock and desktop
setup_dock_desktop() {
    if [ "$DESKTOP_ENV" = "gnome" ]; then
        gsettings set org.gnome.shell favorite-apps "$GNOME_FAVORITE_APPS" || handle_error "Failed to set GNOME favorite apps" false
        # Additional GNOME-specific settings can be added here
    elif [ "$DESKTOP_ENV" = "kde" ]; then
        # Note: You may need to use the full path to the application executable if the application name is not recognized.
        kfp --pin "$KDE_FAVORITE_APPS"
        log ""
    fi
}

# Function to add bookmarks
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

# Function to open file in default text editor
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
download_items
install_packages

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
if [[ $REPLY =~ ^[Yy]$ ]]
then
    log "Opening created .desktop files, /opt directory, and log file for verification..."

    # Open each created .desktop file
    for app_key in "${!APPIMAGE_CONFIGS[@]}"; do
        desktop_file="/usr/share/applications/${app_key}.desktop"
        if [ -f "$desktop_file" ]; then
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