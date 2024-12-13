#!/usr/bin/env bash

###################
# Configuration
###################

# Set the desktop environment: "gnome" or "kde"
desktop_env="gnome"

# Server details for downloading files
server_address="user@192.168.1.100"
server_path="/path/to/files/on/server"

# Items to download from the server
download_items=(
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
packages=(
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
)

# Anaconda version to install
anaconda_version="2023.09-0"

# Bookmarks to add
bookmarks=(
    "$HOME/scripts"
    "$HOME/jupyter_notebooks"
    "$HOME/3d_models"
    "$HOME/Ai_models"
)

# Favorite apps for dock
gnome_favorite_apps="['firefox.desktop', 'org.gnome.Nautilus.desktop', 'code.desktop', 'cura.desktop']"
kde_favorite_apps="firefox.desktop,org.kde.dolphin.desktop,code.desktop,cura.desktop"

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

# Function to check for sudo privileges
check_sudo() {
    if ! sudo -v; then
        log "Error: This script requires sudo privileges."
        exit 1
    fi
}

# Function to detect package manager
detect_package_manager() {
    if command_exists apt; then
        pkg_manager="apt"
    elif command_exists dnf; then
        pkg_manager="dnf"
    elif command_exists pacman; then
        pkg_manager="pacman"
    else
        log "Error: Unsupported package manager"
        exit 1
    fi
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
    case $pkg_manager in
        apt)
            sudo apt update || { log "Error: Failed to update package lists"; exit 1; }
            for package in "${packages[@]}"; do
                log "Installing $package..."
                sudo apt install -y "$package" || { log "Error: Failed to install $package"; exit 1; }
            done
            ;;
        dnf)
            sudo dnf update || { log "Error: Failed to update package lists"; exit 1; }
            sudo dnf install -y "${packages[@]}" || { log "Error: Failed to install packages"; exit 1; }
            ;;
        pacman)
            sudo pacman -Syu || { log "Error: Failed to update package lists"; exit 1; }
            sudo pacman -S --noconfirm "${packages[@]}" || { log "Error: Failed to install packages"; exit 1; }
            ;;
    esac

    # Install desktop-specific packages
    if [ "$desktop_env" = "gnome" ]; then
        sudo "$pkg_manager" install -y gnome-tweak-tool chrome-gnome-shell || { log "Error: Failed to install GNOME packages"; exit 1; }
    elif [ "$desktop_env" = "kde" ]; then
        sudo "$pkg_manager" install -y kde-plasma-desktop || { log "Error: Failed to install KDE packages"; exit 1; }
    fi

    # Install common additional software
    sudo "$pkg_manager" install -y chromium-browser opera-stable code || { log "Error: Failed to install additional software"; exit 1; }
    
    log "All packages installed successfully."
}

# Function to set up Conda environments
setup_conda_environments() {
    log "Setting up Conda environments..."
    # Download and install Anaconda
    wget "https://repo.anaconda.com/archive/Anaconda3-$anaconda_version-Linux-x86_64.sh" -O anaconda.sh || { log "Error: Failed to download Anaconda"; exit 1; }
    bash anaconda.sh -b -p "$HOME/anaconda3" || { log "Error: Failed to install Anaconda"; exit 1; }
    rm anaconda.sh

    # Add Anaconda to PATH
    #echo 'export PATH="$HOME/anaconda3/bin:$PATH"' >> "$HOME/.bashrc"
    #source "$HOME/.bashrc"
    conda init

    # Create environments
    conda create -y -n py39 python=3.9 || { log "Error: Failed to create Python 3.9 environment"; exit 1; }
    conda create -y -n py310 python=3.10 || { log "Error: Failed to create Python 3.10 environment"; exit 1; }

    log "Conda environments set up successfully."
}

# Function to install additional software
install_additional_software() {
    log "Installing additional software..."
    # Install VS Code
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f packages.microsoft.gpg
    sudo apt update
    sudo apt install -y code || { log "Error: Failed to install VS Code"; exit 1; }

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

    log "Additional software installed successfully."
}

# Function to set up Arduino permissions
setup_arduino_permissions() {
    log "Setting up Arduino permissions..."
    sudo usermod -a -G dialout "$USER" || { log "Error: Failed to add user to dialout group"; exit 1; }
    sudo chmod a+rw /dev/ttyACM0 || { log "Error: Failed to set permissions for /dev/ttyACM0"; exit 1; }
    log "Arduino permissions set up successfully."
}

# Function to set up dock and desktop
setup_dock_desktop() {
    log "Setting up dock and desktop..."
    if [ "$desktop_env" = "gnome" ]; then
        gsettings set org.gnome.shell favorite-apps "$gnome_favorite_apps" || { log "Error: Failed to set GNOME favorite apps"; exit 1; }
        # Additional GNOME-specific settings can be added here
    elif [ "$desktop_env" = "kde" ]; then
        # KDE uses a different method to set favorite apps
        kwriteconfig5 --file ~/.config/plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 1 --group Applets --group 2 --group Configuration --key launchers "$kde_favorite_apps" || { log "Error: Failed to set KDE favorite apps"; exit 1; }
        # Additional KDE-specific settings can be added here
    fi
    log "Dock and desktop set up successfully."
}

# Function to add bookmarks
add_bookmarks() {
    log "Adding bookmarks..."
    if [ "$desktop_env" = "gnome" ]; then
        for bookmark in "${bookmarks[@]}"; do
            echo "file://$bookmark" >> "$HOME/.config/gtk-3.0/bookmarks" || { log "Error: Failed to add GNOME bookmark: $bookmark"; exit 1; }
        done
    elif [ "$desktop_env" = "kde" ]; then
        for bookmark in "${bookmarks[@]}"; do
            echo "file://$bookmark" >> "$HOME/.local/share/user-places.xbel" || { log "Error: Failed to add KDE bookmark: $bookmark"; exit 1; }
        done
    fi
    log "Bookmarks added successfully."
}

###################
# Main Execution
###################

# Start logging
log "Starting setup for $desktop_env environment..."

# Check for sudo privileges
check_sudo

# Detect package manager
detect_package_manager

# Confirm with user
read -p "Do you want to proceed with the installation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Installation cancelled by user."
    exit 1
fi

# Show progress
total_steps=7
current_step=0

progress() {
    current_step=$((current_step + 1))
    log "Progress: $current_step / $total_steps"
}

# Execute setup steps
download_items
progress

install_packages
progress

setup_conda_environments
progress

install_additional_software
progress

setup_arduino_permissions
progress

setup_dock_desktop
progress

add_bookmarks
progress

log "Setup complete!"