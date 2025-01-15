#!/bin/sh -x
exec > >(tee $HOME/Desktop/appimage_output.log) 2>&1
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

###################
# Logging & Debugging
###################

LOG_FILE="$HOME/Desktop/appimage.log"

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
