#!/bin/bash

###################
# Logging & Debugging
###################

LOG_FILE="$HOME/Desktop/linux_set_up.log"

log() {
    local level="$1"
    local message="$2"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [$level] - $message" | tee -a "$LOG_FILE"
}



# Initialize log
log "INFO" "Starting script..."

# Trap error and write to log file
trap 'log "ERROR" "Error occurred in ${BASH_SOURCE[0]} at line ${LINENO}: $? - $BASH_COMMAND"' ERR

# Debugging: Test the error trap by using a failing command
log "INFO" "Testing the error trap..."
false

###################
# Configuration
###################

# Server details for downloading files
SERVER_ADDRESS="user@192.168.1.100"
SERVER_PATH="/media/garner/Dual_boot_share"

# Items to download from the server
DOWNLOAD_ITEMS=(
    
    "code"
    "3d_models"
    "ai_models"
    "Desktop"
    "Downloads"
    "Documents"
    "iso_files"
)

# Initialize variable for packages that failed to install
FAILED_PACKAGES=()
FAILED_SNAP_PACKAGES=()
FAILED_FLATPAK_PACKAGES=()

# Packages to install
PACKAGES=(
    "build-essential"
    "arduino"
    "darktable"
    "rsync"
    "virt-manager"
    "git"
    "htop"
    "cantor" 
    "labplot"
    "tree"
    "gnome-terminal"
    "gedit"
)

# Pip packages to install
PIP_PACKAGES=(
    "pyqt5"
    "pyqtwebengine"
    "selenium"
    "webdriver-manager"
    "beautifulsoup4"
    "chromedriver-autoinstaller"
    
)

# Conda packages to install
CONDA_PACKAGES=(
    # "-c conda-forge jupyterlab"
)

# Snap packages to install
SNAP_PACKAGES=(
    # "jupyterlab-desktop"
    "vlc"
    "spotify"
    "freecad"
    "opera"
    "mailspring"
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
    "$HOME/iso_files"
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

# URLs for .deb files
declare -A DEB_URLS
DEB_URLS=(
    ["google-chrome"]="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    ["marktext"]="https://github.com/marktext/marktext/releases/latest/download/marktext-amd64.deb"
    ["vs-code"]="https://go.microsoft.com/fwlink/?LinkID=760868"
    # ["jupyterlab-desktop"]="https://github.com/jupyterlab/jupyterlab-desktop/releases/latest/download/JupyterLab-Setup-Debian-x64.deb"
    ["docker-desktop"]="https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-linux-amd64&_gl=1*ue25ac*_gcl_au*MTkxNjE5MzMzMy4xNzE5ODM5Mjc5*_ga*MTIyNjMxMTQ2OC4xNzE5ODM5Mjc5*_ga_XJWPQMJYHQ*MTcyNTkwMDA5NS4zLjEuMTcyNTkwMTA4Mi42MC4wLjA."
)

###################
# Script Functions
###################

critical_error() {
    local message="$1"
    log "ERROR" "$message"
    log "ERROR" "Critical error. Exiting script."
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_anaconda() {
    log "INFO" "Starting install_anaconda function..."
    if command_exists conda; then
        log "INFO" "Anaconda is already installed. Updating..."
    else
        log "INFO" "Installing Anaconda..."
        wget "https://repo.anaconda.com/archive/Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh" -O anaconda.sh || critical_error "Failed to download Anaconda"
        bash anaconda.sh -b -p "$HOME/anaconda3" || critical_error "Failed to install Anaconda"
        rm anaconda.sh
        log "INFO" "Initializing Conda"
        "$HOME/anaconda3/bin/conda" init || log "ERROR" "Failed to initialize Conda"
    fi
    log "INFO" "Finished install_anaconda function."
}

check_conda() {
    echo "Checking for Conda"
    if command_exists conda; then
        log "Anaconda is already installed."
    else
        echo "installing Anaconda"
        install_anaconda
        # restart script to make conda and pip commands available
        exec bash "$(dirname "$0")"
    fi
}

download_items() {
    log "INFO" "Downloading items from server..."
    for item in "${DOWNLOAD_ITEMS[@]}"; do
        log "INFO" "Downloading $item..."
        scp -r "$SERVER_ADDRESS:$SERVER_PATH/$item" "$HOME/" || log "ERROR" "Failed to download $item"
    done
    log "INFO" "Finished download_items function."
}

contact_server() {
    ping -c 1 -W 1 "$SERVER_ADDRESS" >/dev/null 2>&1
    if [ $? -eq 0 ] || [ -e "$SERVER_PATH" ]; then
        log "Server is reachable. Downloading items..."
        download_items
    else
        log "Server is not reachable. Skipping download_items..."
        echo "Server is not reachable. Skipping download_items..."
    fi
}

install_packages() {
    log "INFO" "Installing packages..."
    sudo apt-get update || log "ERROR" "Failed to update package lists"
    for package in "${PACKAGES[@]}"; do
        log "INFO" "Installing $package..."
        if ! sudo apt-get install -y "$package"; then
            log "ERROR" "Failed to install $package"
            FAILED_PACKAGES+=("$package")
        fi
    done
    sudo apt-get upgrade
    log "INFO" "Finished install_packages function."
}

install_pip_on_base_env() {
    log "INFO" "Installing pip packages in base environment..."
    for pip_package in "${PIP_PACKAGES[@]}"; do
        log "INFO" "Installing $pip_package..."
        pip install "$pip_package" || log "ERROR" "Failed to install $pip_package"
    done
    log "INFO" "Finished install_pip_on_base_env function."
}

install_conda_packages() {
    log "INFO" "installing conda packages on base environment"
    for conda_package in "${CONDA_PACKAGES[@]}"; do
        log "INFO" "Installing $conda_package..."
        conda install "$conda_package" || log "ERROR" "Failed to install $conda_package"
    done
}

install_third_party_apps() {
    log "INFO" "Installing third-party apps..."
    for app_name in "${!DEB_URLS[@]}"; do
        local deb_url="${DEB_URLS[$app_name]}"
        local deb_file="${app_name}.deb"
        log "INFO" "Downloading and installing $app_name..."
        wget "$deb_url" -O "$deb_file" || log "ERROR" "Failed to download $app_name"
        sudo dpkg -i "$deb_file" || log "ERROR" "Failed to install $app_name"
        sudo apt-get install -f -y || log "ERROR" "Failed to resolve $app_name dependencies"
        rm "$deb_file"
    done
    log "INFO" "Finished install_third_party_apps function."
}

install_snap_packages() {
    log "INFO" "Checking for Snap package manager..."
    if ! command_exists snap; then
        log "WARN" "Snap package manager not found. Installing Snap..."
        sudo apt-get install -y snapd || log "ERROR" "Failed to install Snap package manager"
    fi
    log "INFO" "Installing Snap packages..."
    for snap_package in "${SNAP_PACKAGES[@]}"; do
        log "INFO" "Installing $snap_package..."
        if ! sudo snap install "$snap_package"; then
            log "ERROR" "Failed to install Snap package $snap_package"
            FAILED_SNAP_PACKAGES+=("$snap_package")
        fi
    done
    log "INFO" "Finished install_snap_packages function."
}

install_flatpak_packages() {
    log "INFO" "Checking for Flatpak package manager..."
    if ! command_exists flatpak; then
        log "WARN" "Flatpak package manager not found. Installing Flatpak..."
        sudo apt-get install -y flatpak || log "ERROR" "Failed to install Flatpak package manager"
    fi
    log "INFO" "Installing Flatpak packages..."
    for flatpak_package in "${FLATPAK_PACKAGES[@]}"; do
        log "INFO" "Installing $flatpak_package..."
        if ! flatpak install -y "$flatpak_package"; then
            log "ERROR" "Failed to install Flatpak package $flatpak_package"
            FAILED_FLATPAK_PACKAGES+=("$flatpak_package")
        fi
    done
    log "INFO" "Finished install_flatpak_packages function."
}

install_appimages() {
    log "INFO" "Installing AppImages..."
    APPIMAGES_DIR="$HOME/AppImages"
    mkdir -p "$APPIMAGES_DIR"
    for appimage in "${!APPIMAGE_CONFIGS[@]}"; do
        IFS='|' read -r url name icon category <<< "${APPIMAGE_CONFIGS[$appimage]}"
        appimage_file="$APPIMAGES_DIR/$appimage.AppImage"
        desktop_file="$HOME/Desktop/$appimage.desktop"
        icon_file="$HOME/.local/share/icons/$icon"
        log "INFO" "Downloading $name..."
        wget "$url" -O "$appimage_file" || log "ERROR" "Failed to download $name"
        chmod +x "$appimage_file"
        # Extract AppImage
        log "INFO" "Extracting $appimage AppImage..."
        "$appimage_file" --appimage-extract || log "ERROR" "Failed to extract $appimage AppImage"
        # Move extracted contents to /opt
        sudo mv squashfs-root "/opt/$appimage" || log "ERROR" "Failed to move $appimage to /opt"
        # Create .desktop file
        log "INFO" "Creating desktop entry for $name..."
        cat << EOF > "$desktop_file" || log "ERROR" "Failed to create .desktop file for $appimage"
[Desktop Entry]
Name=$name
Exec=/opt/$appimage/AppRun
Icon=/opt/$appimage/$icon
Type=Application
Categories=$category;
EOF
        sudo desktop-file-install "$desktop_file" || log "ERROR" "Failed to move $appimage.desktop to /usr/share/applications"
        log "INFO" "Downloading icon for $name..."
    done
    log "INFO" "Finished install_appimages function."
}

setup_gnome_favorites() {
    log "INFO" "Setting up GNOME favorite apps and folders..."
    gsettings set org.gnome.shell favorite-apps "$GNOME_FAVORITE_APPS" || log "ERROR" "Failed to set GNOME favorite apps"
    for bookmark in "${BOOKMARKS[@]}"; do
        echo "file://$bookmark" >> "$HOME/.config/gtk-3.0/bookmarks"
    done
    log "INFO" "Finished setup_gnome_favorites function."
}

setup_kde_favorites() {
    log "INFO" "Setting up KDE favorite apps and folders..."
    kwriteconfig5 --file ~/.config/plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 1 --group Applets --group 2 --group Configuration --group General --key favorites "$KDE_FAVORITE_APPS" || log "ERROR" "Failed to set KDE favorite apps"
    for bookmark in "${BOOKMARKS[@]}"; do
        echo "file://$bookmark" >> "$HOME/.local/share/user-places.xbel"
    done
    log "INFO" "Finished setup_kde_favorites function."
}

prompt_desktop_environment() {
    log "INFO" "Prompting user for desktop environment..."
    PS3='Please enter your choice: '
    options=("GNOME" "KDE")
    select opt in "${options[@]}"; do
        case $opt in
            "GNOME")
                log "INFO" "User selected GNOME."
                setup_gnome_favorites
                break
                ;;
            "KDE")
                log "INFO" "User selected KDE."
                setup_kde_favorites
                break
                ;;
            *) 
                log "WARN" "Invalid option $REPLY"
                ;;
        esac
    done
    log "INFO" "Finished prompt_desktop_environment function."
}

###################
# Execution
###################

main() {
    log "INFO" "Starting main function..."
    
    check_conda
    # contact_server
    install_packages
    # retry_failed_packages
    install_pip_on_base_env
    install_conda_packages
    conda update -n base -c defaults conda
    install_third_party_apps
    install_snap_packages
    # retry_failed_snap_packages
    install_flatpak_packages
    # retry_failed_flatpak_packages
    install_appimages
    # prompt_desktop_environment
    
    log "INFO" "Finished main function."
}

main "$@"
log "INFO" "Script finished successfully."



####################
# BUGS (possible solutions)
####################

# stop deleting these and move them to "FIXED" to add to git commits


# TODO: bookmarks:check if directory exists before adding to bokkmarks
# TODO: bookmarks: prompt user?
# TODO: download_items: promt for server location / skip download?
# TODO: call anaconda env setup scripts
# TODO: set up dev containers on VS-CODE
# TODO: add -y flags
# check is things are installed before installing
# TODO: set jupyter to use non-default browser (eliminates the need for jupyterlab-desktop)
#     1. jupyter notebook --browser=/path/to/browser %s OR jupyter lab --browser=/path/to/browser %s
#     2. jupyter notebook --generate-config OR jupyter lab --generate-config
#       - c.NotebookApp.browser = '/path/to/browser %s'

# Failed to restart script: .: .: Is a directory
    # run bootsrtap script first? (install anaconda, ansible, and maybe docker)

# Failed to install Snap package jupyterlab-desktop (--classic?)
    # install conda package opens in browser
    # use docker? deb?
    # deb installed but crashes

# Failed to install docker-desktop deb

# Failed to install Flatpak packages (add repo?) 
	# Note that the directories 

# '/var/lib/flatpak/exports/share'
# '/home/garner/.local/share/flatpak/exports/share'

# are not in the search path set by the XDG_DATA_DIRS environment variable, so
# applications installed by Flatpak may not appear on your desktop until the
# session is restarted.


# Krita failed to open

# no bookmarks created (kde) 
# favorites not added to task manager (kde) 

####################
# FIXED BUGS
####################

# Failed to install opera-stable (add repo) or (deb)
# Failed to install mailspring (shows in app drawer but crashes on startup)
# Failed to install code (snap --classic) or (deb) or (add repo)
# Failed to extract and relocate appimages (they are functional in appimage folder)
    # Failed to download icon for Krita (solved?)
    # Failed to download icon for Ultimaker Cura (solved?)
    # double install of appimages? /home/garner/squashfs-root
    # .desktop exec line
    # find appimage icon "*.png" (open file manager to view?)
