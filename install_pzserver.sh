#!/bin/bash

# Project Zomboid Server Install Script for Ubuntu
# Run as root or with sudo

# Exit on error
set -e

# Configuration variables
ZOMBOID_USER="zomboid"
STEAMCMD_DIR="/home/$ZOMBOID_USER/steamcmd"
PZSERVER_DIR="/home/$ZOMBOID_USER/pzserver"
ZOMBOID_DATA_DIR="/home/$ZOMBOID_USER/Zomboid"
BACKUP_DIR="/home/$ZOMBOID_USER/backups"
SERVER_NAME="MyZomboidServer"
ADMIN_PASSWORD="youradminpassword"  # Change this to your desired password
LISTEN_IP="0.0.0.0"

# Get the directory of this script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)."
    exit 1
fi

# Step 1: Update system
echo "Updating system..."
apt update && apt upgrade -y

# Step 2: Install dependencies
echo "Installing dependencies..."
apt install -y lib32gcc-s1 lib32stdc++6 steamcmd screen wget nano ufw

# Step 3: Create zomboid user
if ! id "$ZOMBOID_USER" >/dev/null 2>&1; then
    echo "Creating user $ZOMBOID_USER..."
    adduser --gecos "" --disabled-password "$ZOMBOID_USER"
    echo "$ZOMBOID_USER:$ZOMBOID_USER" | chpasswd  # Set password to 'zomboid' (change if needed)
else
    echo "User $ZOMBOID_USER already exists."
fi

# Step 4: Install SteamCMD
echo "Installing SteamCMD..."
if [ ! -d "$STEAMCMD_DIR" ]; then
    su - "$ZOMBOID_USER" -c "mkdir -p $STEAMCMD_DIR && cd $STEAMCMD_DIR && wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz && tar -xvzf steamcmd_linux.tar.gz && rm steamcmd_linux.tar.gz"
else
    echo "SteamCMD directory already exists."
fi

# Step 5: Install Project Zomboid server
echo "Installing Project Zomboid server..."
if [ ! -d "$PZSERVER_DIR" ]; then
    su - "$ZOMBOID_USER" -c "$STEAMCMD_DIR/steamcmd.sh +force_install_dir $PZSERVER_DIR +login anonymous +app_update 380870 validate +quit"
else
    echo "Project Zomboid server directory already exists."
fi

# Step 6: Create data and backup directories
echo "Setting up data and backup directories..."
su - "$ZOMBOID_USER" -c "mkdir -p $ZOMBOID_DATA_DIR $BACKUP_DIR"

# Step 7: Configure firewall
echo "Configuring firewall..."
ufw allow 16261/udp
ufw allow 16262/udp
ufw reload
echo "Firewall configured for ports 16261-16262/UDP."

# Step 8: Copy and configure provided scripts
echo "Copying provided scripts from $SCRIPT_DIR..."
for script in backup.sh cron_shutdown.sh cron_update.sh server-restart.sh server-stop.sh cron_monitor.sh cron_startup.sh server-start.sh server-update.sh; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        cp "$SCRIPT_DIR/$script" "/home/$ZOMBOID_USER/"
        echo "Copied $script to /home/$ZOMBOID_USER/"
    else
        echo "Warning: $script not found in $SCRIPT_DIR"
    fi
done

# Copy additional files: includes and readme.md
if [ -e "$SCRIPT_DIR/includes" ]; then
    cp -r "$SCRIPT_DIR/includes" "/home/$ZOMBOID_USER/"
    echo "Copied includes to /home/$ZOMBOID_USER/"
else
    echo "Warning: includes not found in $SCRIPT_DIR"
fi
if [ -f "$SCRIPT_DIR/readme.md" ]; then
    cp "$SCRIPT_DIR/readme.md" "/home/$ZOMBOID_USER/"
    echo "Copied readme.md to /home/$ZOMBOID_USER/"
else
    echo "Warning: readme.md not found in $SCRIPT_DIR"
fi

# Configure scripts with variables
echo "Configuring scripts..."
for script in /home/$ZOMBOID_USER/*.sh; do
    if [ -f "$script" ]; then
        sed -i "s|STEAM=.*|STEAM=\"$STEAMCMD_DIR\"|" "$script"
        sed -i "s|INSTALL=.*|INSTALL=\"$PZSERVER_DIR\"|" "$script"
        sed -i "s|DATA=.*|DATA=\"$ZOMBOID_DATA_DIR\"|" "$script"
        sed -i "s|IP=.*|IP=\"$LISTEN_IP\"|" "$script"
        sed -i "s|ADMINPASS=.*|ADMINPASS=\"$ADMIN_PASSWORD\"|" "$script"
    fi
done

# Step 9: Set permissions
echo "Setting permissions..."
chown -R "$ZOMBOID_USER:$ZOMBOID_USER" "/home/$ZOMBOID_USER"
chmod -R 700 "/home/$ZOMBOID_USER"/*.sh
if [ -d "/home/$ZOMBOID_USER/includes" ]; then
    chmod -R 700 "/home/$ZOMBOID_USER/includes"
fi

# Step 10: Test server start
echo "Testing server start..."
if [ -f "/home/$ZOMBOID_USER/server-start.sh" ]; then
    su - "$ZOMBOID_USER" -c "/home/$ZOMBOID_USER/server-start.sh"
    sleep 10
    if [ -f "/home/$ZOMBOID_USER/server-stop.sh" ]; then
        su - "$ZOMBOID_USER" -c "/home/$ZOMBOID_USER/server-stop.sh"
    else
        echo "Warning: server-stop.sh not found, cannot stop server."
    fi
else
    echo "Warning: server-start.sh not found, skipping test."
fi

# Step 11: Instructions
echo "Installation complete!"
echo "To manage the server, use the following as the zomboid user:"
echo "  su - $ZOMBOID_USER"
echo "  cd /home/$ZOMBOID_USER"
echo "Available scripts:"
for script in /home/$ZOMBOID_USER/*.sh; do
    if [ -f "$script" ]; then
        echo "  ./$(basename "$script")"
    fi
done
echo "Admin password set to: $ADMIN_PASSWORD"
echo "Backup directory: $BACKUP_DIR"
echo "Connect to server at: <your_public_ip>:16261"
echo "Note: Ensure port forwarding for 16261-16262/UDP if hosting locally."
echo "Please verify the functionality of the provided scripts and consult readme.md if available."
