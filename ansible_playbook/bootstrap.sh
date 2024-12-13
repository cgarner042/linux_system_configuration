#!/bin/bash

###################
# Logging & Debugging
###################

LOG_FILE="$HOME/Desktop/bootstrap.log"

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

# Anaconda version to install
ANACONDA_VERSION="2023.09-0"

###################
# Script Functions
###################

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

###################
# Execution
###################

main() {
    log "INFO" "Starting main function..."
    echo "Checking for Conda"
    if command_exists conda; then
        log "Anaconda is already installed."
    else
        echo "installing Anaconda"
        install_anaconda
        # restart script from beginning (allows for the conda and pip commands to be used in the script)
        exec bash "$(dirname "$0")"
    fi
    pip install ansible
    ansible-galaxy collection install community.general
}

main "$@"
echo "Please start a new shell to enable conda"