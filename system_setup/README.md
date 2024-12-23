# Linux System Configuration

An automated system configuration script for Linux that installs and configures development tools, applications, and environments.

## Directory Structure
```
system_setup/
├── conda_env/               # Conda environment configurations
├── extra_install_scripts/   # Additional installation scripts
├── kwin_rules/             # KDE window management rules
├── backup_and_sync.sh      # Backup utility script
├── config.jsonc            # Fastfetch configuration file
├── POST_INSTALL_INSTRUCTIONS.md
├── system_setup.sh         # Main setup script
└── starship.toml          # Starship prompt configuration
```

## Prerequisites

- A Linux distribution with one of these package managers:
  - nala/apt (Debian/Ubuntu)
  - dnf (Fedora)
  - zypper (openSUSE)
- sudo/doas privileges
- curl
- Basic command line tools

## Features

- Package management (apt/dnf/zypper)
- Development environments:
  - Python with Anaconda
  - Various pip packages
  - Code editors and IDEs
- System utilities:
  - ClamAV antivirus
  - Backup tools
  - System monitoring
- Media applications:
  - Video editing (DaVinci Resolve)
  - Image editing
  - Media playback
- Productivity tools:
  - Document readers
  - Note-taking applications
  - Office tools

## Installation

1. Clone the repository:
```bash
git clone [repository-url]
cd system_setup
```

2. Add any .run scripts to `extra_install_scripts` and re-name them to reflect the command that will be used to launch the program once installed

3. Add any .yaml files to `conda_env` for anaconda environment creation

4. Make the script executable:
```bash
chmod +x system_setup.sh
```

5. Run the setup script:
```bash
./system_setup.sh
```

## Post-Installation

Review POST_INSTALL_INSTRUCTIONS.md for additional setup steps and configurations.

## Configuration

The script uses several configuration files:
- `config.jsonc`: FastFetch configuration
- `starship.toml`: Terminal prompt configuration
- Conda environment files in `conda_env/`

## Troubleshooting

The script generates logs in:
- `~/Desktop/setup_terminal_output.log`: General setup log
- `~/Desktop/linux_set_up.log`: Detailed operation log
- `~/Desktop/installation_failures_[date].txt`: Failed installations report

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

