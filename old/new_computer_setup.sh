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
    "chromium-browser"
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
# file_explorer, mailspring, chrome, opera, terminal, jupyter_lab, vs_code, arduino, botango, native_text_editor, freecad, cura, darktable
GNOME_FAVORITE_APPS="['firefox.desktop', 'org.gnome.Nautilus.desktop', 'code.desktop', 'cura.desktop']"
KDE_FAVORITE_APPS="chrome.desktop,org.kde.dolphin.desktop,code.desktop,cura.desktop"

# Log file
log_file="$HOME/setup_log.txt"

###################
# Script Functions
###################

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$log_file"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to download files/folders from a local server
download_items() {
    log "Downloading items from server..."
    for item in "${download_items[@]}"; do
        log "Downloading $item..."
        scp -r "$server_address:$server_path/$item" "$HOME/" || { log "Error: Failed to download $item"; exit 1; }
    done
    log "All items downloaded successfully."
}

# Function to install packages
install_packages() {
    log "Installing packages..."
    sudo apt update || { log "Error: Failed to update package lists"; exit 1; }
    for package in "${PACKAGES[@]}"; do
        echo "Installing $package..."
        sudo apt install -y "$package" || { log "Error: Failed to install $package"; exit 1; }
    done

    # Install desktop-specific packages
    if [ "$DESKTOP_ENV" = "gnome" ]; then
        sudo apt install -y gnome-tweak-tool chrome-gnome-shell
    fi

    # Install Anaconda
    if command_exists conda; then
        echo "Anaconda is already installed."
    else
        echo "Installing Anaconda..."
        ANACONDA_VERSION="2023.09-0"
        wget "https://repo.anaconda.com/archive/Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh" -O anaconda.sh
        bash anaconda.sh -b -p $HOME/anaconda3
        rm anaconda.sh
        conda init
    fi

    # Set up Conda environments using downloaded scripts
    setup_conda_environments

    # Install Mailspring
    wget https://updates.getmailspring.com/download?platform=linuxDeb -O mailspring.deb
    sudo dpkg -i mailspring.deb
    sudo apt install -f -y
    rm mailspring.deb

    # Install MarkText
    wget https://github.com/marktext/marktext/releases/latest/download/marktext-amd64.deb -O marktext.deb
    sudo dpkg -i marktext.deb
    sudo apt install -f -y
    rm marktext.deb

    # Install Ultimaker Cura
    # Download and make AppImage executable
    wget https://github.com/Ultimaker/Cura/releases/download/5.7.2-RC2/UltiMaker-Cura-5.7.2-linux-X64.AppImage
    chmod +x UltiMaker-Cura-5.7.2-linux-X64.AppImage

    # Create .desktop file
    echo "[Desktop Entry]
    Version=1.0
    Type=Application
    Name=Ultimaker Cura
    Exec=/path/to/UltiMaker-Cura-5.7.2-linux-X64.AppImage
    Icon=/path/to/cura-icon.png
    Terminal=false
    StartupWMClass=UltiMaker Cura" > cura.desktop

    # Create dock shortcut (KDE)
    if [ "$DESKTOP_ENV" = "kde" ]; then
        kde-desktop-file-install cura.desktop
        dcop kde-desktop --add-applications cura.desktop
    fi

    # Create dock shortcut (GNOME)
    if [ "$DESKTOP_ENV" = "gnome" ]; then
        gnome-desktop-item-install --add-to-panel cura.desktop
    fi || { log "Error: Failed to install Ultimaker Cura"; exit 1; }

    # Install Cantor and LabPlot (if available in repositories)
    sudo apt install -y cantor labplot
}

# Function to set up Arduino permissions
setup_arduino_permissions() {
    sudo usermod -a -G dialout $USER
    sudo chmod a+rw /dev/ttyACM0
}

# Function to set up dock and desktop
setup_dock_desktop() {
    if [ "$DESKTOP_ENV" = "gnome" ]; then
        gsettings set org.gnome.shell favorite-apps "$GNOME_FAVORITE_APPS"
        # Additional GNOME-specific settings can be added here
    elif [ "$DESKTOP_ENV" = "kde" ]; then
        # KDE uses a different method to set favorite apps
        kwriteconfig5 --file ~/.config/plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 1 --group Applets --group 2 --group Configuration --key launchers "$KDE_FAVORITE_APPS"
        # Additional KDE-specific settings can be added here
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

###################
# Main Execution
###################

echo "Starting setup for $DESKTOP_ENV environment..."
download_items
install_packages
install_additional_software
setup_arduino_permissions
setup_dock_desktop
add_bookmarks
echo "Setup complete!"


