#!/bin/sh -x

###################
# Initialize variables
###################

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'

SRC_DIR="/"
DST_DIR=""
PACKAGER=""
SUDO_CMD=""
SUGROUP=""

###################
# Logging & Debugging
###################

LOG_FILE="$HOME/Desktop/linux_set_up.log"

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

cleanup() {
    log "Performing cleanup..."
    # Remove temporary files
    rm -rf /tmp/setup_* 2>/dev/null
    # Cleanup package manager caches if needed
    if [ -n "$PACKAGER" ]; then
        case $PACKAGER in
            apt|nala)
                ${SUDO_CMD} apt-get clean
                ;;
            dnf|yum)
                ${SUDO_CMD} dnf clean all
                ;;
            pacman)
                ${SUDO_CMD} pacman -Scc --noconfirm
                ;;
        esac
    fi
}

###################
# Configuration
###################

BACKUP_DRIVE_NAME="Dual_boot_share"

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
    PACKAGEMANAGER='nala apt dnf yum pacman zypper emerge xbps-install nix-env'
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

    ## Check AUR helper
    if [ "$PACKAGER" = "pacman" ]; then
        AUR_HELPER='yay paru'
        for aur in $AUR_HELPER; do
            if command_exists "$aur"; then
                PACKAGER="$aur"
                break
            fi
        done
        if [ -z "$PACKAGER" ]; then
            echo "Installing yay as AUR helper..."
            ${SUDO_CMD} pacman --noconfirm -S base-devel
            cd /opt && ${SUDO_CMD} git clone https://aur.archlinux.org/yay-git.git && ${SUDO_CMD} chown -R "${USER}:${USER}" ./yay-git
            cd yay-git && makepkg --noconfirm -si
            PACKAGER="yay"
        fi
    fi

    ## Set install command and flags
    case $PACKAGER in
        yay|paru) INSTALL="-S --noconfirm";;
        pacman) INSTALL="-Syu --noconfirm";;
        apt|nala) INSTALL="install -y";;
        dnf|yum) INSTALL="install -y";;
        xbps-install) INSTALL="-v";;
        zypper) INSTALL="install -n";;
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

###################
# Backup Functions
###################

setup_backup() {
    local xdg_dirs=(
        "$HOME/.config"
        "$HOME/.local/share"
        "$HOME/Documents"
        "$HOME/Pictures"
        "$HOME/Videos"
        "$HOME/Music"
        "$HOME/Downloads"
        "$HOME/Desktop"
        "$HOME/3d_models"
        "$HOME/ai_models"
        "$HOME/code"
        "$HOME/iso_files"
    )

    DST_DRIVE=$(blkid -L ${BACKUP_DRIVE_NAME} 2>/dev/null)
    if [ -z "$DST_DRIVE" ]; then
        log "ERROR" "${RED}Drive labeled '${BACKUP_DRIVE_NAME}' not found.${RC}"
        return 1
    fi

    DST_DIR="${DST_DRIVE}/backup"

    # Check available space on backup drive
    local backup_space=$(df -k "$DST_DRIVE" | awk 'NR==2 {print $4}')
    local source_size=$(du -sk "${xdg_dirs[@]}" 2>/dev/null | awk '{sum+=$1} END {print sum}')

    if [ "$backup_space" -lt "$source_size" ]; then
        log "ERROR" "${RED}Insufficient space on backup drive${RC}"
        return 1
    fi

    # Create backup directory structure
    ${SUDO_CMD} mkdir -p "$DST_DIR"

    # Setup real-time syncing for XDG directories
    for dir in "${xdg_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log "Setting up backup for $dir"
            ${SUDO_CMD} rsync -av --delete "$dir/" "$DST_DIR/$(basename "$dir")/"
            echo "$dir/ IN_MODIFY,IN_CREATE,IN_DELETE ${SUDO_CMD} rsync -av --delete $dir/ $DST_DIR/$(basename "$dir")/" | ${SUDO_CMD} tee -a /etc/incron.d/backup
        fi
    done

    # Restart incron daemon
    ${SUDO_CMD} systemctl restart incron || ${SUDO_CMD} service incron restart
}

###################
# Main Execution
###################

main() {
    log "Starting main function..."

    checkEnv
    setup_backup
    handle_failed_installations
    cleanup

    log "Finished main function."
}


main "$@"
log "Script finished successfully."
echo -e "$(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"

####################
# BUGS AND TODOS
####################

# TODO: this is justa rough draft

# TODO: add folders from import drive to places/bookmarks in dolphin/nautilus (example: add code, 3d_models, ai_models, and iso_files to sidebar)

