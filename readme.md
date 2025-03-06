# Odoo Auto-Installer Script

This repository contains a Bash script that automates the installation of multiple Odoo versions (16, 17, and 18). It sets up users, installs dependencies, configures PostgreSQL, and creates systemd services for each version.

## Features
- Creates a system user and group for Odoo
- Installs necessary system packages
- Clones the Odoo repository for versions 16, 17, and 18
- Creates virtual environments and installs dependencies
- Sets up PostgreSQL users for Odoo
- Configures Odoo settings and systemd services

## Prerequisites
Ensure you have the following installed on your system:
- Git
- Bash
- PostgreSQL
- `sudo` privileges

## Installation & Execution
Run the following command in your terminal to clone the repository, make the script executable, and execute it in a single step:

```bash
repo_url="https://github.com/rnium/odoo_installer" && git clone "$repo_url" && cd "$(basename "$repo_url")" && chmod +x setup.sh && sudo ./setup.sh
```

Replace `https://github.com/rnium/odoo_installer` with the actual repository URL.

## License
This project is licensed under the MIT License.

## Author
Md Saiful Islam Rony
