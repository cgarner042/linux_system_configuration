#!/bin/sh -x
exec > >(tee $HOME/Desktop/setup_terminal_output.log) 2>&1
###################
# Initialize variables
###################

## Colors
RC='\033[0m'
RED='\033[31m'      # failure
YELLOW='\033[33m'   # info
GREEN='\033[32m'    # success / already installed / finished function
BLUE='\033[34m'     # other
MAGENTA='\033[35m'  # file contents
CYAN='\033[36m'     # skipping

## System variables
USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
APPIMAGES_DIR="$HOME/AppImages"
PACKAGER=""
SUDO_CMD=""
SUGROUP=""

## Git global variables
GIT_NAME="Chris Garner"
GIT_EMAIL="cgarner042@gmail.com"

## Installation tracking
# Should these move back to respective functions?
INSTALLED=()
uninstalled_dependencies=()
FAILED_DEPENDENCIES=()
uninstalled_packages=()
FAILED_PACKAGES=()
uninstalled_pip_packages=()
FAILED_PIP=()
uninstalled_conda_packages=()
FAILED_CONDA=()
uninstalled_deb_rpm_packages=()
FAILED_DEB_RPM_PACKAGES=()
uninstalled_snap_packages=()
FAILED_SNAP_PACKAGES=()
uninstalled_flatpak_packages=()
FAILED_FLATPAK_PACKAGES=()
FAILED_APPIMAGE=()
FAILED_EXTRA_SCRIPTS=()
FAILED_MISC=()


###################
# Logging & Debugging
###################

LOG_FILE="$HOME/logs/linux_set_up.log"

log() {
    local level="${1:-INFO}"
    local message="$2"
    echo -e "[$level] - $message" | tee -a "$LOG_FILE"
}

# Initialize log
log "Starting script..."
echo -e "$(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"

# Trap error and write to log file
trap 'log "ERROR" "Error occurred in ${BASH_SOURCE[0]} at line ${LINENO}: $? - $BASH_COMMAND"' ERR

# Debugging: Test the error trap by using a failing command
log "INFO" "Testing the error trap..."
false

critical_error() {
    local message="$1"
    log "ERROR" "${RED}$message${RC}"
    log "ERROR" "${RED}Critical error. Exiting script.${RC}"
    exit 1
}

###################
# Pre-installation Checks
###################

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_nvidia() {
    if lspci | grep -i nvidia > /dev/null; then
        log "NVIDIA GPU detected. Checking drivers..."
        if ! nvidia-smi > /dev/null 2>&1; then
            log "WARN" "${RED}NVIDIA drivers not installed or not functioning properly${RC} \n${BLUE}nvidia.run:${RC} https://http.download.nvidia.com/XFree86/Linux-x86_64/384.111/README/installdriver.html \n${BLUE}opensuse wiki:${RC} https://en.opensuse.org/SDB:NVIDIA \n${BLUE}ubuntu:${RC} https://ubuntu.com/server/docs/nvidia-drivers-installation \n${BLUE}arch:${RC} https://wiki.archlinux.org/title/NVIDIA"
            exit 1
        else
            log "${GREEN}NVIDIA drivers are properly installed${RC}"
        fi
    else
        log "No NVIDIA GPU detected"
    fi
}

checkEnv() {
    ## Check for requirements.
    REQUIREMENTS='curl groups sudo'
    for req in $REQUIREMENTS; do
        if ! command_exists "$req"; then
            echo "${RED}To run me, you need: $REQUIREMENTS${RC}"
            exit 1
        fi
    done
    ## Check Package Handler
    PACKAGEMANAGER='nala apt dnf zypper'
    for pgm in $PACKAGEMANAGER; do
        if command_exists "$pgm"; then
            PACKAGER="$pgm"
            break
        fi
    done
    if [ -z "$PACKAGER" ]; then
        echo "${RED}Can't find a supported package manager${RC}"
        exit 1
    fi
    ## Set system variables
    case $PACKAGER in
        nala|apt)
            INSTALL="install -y"
            CLEAN="clean"
            UPDATE="update"
            UPGRADE="upgrade"
            CLAM="clamav clamav-daemon"
            package_urls=("${DEB_URLS[@]}")
            url_keys=("${!DEB_URLS[@]}")
            package_ext=.deb
            install_cmd="dpkg -i"
            fix_dep_flag="--fix-broken -y"
            ;;
        zypper)
            INSTALL="install -n"
            CLEAN="clean all"
            UPDATE="update"
            CLAM="clamav"
            package_urls=("${RPM_URLS[@]}")
            url_keys=("${!RPM_URLS[@]}")
            package_ext=.rpm
            install_cmd="rpm -i"
            fix_dep_flag="--fix-dependencies -n"
            ;;
        dnf)
            INSTALL="install -y"
            CLEAN="clean all"
            UPDATE="check-update"
            UPGRADE="upgrade"
            CLAM="clamav clamd clamav-update"
            package_urls=("${RPM_URLS[@]}")
            url_keys=("${!RPM_URLS[@]}")
            package_ext=.rpm
            install_cmd="rpm -i"
            fix_dep_flag="--fixdep -y"
            ;;
        *)
            log "ERROR" "${RED}Unsupported package manager: $PACKAGER${RC}"
            return 1
            ;;
    esac
    ## Check sudo
    if command_exists sudo; then
        SUDO_CMD="sudo"
    elif command_exists doas && [ -f "/etc/doas.conf" ]; then
        SUDO_CMD="doas"
    else
        SUDO_CMD="su -c"
    fi
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
            break
        fi
    done
    ## Check if member of the sudo group.
    if ! groups | grep --quiet "$SUGROUP"; then
        echo "${RED}You need to be a member of the sudo group to run me!${RC}"
        exit 1
    fi
    log "${BLUE}System variables are:${RC}${YELLOW}\nGITPATH=${BLUE}${GITPATH} \n${YELLOW}SUGROUP=${BLUE}${SUGROUP} \n${YELLOW}SUDO_CMD=${BLUE}${SUDO_CMD} \n${YELLOW}PACKAGER=${BLUE}${PACKAGER} \n${YELLOW}INSTALL=${BLUE}${INSTALL}${RC}"
    log "${CYAN}##############################################${RC}"
}

check_package(){
    case $PACKAGER in
        nala|apt)
            dpkg -l | grep -q "$1"
            ;;
        dnf|yum)
            rpm -qa | grep -q "$1"
            ;;
        zypper)
            zypper packages --installed-only | grep -q "$1"
            ;;
    esac
}

cleanup() {
    log "${YELLOW}Performing cleanup...${RC}"
    # Remove temporary files
    rm -rf /tmp/setup_* 2>/dev/null
    if [ -n "$PACKAGER" ]; then
        ${SUDO_CMD} ${PACKAGER} ${CLEAN}
    fi
}

update(){
    log "${YELLOW}Performing updates${RC}"
    case $PACKAGER in
        nala|apt|dnf)
            ${SUDO_CMD} ${PACKAGER} ${UPDATE} && ${SUDO_CMD} ${PACKAGER} ${UPGRADE}
            ;;
        zypper)
            ${SUDO_CMD} ${PACKAGER} ${UPDATE}
            ;;
        esac
}

###################
# Configuration
###################

DEPENDENCIES=(
    "bash"
    "bash-completion"
    "trash-cli"
    "ripgrep"
    "tar"
    "bat"
    "tree"
    "multitail"
    "fastfetch"
    "wget"
    "unzip"
    "fontconfig"
    "gnome-terminal" #dependency for git desktop #switched to git kraken? may not need anymore
    "rsync"
    "virt-manager"
    "git"
    "htop"
    "build-essential"
    "incron"
    "net-tools"
    "ncdu"
    # bechmarking for troublshooting script
    "fio"
    "sysstat"
    "mesa-utils"
    "vulkan-sdk"
    "stress-ng"
    "mbw"

)

# System config files
CONFIG_FILES=(
    ".bashrc:$USER_HOME/.bashrc"
    "starship.toml:$USER_HOME/.config/starship.toml"
)

# Packages to install
PACKAGES=(
    "arduino"
    "darktable"
    "cantor"
    "labplot"
    "gedit"
    "gnome-disk-utility"
    "librewolf"
)

# Pip packages to install
PIP_PACKAGES=(
    "pyqt5"
    "pyqtwebengine"
    "selenium"
    "webdriver-manager"
    "beautifulsoup4"
    "chromedriver-autoinstaller"
    "html2text"
)

# Conda channels to install
CONDA_CHANNELS=(
    "pytorch"
    "huggingface"
    "nvidia"
)

# Conda packages to install
CONDA_PACKAGES=(

)

# Snap packages to install
SNAP_PACKAGES=(
    "vlc"
    "spotify"
    "freecad"
    "opera"
    "mailspring"
    "code"
    "kate"
    "ksnip"
    "gitkraken"
    "mdless"
    "okular"
    "spectacle"
    "marktext"
    "typora"

)

# Flatpak packages to install
FLATPAK_PACKAGES=(

)

# Backup anaconda version to install if promt is skipped
ANACONDA_VERSION="2023.09-0"

# AppImage configurations
declare -A APPIMAGE_CONFIGS
APPIMAGE_CONFIGS=(
    ["cura"]="https://github.com/Ultimaker/Cura/releases/download/5.7.2-RC2/UltiMaker-Cura-5.7.2-linux-X64.AppImage|Ultimaker Cura|cura-icon.png|Graphics"
    ["krita"]="https://download.kde.org/stable/krita/5.1.5/krita-5.1.5-x86_64.appimage|Krita|krita.png|Graphics"
    ["zettlr"]="https://www.zettlr.com/download/appimage64|Zettlr markdown editor|Utility;TextEditor;Development;Office;"
)

# URLs for .deb files
declare -A DEB_URLS
DEB_URLS=(
    ["google-chrome"]="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    ["docker-desktop"]="https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb"
)

# URLs for RPM files
declare -A RPM_URLS
RPM_URLS=(
    ["google-chrome"]="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.rpm"
    ["docker-desktop"]="https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.rpm"
)

###################
# Script Functions
###################

get_anaconda_version() {
    local max_retries=3
    local retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        echo "${YELLOW}Please visit https://repo.anaconda.com/archive/ to see the latest version (ex: 2024.10-1)${RC}"
        read -p "Enter the latest Anaconda version (press enter to use default: $ANACONDA_VERSION): " user_input
        # If user presses enter without input, use the default value
        if [ -z "$user_input" ]; then
            anaconda_version=$ANACONDA_VERSION
        else
            anaconda_version=$user_input
        fi
        # Validate the input
        if [[ $anaconda_version =~ ^[0-9]{4}\.[0-9]{2}-[0-9]+$ ]]; then
            echo "You entered: $anaconda_version"
            return 0
        else
            echo "${RED}Invalid version format. Please try again.${RC}"
            retry_count=$((retry_count + 1))
        fi
    done
    # If we reach this point, all retries failed
    echo "${YELLOW}Max retries exceeded. Using default version: $ANACONDA_VERSION${RC}"
    anaconda_version=$ANACONDA_VERSION
}

install_anaconda() {
    get_anaconda_version
    log "${YELLOW}Installing Anaconda...${RC}"
    log "Using Anaconda version $anaconda_version"
    wget "https://repo.anaconda.com/archive/Anaconda3-${anaconda_version}-Linux-x86_64.sh" -O anaconda.sh || critical_error "Failed to download Anaconda"
    bash anaconda.sh -b -p "$HOME/anaconda3" || critical_error "Failed to install Anaconda" && FAILED_MISC+=("anaconda")
    rm anaconda.sh
    log "Initializing Conda"
    "$HOME/anaconda3/bin/conda" init || log "ERROR" "${RED}Failed to initialize Conda${RC}"
    log "${GREEN}Finished install_anaconda function.${RC}"
}

check_conda() {
    log "Checking for Conda"
    if command_exists conda; then
        log "${GREEN}Anaconda is already installed.${RC}"
    else
        log "installing Anaconda"
        install_anaconda
        # restart script to make conda and pip commands available
        exec bash "${BASH_SOURCE[0]}"
    fi
}

installDepend() {
    ## Check for dependencies.
    log "$YELLOW}Checking for dependencies...${RC}"
    for dep in ${DEPENDENCIES[@]}; do
        if ! check_package "$dep"; then
            uninstalled_dependencies+=("$dep")
        fi
    done
    log "${YELLOW}Installing dependencies...${RC}"
    for dependency in ${uninstalled_dependencies[@]}; do
        log "Installing $dependency..."
        ${SUDO_CMD} ${PACKAGER} ${INSTALL} "$dependency" || log "ERROR" "${RED}Failed to install $dependency${RC}" && FAILED_DEPENDENCIES+=("$dependency")
    done
    for depend in ${DEPENDENCIES[@]}; do
        if check_package "$depend"; then
            INSTALLED+=("$depend")
        fi
    done
    log "${GREEN}Finished installing system dependencies.${RC}"
    # Check to see if the MesloLGS Nerd Font is installed (Change this to whatever font you would like)
    FONT_NAME="MesloLGS Nerd Font Mono"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    FONT_DIR="$HOME/.local/share/fonts"
    if fc-list :family | grep -iq "$FONT_NAME"; then
        log "${GREEN}Font '$FONT_NAME' is already installed.${RC}"
    else
        log "${YELLOW}Installing font '$FONT_NAME'${RC}"
        # check if the file is accessible
        if wget --quiet --spider "$FONT_URL"; then
            TEMP_DIR=$(mktemp -d)
            wget --quiet --show-progress $FONT_URL -O "$TEMP_DIR"/"${FONT_NAME}".zip || log "ERROR" "${RED}$FONT_NAME failed to download${RC}" && FAILED_DEPENDENCIES+=("$FONT_NAME")
            unzip "$TEMP_DIR"/"${FONT_NAME}".zip -d "$TEMP_DIR" || log "ERROR" "${RED}Failed to unzip $FONT_NAME${RC}" && FAILED_DEPENDENCIES+=("$FONT_NAME")
            mkdir -p "$FONT_DIR"/"$FONT_NAME" || log "ERROR" "${RED}Failed to make directory for $FONT_NAME${RC}" && FAILED_DEPENDENCIES+=("$dependency")
            mv "${TEMP_DIR}"/*.ttf "$FONT_DIR"/"$FONT_NAME" || log "ERROR" "${RED}Failed to move .ttf to $FONT_DIR/$FONT_NAME${RC}" && FAILED_DEPENDENCIES+=("$FONT_NAME")
            # Update the font cache
            fc-cache -fv
            # delete the files created from this
            rm -rf "${TEMP_DIR}"
            log "'$FONT_NAME' installed successfully."
        else
            log "Font '$FONT_NAME' not installed. Font URL is not accessible."
        fi
    fi
        log "${GREEN}Finished installDepend function.${RC}"
}

install_packages() {
    log "${YELLOW}Checking for packages...${RC}"
    for package in "${PACKAGES[@]}"; do
        if ! check_package "$package"; then
            uninstalled_packages+=("$package")
        fi
    done
    log "${YELLOW}Installing packages...${RC}"
    for package in "${uninstalled_packages[@]}"; do
        log "Installing $package..."
        ${SUDO_CMD} ${PACKAGER} ${INSTALL} "$package" || log "ERROR" "${RED}$package failed to install${RC}" && FAILED_PACKAGES+=("$package")
    done
    for package in "${PACKAGES[@]}"; do
        if check_package "$package"; then
            INSTALLED+=("$package")
        fi
    done
    log "${GREEN}Finished install_packages function.${RC}"
}

install_pip_on_base_env() {
    log "${YELLOW}Checking for missing pip packages in base environment...${RC}"
    for pip_package in "${PIP_PACKAGES[@]}"; do
        if ! pip show "$pip_package" > /dev/null 2>&1; then
            uninstalled_pip_packages+=("$pip_package")
        fi
    done
    log "${YELLOW}Installing missing pip packages...${RC}"
    for pip_package in "${uninstalled_pip_packages[@]}"; do
        log "Installing $pip_package..."
        pip install "$pip_package" || log "ERROR" "${RED}Failed to install $pip_package${RC}" && FAILED_PIP+=("$pip_package")
    done
    for pip_package in "${PIP_PACKAGES[@]}"; do
        if pip show "$pip_package" > /dev/null 2>&1; then
            INSTALLED+=("$pip_package")
        fi
    done
    log "${GREEN}Finished installing pip packages in base environment.${RC}"
}

install_conda_packages() {
    log "${YELLOW}Checking for missing conda packages in base environment...${RC}"
    for conda_package in "${CONDA_PACKAGES[@]}"; do
        if ! conda list "$conda_package" | grep "$conda_package" > /dev/null 2>&1; then
            uninstalled_conda_packages+=("$conda_package")
        fi
    done
    log "${YELLOW}Installing missing conda packages...${RC}"
    for conda_package in "${uninstalled_conda_packages[@]}"; do
        log "Installing $conda_package..."
        conda install "$conda_package" -y || log "ERROR" "${RED}Failed to install $conda_package${RC}" && FAILED_CONDA+=("$conda_package")
    done
    for conda_package in "${CONDA_PACKAGES[@]}"; do
        if conda list "$conda_package" | grep "$conda_package" > /dev/null 2>&1; then
            INSTALLED+=("$conda_package")
        fi
    done
    log "${GREEN}Finished installing conda packages in base environment.${RC}"
}

install_deb_rpm_packages() {
    log "${YELLOW}Checking for missing deb/rpm packages${RC}"
    for ((i=0; i<${#package_urls[@]}; i++)); do
        local app_name="${url_keys[$i]}"
        local package_url="${package_urls[$i]}"
        local package_file="${app_name}${package_ext}"
        if ! check_package "$app_name"; then
            uninstalled_deb_rpm_packages+=("$i")
        fi
    done
    log "${YELLOW}Installing missing deb/rpm packages${RC}"
    for i in "${uninstalled_deb_rpm_packages[@]}"; do
        local app_name="${url_keys[$i]}"
        local package_url="${package_urls[$i]}"
        local package_file="${app_name}${package_ext}"
        log "Downloading $app_name..."
        wget "$package_url" -O "$package_file" || log "ERROR" "${RED}Failed to download $app_name${RC}" && FAILED_DEB_RPM_PACKAGES+=("$app_name")
        log "Installing $app_name..."
        ${SUDO_CMD} ${install_cmd} "$package_file" || log "ERROR" "${RED}Failed to install $app_name${RC}" && FAILED_DEB_RPM_PACKAGES+=("$package_file")
        log "Fixing dependencies for $app_name..."
        ${SUDO_CMD} ${PACKAGER} install $fix_dep_flag || log "ERROR" "${RED}Failed to resolve dependencies for $app_name${RC}"
        rm "$package_file"
    done
    for ((i=0; i<${#package_urls[@]}; i++)); do
        local app_name="${url_keys[$i]}"
        local package_url="${package_urls[$i]}"
        local package_file="${app_name}${package_ext}"
        if check_package "$app_name"; then
            INSTALLED+=("$i")
        fi
    done
    log "${GREEN}Finished installing deb/rpm packages.${RC}"
}

install_snap_packages() {
    log "Checking for Snap package manager..."
    if ! command_exists snap; then
        log "WARN" "${YELLOW}Snap package manager not found. Installing Snap...${RC}"
        ${SUDO_CMD} ${PACKAGER} ${INSTALL} "snapd" || log "ERROR" "${RED}Failed to install Snap package manager${RC}"
    fi
    log "${YELLOW}Checking for missing Snap packages${RC}"
    for snap_package in "${SNAP_PACKAGES[@]}"; do
        if ! snap list "$snap_package" > /dev/null 2>&1; then
            uninstalled_snap_packages+=("$snap_package")
        fi
    done
    log "${YELLOW}Installing missing Snap packages...${RC}"
    for snap_package in "${uninstalled_snap_packages[@]}"; do
        log "Installing $snap_package..."
        ${SUDO_CMD} snap install "$snap_package" || log "ERROR" "${RED}Failed to install Snap package $snap_package${RC}" && FAILED_SNAP_PACKAGES+=("$snap_package")
    done
    for snap_package in "${SNAP_PACKAGES[@]}"; do
        if snap list "$snap_package" > /dev/null 2>&1; then
            INSTALLED+=("$snap_package")
        fi
    done
    log "${GREEN}Finished installing Snap packages.${RC}"
}

install_flatpak_packages() {
    log "Checking for Flatpak package manager..."
    if ! command_exists flatpak; then
        log "WARN" "${YELLOW}Flatpak package manager not found. Installing Flatpak...${RC}"
        ${SUDO_CMD} ${PACKAGER} ${INSTALL} "flatpak" || log "ERROR" "${RED}Failed to install Flatpak package manager${RC}"
    fi
    log "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    log "${YELLOW}Checking for missing Flatpak packages${RC}"
    for flatpak_package in "${FLATPAK_PACKAGES[@]}"; do
        if ! flatpak info "$flatpak_package" >/dev/null 2>&1; then
            uninstalled_flatpak_packages+=("$flatpak_package")
        fi
    done
    log "${YELLOW}Installing missing Flatpak packages...${RC}"
    for flatpak_package in "${uninstalled_flatpak_packages[@]}"; do
        log "Installing $flatpak_package..."
        flatpak install -y flathub "$flatpak_package" || log "ERROR" "${RED}Failed to install Flatpak package $flatpak_package${RC}" && FAILED_FLATPAK_PACKAGES+=("$flatpak_package")
    done
    for flatpak_package in "${FLATPAK_PACKAGES[@]}"; do
        if flatpak info "$flatpak_package" >/dev/null 2>&1; then
            INSTALLED+=("$flatpak_package")
        fi
    done
    log "${GREEN}Finished installing Flatpak packages.${RC}"
}

install_appimages() {
    # Create AppImages directory if it doesn't exist
    if [ ! -e "$APPIMAGES_DIR" ]; then
        mkdir -p "$APPIMAGES_DIR"
    fi
    for appimage in "${!APPIMAGE_CONFIGS[@]}"; do
        IFS='|' read -r url name icon category <<< "${APPIMAGE_CONFIGS[$appimage]}"
        appimage_file="$APPIMAGES_DIR/$appimage.AppImage"
        desktop_file="$HOME/Desktop/$appimage.desktop"
        icon_file="$HOME/.local/share/icons/$icon"
        log "${YELLOW}Checking if AppImage is already installed${RC}"
        if [ -d "/opt/$appimage" ] && [ -f "/usr/share/applications/$appimage.desktop" ]; then
            log ${CYAN}"Skipping $name (already installed)"
            INSTALLED+=("$name")
            continue
        elif [ -d "/opt/$appimage" ]; then
            log "WARNING" "${YELLOW}$appimage directory exists, but .desktop file missing${RC}"
        elif [ -f "/usr/share/applications/$appimage.desktop" ]; then
            log "WARNING" "${YELLOW}$appimage .desktop file exists, but directory missing${RC}"
        fi
        log "Downloading $name..."
        if [ -f "$appimage_file" ]; then
            log "Using existing $appimage_file"
        else
            wget "$url" -O "$appimage_file" || log "ERROR" "${RED}Failed to download $name${RC}" && FAILED_APPIMAGE+=("${appimage_file}_[download]")
        fi
        # Extract and install AppImage
        chmod +x "$appimage_file"
        log "Extracting $appimage AppImage..."
        if ! "$appimage_file" --appimage-extract; then
            log "ERROR" "${RED}Failed to extract $appimage AppImage${RC}"
            FAILED_APPIMAGE+=("${appimage}_[extraction]")
            continue
        fi
        # Move extracted contents to /opt
        ${SUDO_CMD} mv squashfs-root "/opt/$appimage" || log "ERROR" "${RED}Failed to move $appimage to /opt${RC}" && FAILED_APPIMAGE+=("${appimage}_[mv]")
        # Create and install .desktop file
        log "Creating desktop entry for $name..."
        if [ -f "$desktop_file" ]; then
            log "Using existing $desktop_file"
        else
            cat << EOF > "$desktop_file" || log "ERROR" "${RED}Failed to create .desktop file for $appimage${RC}" && FAILED_APPIMAGE+=("${appimage}_[.desktop]")
[Desktop Entry]
Name=$name
Exec=/opt/$appimage/AppRun
Icon=/opt/$appimage/$icon
Type=Application
Categories=$category;
EOF
        fi
        ${SUDO_CMD} desktop-file-install "$desktop_file" || log "ERROR" "${RED}Failed to move $appimage.desktop to /usr/share/applications${RC}" && FAILED_APPIMAGE+=("$appimage [mv .desktop]")

        log "DEBUG" "${YELLOW}Contents of $desktop_file:${RC}"
        cat "$desktop_file" | while IFS= read -r line; do
            log "DEBUG" "${MAGENTA}$line${RC}"
        INSTALLED+=("$name")
        done
    done
    log "${GREEN}Finished install_appimages function.${RC}"
}

###################
# Extra Applications
###################

install_extra_apps() {
    log "${YELLOW}Gathering extra install scripts...${RC}"
    if [ -d "$GITPATH/extra_install_scripts" ]; then
        for script in "$GITPATH/extra_install_scripts"/*; do
            script_name=$(basename "$script" | cut -d '.' -f 1)
            if command_exists "$script_name"; then
                continue
            fi
            case "$script" in
                *.sh)
                    log "Running extra installation script: $(basename "$script")"
                    if ! bash "$script" | tee -a "$HOME/Desktop/setup_terminal_output.log"; then
                        log "ERROR" "${RED}Failed to run $(basename "$script")${RC}"
                        FAILED_EXTRA_SCRIPTS+=("$(basename "$script")")
                    else
                        INSTALLED+=("$script_name")
                    fi
                    ;;
                *.run)
                    if ! chmod +x "$script" || ! "./$script" | tee -a "$HOME/Desktop/setup_terminal_output.log"; then
                        log "ERROR" "${RED}Failed to run $(basename "$script")${RC}"
                        FAILED_EXTRA_SCRIPTS+=("$(basename "$script")")
                    else
                        INSTALLED+=("$script_name")
                    fi
                    ;;
            esac
        done
    else
        log "ERROR" "${RED}$GITPATH/extra_install_scripts does not exist${RC}"
    fi
}

install_clam_av(){
    log "${YELLOW} Checking for ClamAV...${RC}"
    for service in "${CLAM_SERVICES[@]}"; do
        if ! command_exists "$service"; then
            log "${YELLOW}Installing clamav anti-virus...${RC}"
            if [[ "$PACKAGER" == "dnf" ]] || [[ "$PACKAGER" == "yum" ]]; then
                ${SUDO_CMD} ${PACKAGER} ${INSTALL} "epel-release"
            fi
            ${SUDO_CMD} ${PACKAGER} ${INSTALL} ${CLAM} || log "ERROR" "${RED}clamav failed to install${RC}" && FAILED_MISC+=("clamav")
            log "Initialize and start ClamAV services"
            ${SUDO_CMD} systemctl stop clamav-freshclam || log "ERROR" "${RED}stop freshclam${RC}"
            ${SUDO_CMD} freshclam || log "ERROR" "${RED}freshclam${RC}"
            ${SUDO_CMD} systemctl start clamav-freshclam || log "ERROR" "${RED}start freshclam${RC}"
        fi
    done
    for service in "${CLAM_SERVICES[@]}"; do
        if ! command_exists "$service"; then
            log "ERROR" "ClamAV service $service failed"
            uninstalled_packages+=("$service")
        else
            INSTALLED+=("$service")
        fi
    done
}

install_ollama(){
    if ! command_exists ollama; then
        curl -fsSL https://ollama.com/install.sh | sh || log "ERROR" "Failed to install ollama" && FAILED_MISC+=("ollama")
        INSTALLED+=("ollama")
    fi
}

installStarshipAndFzf() {
    if command_exists starship; then
        log "${GREEN}Starship already installed${RC}"
        return
    fi
    if ! curl -sS https://starship.rs/install.sh | sh; then
        log "ERROR" "${RED}Something went wrong during starship install!${RC}" && FAILED_MISC+=("starship")
        exit 1
    fi
    if command_exists fzf; then
        log "${GREEN}Fzf already installed${RC}"
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install
    fi
}

installZoxide() {
    if command_exists zoxide; then
        log "${GREEN}Zoxide already installed${RC}"
        return
    fi
    if ! curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
        log "ERROR" "${RED}Something went wrong during zoxide install!${RC}" && FAILED_MISC+=("zoxide")
        exit 1
    fi
}

###################
# Final Configurations
###################

setup_conda_env() {
  # Add conda channels
  log "${YELLOW}Adding conda channels...${RC}"
  for channel in "${CONDA_CHANNELS[@]}"; do
    if ! conda config --add channels "$channel"; then
      log "ERROR" "${RED}Failed to add $channel channel${RC}"
    fi
  done

  # Create conda environments
  log "${YELLOW}Gathering conda env setup files...${RC}"
  local conda_env_dir="$GITPATH/conda_env"
  if [ ! -d "$conda_env_dir" ]; then
    log "ERROR" "${RED}Directory $conda_env_dir does not exist.${RC}"
    return
  fi
  for yaml_file in "$conda_env_dir"/*.yaml; do
    if ! conda env create -f "$yaml_file"; then
      log "ERROR" "${RED}Failed to create conda environment from ${yaml_file##*/}${RC}"
      FAILED_CONDA+=("${yaml_file##*/}")
    fi
  done
}

create_fastfetch_config() {
    if [ -e "$USER_HOME/.config/fastfetch/config.jsonc" ]; then
    read -p "Fastfetch config exists. Backup and overwrite? (y/n) " -n 1 -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log "${CYAN}Skipping fastfetch config${RC}"
    else
        log "${YELLOW}Creating fastfetch config...${RC}"
        if [ ! -d "$USER_HOME/.config/fastfetch" ]; then
            mkdir -p "$USER_HOME/.config/fastfetch"
        fi
        # Check if the fastfetch config file exists
        if [ -e "$USER_HOME/.config/fastfetch/config.jsonc" ]; then
            rm -f "$USER_HOME/.config/fastfetch/config.jsonc"
        fi
        cp -vf "$GITPATH/config.jsonc" "$USER_HOME/.config/fastfetch/config.jsonc" || {
            log "ERROR" "${RED}Failed to copy fastfetch config${RC}" && FAILED_MISC+=("fastfetch config.json")
            exit 1
            }
    fi
    fi

}

linkConfigFile() {
    local FILE_NAME="$1"
    local FILE_PATH="$2"
    local BACKUP_PATH="$FILE_PATH.bak.$(date +%Y%m%d%H%M%S)"
    local GIT_FILE_PATH="$GITPATH/$FILE_NAME"
    if [ -e "$FILE_PATH" ]; then
        read -p "$FILE_NAME exists. Backup and overwrite? (y/n) " -n 1 -r
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log "${CYAN}Skipping $FILE_NAME backup${RC}"
        else
            if cmp --silent "$GIT_FILE_PATH" "$FILE_PATH"; then
                log "${CYAN}$FILE_NAME is identical to intended config, skipping${RC}"
            else
                if ! mv "$FILE_PATH" "$BACKUP_PATH"; then
                    log "ERROR" "${RED}Can't move the old $FILE_NAME!${RC}"
                    exit 1
                fi
                log "${YELLOW}Linking new $FILE_NAME...${RC}"
                cp -vf "$GIT_FILE_PATH" "$FILE_PATH" || {
                    log "ERROR" "${RED}Failed to copy $FILE_NAME${RC}"
                    FAILED_MISC+=("$FILE_NAME")
                    exit 1
                }
            fi
        fi
    else
        log "${YELLOW}Linking new $FILE_NAME...${RC}"
        cp -vf "$GIT_FILE_PATH" "$FILE_PATH" || {
            log "ERROR" "${RED}Failed to copy $FILE_NAME${RC}"
            FAILED_MISC+=("$FILE_NAME")
            exit 1
        }
    fi
}

configure_jupyter() {
    log "${YELLOW}Configuring Jupyter...${RC}"
    CONFIG_FILE=~/.jupyter/jupyter_notebook_config.py
    if [ -e "$CONFIG_FILE" ]; then
        read -p "Jupyter config exists. Backup and overwrite? (y/n) " -n 1 -r
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log "${CYAN}Skipping $FILE_NAME backup${RC}"
        else
            jupyter notebook --generate-config
            echo "c.NotebookApp.browser = '/usr/bin/firefox %s'" >> "$CONFIG_FILE" ||
                log "${RED}ERROR: Failed to add Jupyter configuration${RC}" &&
                FAILED_MISC+=("jupyter_configuration")
        fi
    else
        jupyter notebook --generate-config
        echo "c.NotebookApp.browser = '/usr/bin/firefox %s'" >> "$CONFIG_FILE" ||
            log "${RED}ERROR: Failed to add Jupyter configuration${RC}" &&
            FAILED_MISC+=("jupyter_configuration")
    fi
    log "${GREEN}Finished configuring Jupyter.${RC}"
}

configure_git() {
    log "${YELLOW}Configuring global Git settings...${RC}"
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global core.excludesfile ~/.gitignore_global
}

###################
# Handle Failures
###################

handle_failed_installations() {
    log "${YELLOW}Checking for failed installations...${RC}"
    local total_failures=0
    local failed_arrays=()
    for var in "${!FAILED_*}"; do
        failed_arrays+=($var)
    done
    declare -A FAILED
    for array in "${failed_arrays[@]}"; do
        local -n contents=$array
        local -a temp_array=("${contents[@]}")  # Create temp array
        FAILED[$array]=${temp_array[@]}  # Assign temp array to FAILED
        ((total_failures += ${#contents[@]}))
    done
    if ((total_failures == 0)); then
    log "${GREEN}All packages installed successfully.${RC}"
    return
    fi
    log "${RED}Total failures: ${BLUE}$total_failures ${RED}Generating report...${RC}"
    local report_file="$HOME/Desktop/installation_failures_$(date +%Y-%m-%d_%H:%M).txt"
    {
        echo "Installation Failure Report"
        echo "============================"
        echo "Date: $(date)"
        echo "Total failures: $total_failures"
        echo
            for array in "${!FAILED[@]}"; do
                if [ ${#FAILED[$array]} -gt 0 ]; then
                    echo "${array}:"
                    for item in ${FAILED[$array]}; do
                        echo "    $item"
                    done
                fi
            done

    } > "$report_file"
    log "Failure report generated: $report_file"

}

###################
# Main Execution
###################

main() {
    log "Starting main function..."

    # Pre-installation checks
    check_nvidia
    checkEnv

    # Core setup
    update
    check_conda
    installDepend
    installStarshipAndFzf
    installZoxide
    create_fastfetch_config
    for file in "${CONFIG_FILES[@]}"; do
        name="${file%%:*}"
        path="${file##*:}"
        linkConfigFile "$name" "$path"
    done

    # Package installations
    install_packages
    install_pip_on_base_env
    install_conda_packages
    conda update -n base -c defaults conda
    setup_conda_env
    install_deb_rpm_packages
    install_snap_packages
    install_flatpak_packages
#     install_appimages

    # Extra applications
    install_extra_apps
    install_clam_av
    install_ollama

    # Final configurations
    configure_jupyter
    configure_git

    # Handle any failures
    handle_failed_installations

    # Cleanup
    update
    cleanup

    log "${GREEN}Finished main function.${RC}"
}

main "$@"
log "${GREEN}Script finished successfully.${RC}"
echo -e "$(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
mdless POST_INSTALL_INSTRUCTIONS.md




####################
# BUGS AND TODOS
####################



# TODO: $INSTALLED is not being used: handle_failed_installations
# TODO: add $EXPECTED variable to compare to $INSTALLED at the end of the script

# TODO: make bashrc and starship symlinks instead of copies

# TODO: create update function to run before and after package installations. add to cleanup function?

# TODO: setup clamav config, user docs, and cron jobs (seperate script?)

# TODO: sudo snap install android-studio --classic
#   - Configure VM acceleration on Linux: https://developer.android.com/studio/run/emulator-acceleration#vm-linux
#   - sudo apt install google-android-platform-tools-installer

# TODO: add repository function
#   - use `sudo apt install extrepo -y` ??
#   - sudo extrepo enable librewolf

# BUG: flatpaks are installed and can be opened from terminal but do not show in app launcher
#     possible troublshooting step
#     - sudo gtk-update-icon-cache /usr/share/icons/hicolor
#     - sudo kde5-config --path icon
#     - kbuildsycoca5
#     - latpak install --reinstall <package_name>
#     - flatpak run --desktop=<package_name>
#     - Log out and log back in
#     - Ensure Flatpak integration is enabled in System Settings
#     - Check for conflicts with other package managers
#     - Verify application permissions

# TODO: moving appimages to second script. (new script is semi-functional. install_appimages function is currently commented out of this script)
#   - need for more recent versions
#   - updating for better control of process





FAILED(){
    ## dependencies
    ####

    vulkan-sdk                  # Unable to locate package
                                # https://vulkan.lunarg.com/doc/view/latest/linux/getting_started.html
                                # https://vulkan.lunarg.com/sdk/home#linux
                                # https://www.amd.com/en/resources/support-articles/faqs/GPU-646.html
    ## conda scripts
    ####

    ## snap
    ####
    code                        # error: This revision of snap "code" was published using classic confinement
                                #        and thus may perform arbitrary system changes outside of the security
                                #        sandbox that snaps are usually confined to, which may put your system at
                                #        risk.
                                #
                                #        If you understand and want to proceed repeat the command including
                                #        --classic.

    kate                        # error: This revision of snap "kate" was published using classic confinement
                                #        and thus may perform arbitrary system changes outside of the security
                                #        sandbox that snaps are usually confined to, which may put your system at
                                #        risk.
                                #
                                #        If you understand and want to proceed repeat the command including
                                #        --classic.
    gitkraken                   # error: This revision of snap "gitkraken" was published using classic confinement
                                #        and thus may perform arbitrary system changes outside of the security
                                #        sandbox that snaps are usually confined to, which may put your system at
                                #        risk.
                                #
                                #        If you understand and want to proceed repeat the command including
                                #        --classic.
    ## flatpak
    ####
    org.kde.spectacle           # Nothing matches org.kde.spectacle in remote flathub
    zettlr                      # [Downloading Zettlr markdown editor...] -
                                # [Using existing /home/garner/AppImages/zettlr.AppImage] -
                                # [Extracting zettlr AppImage...] -
                                # /home/garner/AppImages/zettlr.AppImage: line 1: syntax error near unexpected token `newline'
                                # /home/garner/AppImages/zettlr.AppImage: line 1: `<!DOCTYPE html>'
                                # [ERROR] - Failed to extract zettlr AppImage
    ## extra_install_scripts
    ####
    DaVinci_Resolve             # system_setup.sh: line 669: .//home/garner/system_setup/extra_install_scripts/DaVinci_Resolve.run: No such file or directory
    FoxitReader                 # system_setup.sh: line 669: .//home/garner/system_setup/extra_install_scripts/FoxitReader.run: No such file or directory


}
