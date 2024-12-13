#!/bin/bash

LOG_FILE="$HOME/Desktop/appimage.log"

log() {
    local level="$1"
    local message="$2"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [$level] - $message" | tee -a "$LOG_FILE"
}

# AppImage configurations
declare -A APPIMAGE_CONFIGS
APPIMAGE_CONFIGS=(
    ["cura"]="https://github.com/Ultimaker/Cura/releases/download/5.7.2-RC2/UltiMaker-Cura-5.7.2-linux-X64.AppImage|Ultimaker Cura|cura-icon.png|Graphics"
    ["krita"]="https://download.kde.org/stable/krita/5.1.5/krita-5.1.5-x86_64.appimage|Krita|krita.png|Graphics"
)

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

install_appimages
