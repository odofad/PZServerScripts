#!/bin/bash

# Project Zomboid Server Install Script for Ubuntu
# Run as root or with sudo
# Requires zomboid.sh (and other scripts) in the same directory as this script

# Exit on error
set -e

# Configuration variables
ZOMBOID_USER="zomboid"
STEAMCMD_DIR="/home/$ZOMBOID_USER/steamcmd"
PZSERVER_DIR="/home/$ZOMBOID_USER/pzserver"
ZOMBOID_DATA_DIR="/home/$ZOMBOID_USER/Zomboid"
BACKUP_DIR="/home/$ZOMBOID_USER/backups"
SERVER_NAME="MyZomboidServer"
ADMIN_PASSWORD="youradminpassword"  # Change to a secure password
LISTEN_IP="0.0.0.0"

# Get the directory of this script
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)."
    exit 1
fi

# Step 1: Check for local zomboid.sh
echo "Checking for local zomboid.sh..."
if [ ! -f "$SCRIPT_DIR/zomboid.sh" ]; then
    echo "Error: zomboid.sh not found in $SCRIPT_DIR. Please place it there and rerun."
    exit 1
else
    echo "Found zomboid.sh in $SCRIPT_DIR."
fi

# Step 2: Update system
echo "Updating system..."
apt update && apt upgrade -y

# Step 3: Install dependencies
echo "Installing dependencies..."
apt install -y lib32gcc-s1 lib32stdc++6 steamcmd screen wget nano ufw

# Step 4: Create zomboid user
if ! id "$ZOMBOID_USER" >/dev/null 2>&1; then
    echo "Creating user $ZOMBOID_USER..."
    adduser --gecos "" --disabled-password "$ZOMBOID_USER"
    echo "$ZOMBOID_USER:$ZOMBOID_USER" | chpasswd
else
    echo "User $ZOMBOID_USER already exists."
fi

# Step 5: Install SteamCMD
echo "Installing SteamCMD..."
if [ ! -d "$STEAMCMD_DIR" ]; then
    su - "$ZOMBOID_USER" -c "mkdir -p $STEAMCMD_DIR && cd $STEAMCMD_DIR && wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz && tar -xvzf steamcmd_linux.tar.gz && rm steamcmd_linux.tar.gz"
else
    echo "SteamCMD directory already exists."
fi

# Step 6: Install Project Zomboid server
echo "Installing Project Zomboid server..."
if [ ! -d "$PZSERVER_DIR" ]; then
    su - "$ZOMBOID_USER" -c "$STEAMCMD_DIR/steamcmd.sh +force_install_dir $PZSERVER_DIR +login anonymous +app_update 380870 validate +quit"
else
    echo "Project Zomboid server directory already exists."
fi

# Step 7: Create data and backup directories
echo "Setting up data and backup directories..."
su - "$ZOMBOID_USER" -c "mkdir -p $ZOMBOID_DATA_DIR $BACKUP_DIR"

# Step 8: Configure firewall
echo "Configuring firewall..."
ufw allow 16261/udp
ufw allow 16262/udp
ufw reload
echo "Firewall configured for ports 16261-16262/UDP."

# Step 9: Copy and configure scripts
echo "Copying and configuring scripts..."
ZOMBOID_SH="/home/$ZOMBOID_USER/zomboid.sh"
# Copy zomboid.sh
cp "$SCRIPT_DIR/zomboid.sh" "$ZOMBOID_SH"
# Copy any other .sh scripts in the same directory
for script in "$SCRIPT_DIR"/*.sh; do
    if [ "$script" != "$SCRIPT_DIR/install_pzserver.sh" ] && [ "$script" != "$SCRIPT_DIR/zomboid.sh" ]; then
        cp "$script" "/home/$ZOMBOID_USER/"
        echo "Copied $(basename "$script") to /home/$ZOMBOID_USER/"
    fi
done

# Configure zomboid.sh
echo "Configuring zomboid.sh..."
su - "$ZOMBOID_USER" -c "sed -i 's|STEAM=.*|STEAM=\"$STEAMCMD_DIR\"|' $ZOMBOID_SH || true"
su - "$ZOMBOID_USER" -c "sed -i 's|INSTALL=.*|INSTALL=\"$PZSERVER_DIR\"|' $ZOMBOID_SH || true"
su - "$ZOMBOID_USER" -c "sed -i 's|DATA=.*|DATA=\"$ZOMBOID_DATA_DIR\"|' $ZOMBOID_SH || true"
su - "$ZOMBOID_USER" -c "sed -i 's|IP=.*|IP=\"$LISTEN_IP\"|' $ZOMBOID_SH || true"
su - "$ZOMBOID_USER" -c "sed -i 's|ADMINPASS=.*|ADMINPASS=\"$ADMIN_PASSWORD\"|' $ZOMBOID_SH || true"
su - "$ZOMBOID_USER" -c "chmod +x $ZOMBOID_SH"

# Set permissions for other scripts
for script in /home/$ZOMBOID_USER/*.sh; do
    chown "$ZOMBOID_USER:$ZOMBOID_USER" "$script"
    chmod 700 "$script"
done

# Step 10: Set permissions for directories
echo "Setting directory permissions..."
chown -R "$ZOMBOID_USER:$ZOMBOID_USER" "$STEAMCMD_DIR" "$PZSERVER_DIR" "$ZOMBOID_DATA_DIR" "$BACKUP_DIR"

# Step 11: Test server start
echo "Testing server start..."
su - "$ZOMBOID_USER" -c "$ZOMBOID_SH start"
sleep 10
su - "$ZOMBOID_USER" -c "$ZOMBOID_SH status"
su - "$ZOMBOID_USER" -c "$ZOMBOID_SH stop"

# Step 12: Instructions
echo "Installation complete!"
echo "To manage the server, use the following as the zomboid user:"
echo "  su - $ZOMBOID_USER"
echo "  cd /home/$ZOMBOID_USER"
echo "  ./zomboid.sh [start|stop|restart|save|status|update|reset]"
echo "Other scripts copied: $(ls /home/$ZOMBOID_USER/*.sh 2>/dev/null | grep -v zomboid.sh | grep -v install_pzserver.sh || echo 'None')"
echo "Admin password set to: $ADMIN_PASSWORD"
echo "Backup directory: $BACKUP_DIR"
echo "Connect to server at: <your_public_ip>:16261"
echo "Note: Ensure port forwarding for 16261-16262/UDP if hosting locally."
