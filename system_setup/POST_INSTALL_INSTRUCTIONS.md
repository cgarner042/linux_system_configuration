# Post-installation Instructions

## NVIDIA Persistence and Hybrid Sleep

See nvidia-persistence-setup.md in the system_setup directory

## Sleep settings

Nvidia persistence may not work. If so, please set the system to not sleep or hybernate. require password and screen off should be fine

## Set Terminal Font

Press Ctrl + Shift + , (comma) to adjust the font in Konsole.

Right click -> properties in Gnome Terminal

## Import KWin Rules

Import your custom KWin rules for personalized window management.

## Set default utilities and aplications

Set in settings on KDE or right click a file of each type for properties in Gnome

1. .md files
    - Okular
    - **Typora**
    - mdless
    - marktext
    - zettler
    - glow
    
2. screenshot utility
    - spectacle
    - flameshot

3. browser (I like to set a browser that is not my primary browser as default to allow for a second windowwhen opening something)
    - librewolf <default>
    - firefox
    - chrome
    - vivaldi
    - opera <primary>

4. text editor / IDE
    - kate
    - codium
## Pin AI Apps to Browser

Pin Perplexity, Meta AI, Claude, and ChatGPT to your browser for easy access.

## Git Credential Helper

- Run `git config --global credential.helper store` to enable credential caching.
- pull repos to set credentials

## Manual Installation for Unsupported Apps

Run the following commands to install additional apps:

* VSCode: <insert installation command here>
* kate: <insert installation commands here>
* gitkraken: <>
* codium: <sudo snap install codium --classic>

## Extra install scripts

please view the extra_install_scripts folder to see if they have been install or need to be run manually

## AppImages

Run AppImage script to extract and install appimages

(Script is broken at this time)

(Some of these may be available as Flatpaks)

- Cura
- Typora
- Joplin
- Obsidian
- Zettler

## Backup and synch

The backup_and_synch.sh script is not currently finished but setting up a backup system is a good practice

