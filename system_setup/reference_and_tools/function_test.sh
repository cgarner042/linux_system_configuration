#!/bin/sh -x

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
            echo "Using $pgm"
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

    echo "Using $SUDO_CMD as privilege escalation software"

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
            echo "Super user group $SUGROUP"
            break
        fi
    done

    ## Check if member of the sudo group.
    if ! groups | grep --quiet "$SUGROUP"; then
        echo "${RED}You need to be a member of the sudo group to run me!${RC}"
        exit 1
    fi
}

print_variables(){
    echo "${SUDO_CMD} ${PACKAGER} ${INSTALL} ${DEPENDENCIES}"
}

clam_av(){
    case $PACKAGER in
        yay|paru) CLAM="";;
        pacman) CLAM="";;
        apt|nala) CLAM="clamav clamav-daemon";;
        dnf|yum) CLAM="clamav clamd clamav-update";;
        zypper) CLAM="clamav";;
    esac

    if [[ "$PACKAGER" == "dnf" ]] || [[ "$PACKAGER" == "yum" ]]; then
        echo ${SUDO_CMD} ${PACKAGER} ${INSTALL} epel-release
        echo ${SUDO_CMD} ${PACKAGER} ${INSTALL} ${CLAM}
    else
        echo ${SUDO_CMD} ${PACKAGER} ${INSTALL} ${CLAM}
    fi

    echo ${SUDO_CMD} systemctl stop clamav-freshclam
    echo ${SUDO_CMD} freshclam
    echo ${SUDO_CMD} systemctl start clamav-freshclam
}


main(){
    checkEnv
    print_variables
    clam_av
}

main "$@"
