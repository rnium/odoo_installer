#!/bin/bash

DEFAULT_ADMIN_PASSWORD="admin1234"
DEFAULT_DB_PORT=5432
DEFAULT_DB_PASSWORD="admin"

create_user_group() {
    local user=$1
    local group=$2
    echo "Creating user and group..."
    if ! id -u $user &>/dev/null; then
        sudo useradd -r -s /bin/false $user
    fi
    if ! getent group $group &>/dev/null; then
        sudo groupadd $group
    fi
}

install_system_packages() {
    echo "Installing system packages..."
    sudo apt-get update
    sudo apt install -y python3-pip python3-virtualenv libldap2-dev libpq-dev libsasl2-dev
    sudo apt install -y postgresql
}

clone_repo() {
    echo "Cloning repository..."
    local basedir=$1
    local gh_user=$2
    local repo=$3
    local version=$4
    local owner=$5
    local branch="$version.0"
    local workdir=$basedir/server
    sudo mkdir -p $workdir
    cd $workdir
    sudo git clone https://github.com/$gh_user/$repo.git --depth 1 --branch $branch --single-branch
    sudo mv $repo "$repo-$version"
}

create_venv() {
    echo "Creating virtual environment..."
    local basedir=$1
    local repo=$2
    local version=$3
    local owner=$4
    local all_venv_dir="$basedir/venv"
    local envdir="$all_venv_dir/$repo-$version-env"
    sudo mkdir -p $all_venv_dir
    sudo virtualenv $envdir
    sudo chown -R $owner:$owner $envdir
}

install_requirements() {
    echo "Installing requirements..."
    local basedir=$1
    local repo=$2
    local version=$3
    local owner=$4
    local source_dir="$basedir/server/$repo-$version"
    local envdir="$basedir/venv/$repo-$version-env"
    source $envdir/bin/activate
    pip install -r $source_dir/requirements.txt
    deactivate
}

create_postgres_user() {
    local version="$1"
    local db_user="odoo$version-demouser"
    local db_password=$DEFAULT_DB_PASSWORD

    echo "Creating PostgreSQL user $db_user..."
    
    sudo -u postgres psql -c "CREATE USER \"$db_user\" WITH SUPERUSER LOGIN PASSWORD '$db_password';"
    
    sudo -u postgres psql -c "ALTER USER \"$db_user\" CREATEDB CREATEROLE;"

    echo "PostgreSQL user $db_user created and configured."

    echo "Setting password for the PostgreSQL user $db_user..."
    sudo -u postgres psql -c "ALTER USER \"$db_user\" WITH PASSWORD '$db_password';"
    
    echo "Password set for PostgreSQL user $db_user."
}

create_conf_file() {
    echo "Creating odoo configuration file..."
    local basedir=$1
    local repo=$2
    local version=$3
    local owner=$4
    local conf_dir="$basedir/conf"
    local conf_file="$conf_dir/$repo$version.conf"
    local db_user="$repo$version-demouser"
    sudo mkdir -p $conf_dir
    sudo touch $conf_file
    {
        echo "[options]"
        echo "admin_passwd = $DEFAULT_ADMIN_PASSWORD"
        echo "db_host = localhost"
        echo "db_port = $DEFAULT_DB_PORT"
        echo "db_user = $db_user"
        echo "db_password = $DEFAULT_DB_PASSWORD"
        echo "addons_path = $basedir/server/$repo-$version/addons,$basedir/server/$repo-$version/odoo/addons"
        echo "xmlrpc_port = 80$version"
    } | sudo tee $conf_file > /dev/null
}

create_service_file() {
    local basedir=$1
    local repo=$2
    local version=$3
    local owner=$4
    local source_dir="$basedir/server/$repo-$version"
    local envdir="$basedir/venv/$repo-$version-env"
    local conf_file="$basedir/conf/$repo$version.conf"
    local service_file_name="$repo-$version.service"
    local service_file="/etc/systemd/system/$service_file_name"
    
    # Create log directory with proper permissions
    sudo mkdir -p /var/log/odoo
    sudo chown $owner:$owner /var/log/odoo

    # Create session directory with proper permissions
    sudo mkdir -p /var/lib/odoo
    sudo chown $owner:$owner /var/lib/odoo

    echo "Creating $repo-$version service file..."
    sudo tee $service_file > /dev/null <<EOF
[Unit]
Description=Odoo $version Demo Service
Documentation=https://www.odoo.com
After=postgresql.service

[Service]
Type=simple
User=$owner
Group=$owner
WorkingDirectory=$source_dir
Environment="PATH=$envdir/bin:/usr/bin"
ExecStart=$envdir/bin/python3 $source_dir/odoo-bin -c $conf_file
StandardOutput=append:/var/log/odoo/odoo-$version.log
StandardError=append:/var/log/odoo/odoo-$version.log
Restart=on-failure
RestartSec=5
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

    # Reload and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable $service_file_name
    sudo systemctl start $service_file_name
    echo "Service status:"
    sudo systemctl status $service_file_name
}

print_summary() {
    echo "Installation Summary"
    echo "====================="
    echo "Installed Odoo Version: $version"
    echo "Base Directory: $basedir"
    echo "Default Admin Password: $DEFAULT_ADMIN_PASSWORD"
    echo "To install another version, re-run this script (*/setup.sh) and enter the desired version when prompted."
}

install_odoo_version() {
    local version="$1"
    local basedir="/opt/odoo"
    local repo="odoo"
    local gh_user="odoo"
    local owner="odoo"
    clone_repo $basedir $gh_user $repo $version $owner
    create_venv $basedir $repo $version $owner
    install_requirements $basedir $repo $version $owner
    create_postgres_user $version
    create_conf_file $basedir $repo $version $owner
    create_service_file $basedir $repo $version $owner
    print_summary
}

main() {
    read -p "Enter Odoo version to install (16, 17, or 18): " version
    if [[ "$version" =~ ^(16|17|18)$ ]]; then
        create_user_group odoo odoo
        install_system_packages
        install_odoo_version $version
    else
        echo "Invalid version. Please enter 16, 17, or 18."
        exit 1
    fi
}

main

