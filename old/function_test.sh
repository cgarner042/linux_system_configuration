
# URLs for .deb files
declare -A DEB_URLS
DEB_URLS=(
    ["google-chrome"]="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    ["mailspring"]="https://updates.getmailspring.com/download?platform=linuxDeb"
    ["marktext"]="https://github.com/marktext/marktext/releases/latest/download/marktext-amd64.deb"
)

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