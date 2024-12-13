#!/bin/sh -x

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'

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

# Initialize variables
BACKUP_DRIVE_NAME="Dual_boot_share"
SRC_DIR="/"
DST_DIR=""
PACKAGER=""
SUDO_CMD=""
SUGROUP=""
FAILED_PACKAGES=()
FAILED_SNAP_PACKAGES=()
FAILED_FLATPAK_PACKAGES=()

DEPENDENCIES=(
    "bash"
    "bash-completion"
    "tar"
    "bat"
    "tree"
    "multitail"
    "fastfetch"
    "wget"
    "unzip"
    "fontconfig"
    "gnome-terminal" #dependency for git desktop
    "rsync"
    "virt-manager"
    "git"
    "htop"
    "build-essential"
    "incron"

)

# Packages to install
PACKAGES=(
    "arduino"
    "darktable"
    "cantor"
    "labplot"
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
    "--classic code"
)

# Flatpak packages to install
FLATPAK_PACKAGES=(
    "com.slack.Slack"
    "org.telegram.desktop"
    "io.gitlab.librewolf-community"
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
    log "INFO" "Installing Anaconda..."
    wget "https://repo.anaconda.com/archive/Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh" -O anaconda.sh || critical_error "Failed to download Anaconda"
    bash anaconda.sh -b -p "$HOME/anaconda3" || critical_error "Failed to install Anaconda"
    rm anaconda.sh
    log "INFO" "Initializing Conda"
    "$HOME/anaconda3/bin/conda" init || log "ERROR" "Failed to initialize Conda"
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

checkEnv() {
    ## Check for requirements.
    REQUIREMENTS='curl groups sudo'
    for req in $REQUIREMENTS; do
        if ! command_exists "$req"; then
            echo "${RED}To run me, you need: $REQUIREMENTS${RC}" | tee -a "$LOG_FILE"
            exit 1
        fi
    done

    ## Check Package Handler
    PACKAGEMANAGER='nala apt dnf yum pacman zypper emerge xbps-install nix-env'
    for pgm in $PACKAGEMANAGER; do
        if command_exists "$pgm"; then
            PACKAGER="$pgm"
            echo "Using $pgm" | tee -a "$LOG_FILE"
            break
        fi
    done

    if [ -z "$PACKAGER" ]; then
        echo "${RED}Can't find a supported package manager${RC}" | tee -a "$LOG_FILE"
        exit 1
    fi

    if command_exists sudo; then
        SUDO_CMD="sudo"
    elif command_exists doas && [ -f "/etc/doas.conf" ]; then
        SUDO_CMD="doas"
    else
        SUDO_CMD="su -c"
    fi

    echo "Using $SUDO_CMD as privilege escalation software" | tee -a "$LOG_FILE"

    ## Check if the current directory is writable.
    GITPATH=$(dirname "$(realpath "$0")")
    if [ ! -w "$GITPATH" ]; then
        echo "${RED}Can't write to $GITPATH${RC}"
        exit 1
    fi

    ## Check SuperUser Group

    SUPERUSERGROUP='wheel sudo root'
    for sug in $SUPERUSERGROUP; do
        if groups | grep --quiet "$sug"; then
            SUGROUP="$sug"
            echo "Super user group $SUGROUP" | tee -a "$LOG_FILE"
            break
        fi
    done

    ## Check if member of the sudo group.
    if ! groups | grep --quiet "$SUGROUP"; then
        echo "${RED}You need to be a member of the sudo group to run me!${RC}" | tee -a "$LOG_FILE"
        exit 1
    fi
}

installDepend() {
    ## Check for dependencies.
    DEPENDENCIES='bash bash-completion tar bat tree multitail fastfetch wget unzip fontconfig'
    if ! command_exists nvim; then
        DEPENDENCIES="${DEPENDENCIES} neovim"
    fi

    echo "${YELLOW}Installing dependencies...${RC}"
    if [ "$PACKAGER" = "pacman" ]; then
        if ! command_exists yay && ! command_exists paru; then
            echo "Installing yay as AUR helper..."
            ${SUDO_CMD} ${PACKAGER} --noconfirm -S base-devel
            cd /opt && ${SUDO_CMD} git clone https://aur.archlinux.org/yay-git.git && ${SUDO_CMD} chown -R "${USER}:${USER}" ./yay-git
            cd yay-git && makepkg --noconfirm -si
        else
            echo "AUR helper already installed"
        fi
        if command_exists yay; then
            AUR_HELPER="yay"
        elif command_exists paru; then
            AUR_HELPER="paru"
        else
            echo "No AUR helper found. Please install yay or paru."
            exit 1
        fi
        ${AUR_HELPER} --noconfirm -S ${DEPENDENCIES}
    elif [ "$PACKAGER" = "nala" ]; then
        ${SUDO_CMD} ${PACKAGER} install -y ${DEPENDENCIES}
    elif [ "$PACKAGER" = "emerge" ]; then
        ${SUDO_CMD} ${PACKAGER} -v app-shells/bash app-shells/bash-completion app-arch/tar app-editors/neovim sys-apps/bat app-text/tree app-text/multitail app-misc/fastfetch
    elif [ "$PACKAGER" = "xbps-install" ]; then
        ${SUDO_CMD} ${PACKAGER} -v ${DEPENDENCIES}
    elif [ "$PACKAGER" = "nix-env" ]; then
        ${SUDO_CMD} ${PACKAGER} -iA nixos.bash nixos.bash-completion nixos.gnutar nixos.neovim nixos.bat nixos.tree nixos.multitail nixos.fastfetch  nixos.pkgs.starship
    elif [ "$PACKAGER" = "dnf" ]; then
        ${SUDO_CMD} ${PACKAGER} install -y ${DEPENDENCIES}
    else
        ${SUDO_CMD} ${PACKAGER} install -y ${DEPENDENCIES}
    fi

    # Check to see if the MesloLGS Nerd Font is installed (Change this to whatever font you would like)
    FONT_NAME="MesloLGS Nerd Font Mono"
    if fc-list :family | grep -iq "$FONT_NAME"; then
        echo "Font '$FONT_NAME' is installed."
    else
        echo "Installing font '$FONT_NAME'"
        # Change this URL to correspond with the correct font
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
        FONT_DIR="$HOME/.local/share/fonts"
        # check if the file is accessible
        if wget --quiet --spider "$FONT_URL"; then
            TEMP_DIR=$(mktemp -d)
            wget --quiet --show-progress $FONT_URL -O "$TEMP_DIR"/"${FONT_NAME}".zip
            unzip "$TEMP_DIR"/"${FONT_NAME}".zip -d "$TEMP_DIR"
            mkdir -p "$FONT_DIR"/"$FONT_NAME"
            mv "${TEMP_DIR}"/*.ttf "$FONT_DIR"/"$FONT_NAME"
            # Update the font cache
            fc-cache -fv
            # delete the files created from this
            rm -rf "${TEMP_DIR}"
            echo "'$FONT_NAME' installed successfully."
        else
            echo "Font '$FONT_NAME' not installed. Font URL is not accessible."
        fi
    fi
}

installStarshipAndFzf() {
    if command_exists starship; then
        echo "Starship already installed"
        return
    fi

    if ! curl -sS https://starship.rs/install.sh | sh; then
        echo "${RED}Something went wrong during starship install!${RC}"
        exit 1
    fi
    if command_exists fzf; then
        echo "Fzf already installed"
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install
    fi
}

installZoxide() {
    if command_exists zoxide; then
        echo "Zoxide already installed"
        return
    fi

    if ! curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
        echo "${RED}Something went wrong during zoxide install!${RC}"
        exit 1
    fi
}

create_fastfetch_config() {
    ## Get the correct user home directory.
    USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)

    if [ ! -d "$USER_HOME/.config/fastfetch" ]; then
        mkdir -p "$USER_HOME/.config/fastfetch"
    fi
    # Check if the fastfetch config file exists
    if [ -e "$USER_HOME/.config/fastfetch/config.jsonc" ]; then
        rm -f "$USER_HOME/.config/fastfetch/config.jsonc"
    fi
    ln -svf "$GITPATH/config.jsonc" "$USER_HOME/.config/fastfetch/config.jsonc" || {
        echo "${RED}Failed to create symbolic link for fastfetch config${RC}"
        exit 1
    }
}

linkConfig() {
    ## Get the correct user home directory.
    USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
    ## Check if a bashrc file is already there.
    OLD_BASHRC="$USER_HOME/.bashrc"
    if [ -e "$OLD_BASHRC" ]; then
        echo "${YELLOW}Moving old bash config file to $USER_HOME/.bashrc.bak${RC}"
        if ! mv "$OLD_BASHRC" "$USER_HOME/.bashrc.bak"; then
            echo "${RED}Can't move the old bash config file!${RC}"
            exit 1
        fi
    fi

    echo "${YELLOW}Linking new bash config file...${RC}"
    ln -svf "$GITPATH/.bashrc" "$USER_HOME/.bashrc" || {
        echo "${RED}Failed to create symbolic link for .bashrc${RC}"
        exit 1
    }
    ln -svf "$GITPATH/starship.toml" "$USER_HOME/.config/starship.toml" || {
        echo "${RED}Failed to create symbolic link for starship.toml${RC}"
        exit 1
    }
}

sync_and_backup() {
    DST_DRIVE=$(blkid -L ${BACKUP_DRIVE_NAME} 2>/dev/null)
    if [ -z "$DST_DRIVE" ]; then
    echo "Error: Drive labeled '${BACKUP_DRIVE_NAME}' not found."
    exit 1
    fi

    DST_DIR=${DST_DRIVE}/

    # Create necessary directories if they don't exist
    ${SUDO_CMD} mkdir -p ${DST_DIR}

    # Set up real-time syncing using rsync
    ${SUDO_CMD} rsync -av --progress --delete ${SRC_DIR}/ ${DST_DIR}/

    # Add incrontab rule
    ${SUDO_CMD} incrontab -e << EOF
    /${SRC_DIR}/ IN_MODIFY,IN_CREATE,IN_DELETE rsync -av --progress --delete ${SRC_DIR}/ ${DST_DIR}/
EOF

    # Restart incron daemon
    ${SUDO_CMD} service incron restart || ${SUDO_CMD} systemctl restart incron
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
    checkEnv
    check_conda
    installDepend
    installStarshipAndFzf
    installZoxide
    create_fastfetch_config
    linkConfig
    sync_and_backup
    install_packages
    install_pip_on_base_env
    install_conda_packages
    conda update -n base -c defaults conda
    install_third_party_apps
    install_snap_packages
    install_flatpak_packages
    install_appimages
    # prompt_desktop_environment

    log "INFO" "Finished main function."
}

main "$@"
log "INFO" "Script finished successfully."
echo "${RED}Please go to POWER MANAGEMENT and set sleep mode to HYBRID SLEEP (Save session to memory and disk)${RC}" | tee -a "$LOG_FILE"



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
