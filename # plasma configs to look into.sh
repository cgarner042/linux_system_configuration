# plasma configs to look into
plasma-apply-colorscheme BreezeDark
kwriteconfig5 --file ~/.config/systemsettingsrc --group Main --key ActiveView systemsettings_sidebar_mode
kwriteconfig5 --file ~/.config/systemsettingsrc --group systemsettings_sidebar_mode --key HighlightNonDefaultSettings true### Dolphin
kwriteconfig5 --file ~/.config/dolphinrc --group General --key ShowFullPath true
kwriteconfig5 --file ~/.config/dolphinrc --group General --key CloseActiveSplitView true
kwriteconfig5 --file ~/.config/dolphinrc --group General --key UseTabForSwitchingSplitView true
kwriteconfig5 --file ~/.config/dolphinrc --group General --key RememberOpenedTabs false
kwriteconfig5 --file ~/.config/dolphinrc --group General --key OpenExternallyCalledFolderInNewTab false
### KWin
# Quarter Tile hitbox 10% of screen height
kwriteconfig5 --file ~/.config/kwinrc --group Windows --key ElectricBorderCornerRatio 0.1
# AltTab
kwriteconfig5 --file ~/.config/kwinrc --group TabBox --key LayoutName thumbnail_grid
# Virtual Desktops
kwriteconfig5 --file ~/.config/kwinrc --group Desktops --key Rows 1
kwriteconfig5 --file ~/.config/kwinrc --group Desktops --key Number 5
qdbus org.kde.KWin /KWin reconfigure
# Shortcuts: Meta+Up/Down to Maximize/Minimize
kwriteconfig5 --file ~/.config/kglobalshortcutsrc --group kwin --key "Window Quick Tile Bottom" "none,Meta+Down,Quick Tile Window to the Bottom"
kwriteconfig5 --file ~/.config/kglobalshortcutsrc --group kwin --key "Window Quick Tile Top" "none,Meta+Up,Quick Tile Window to the Top"
kwriteconfig5 --file ~/.config/kglobalshortcutsrc --group kwin --key "Window Maximize" "Meta+PgUp	Meta+Up,Meta+PgUp,Maximize Window"
kwriteconfig5 --file ~/.config/kglobalshortcutsrc --group kwin --key "Window Minimize" "Meta+PgDown	Meta+Down,Meta+PgDown,Minimize Window"
# Shortcuts: Disable Ctrl+F1 to switch to desktop 1
kwriteconfig5 --file ~/.config/kglobalshortcutsrc --group kwin --key "Switch to Desktop 1" "none,Ctrl+F1,Switch to Desktop 1"
kwriteconfig5 --file ~/.config/kglobalshortcutsrc --group kwin --key "Switch to Desktop 2" "none,Ctrl+F2,Switch to Desktop 2"
kwriteconfig5 --file ~/.config/kglobalshortcutsrc --group kwin --key "Switch to Desktop 3" "none,Ctrl+F3,Switch to Desktop 3"
kwriteconfig5 --file ~/.config/kglobalshortcutsrc --group kwin --key "Switch to Desktop 4" "none,Ctrl+F4,Switch to Desktop 4"
# Shortcuts: Ctrl+Alt+Left/Right to switch to next/prev desktop
kwriteconfig5 --file ~/.config/kglobalshortcutsrc --group kwin --key "Switch to Next Desktop" "Ctrl+Alt+Right,none,Switch to Next Desktop"
kwriteconfig5 --file ~/.config/kglobalshortcutsrc --group kwin --key "Switch to Previous Desktop" "Ctrl+Alt+Left,none,Switch to Previous Desktop"
# Shortcuts: Meta+M to Show Desktop
kwriteconfig5 --file ~/.config/kglobalshortcutsrc --group kwin --key "Show Desktop" "Meta+D	Meta+M,Meta+D,Show Desktop"
### Plasma
# plasmasetconfig.py
# https://gist.github.com/Zren/764f17c26be4ea0e088f4a6a1871f528
git clone https://gist.github.com/Zren/764f17c26be4ea0e088f4a6a1871f528 plasmasetconfig
chmod +x ./plasmasetconfig/plasmasetconfig.py
sudo cp ./plasmasetconfig/plasmasetconfig.py /usr/local/bin/plasmasetconfig
rm -r ./plasmasetconfig
# Task Manager / Icon Tasks
plasmasetconfig org.kde.plasma.taskmanager General groupingStrategy 0 # Do Not Group
plasmasetconfig org.kde.plasma.taskmanager General separateLaunchers false
plasmasetconfig org.kde.plasma.taskmanager General middleClickAction 1 # Close
plasmasetconfig org.kde.plasma.taskmanager General indicateAudioStreams false
plasmasetconfig org.kde.plasma.icontasks General groupingStrategy 0 # Do Not Group
plasmasetconfig org.kde.plasma.icontasks General separateLaunchers false
plasmasetconfig org.kde.plasma.icontasks General middleClickAction 1 # Close
plasmasetconfig org.kde.plasma.icontasks General indicateAudioStreams false
# Digital Clock
plasmasetconfig org.kde.plasma.digitalclock Appearance dateFormat custom
plasmasetconfig org.kde.plasma.digitalclock Appearance customDateFormat "ddd d" # Sun 31
# Virtual Desktop Pager
plasmasetconfig org.kde.plasma.pager General showWindowIcons true
# System Tray
# TODO: Since this is a list, we need to append/remove elements from the list, so we should write a Plasma Script.
plasmasetconfig org.kde.plasma.private.systemtray General hiddenItems "org.kde.plasma.networkmanagement,org.kde.plasma.mediacontroller"
# https://gist.github.com/Zren/764f17c26be4ea0e088f4a6a1871f528
# https://develop.kde.org/docs/plasma/scripting/
# https://develop.kde.org/docs/plasma/scripting/api/#panels
# https://github.com/shalva97/kde-configuration-files/blob/master/scripts/plasmasetconfig.py
# https://github.com/shalva97/kde-configuration-files
# https://linuxcommandlibrary.com/man/kwriteconfig5