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

# Step 8: Download and configure zomboid.sh
echo "Downloading and configuring zomboid.sh..."
ZOMBOID_SH="/home/$ZOMBOID_USER/zomboid.sh"
if [ ! -f "$ZOMBOID_SH" ]; then
    su - "$ZOMBOID_USER" -c "wget -O $ZOMBOID_SH https://raw.githubusercontent.com/odofad/PZServerScripts/main/zomboid.sh && chmod +x $ZOMBOID_SH"
    
    # Update zomboid.sh configuration
    su - "$ZOMBOID_USER" -c "sed -i 's|STEAM=.*|STEAM=\"$STEAMCMD_DIR\"|' $ZOMBOID_SH"
    su - "$ZOMBOID_USER" -c "sed -i 's|INSTALL=.*|INSTALL=\"$PZSERVER_DIR\"|' $ZOMBOID_SH"
    su - "$ZOMBOID_USER" -c "sed -i 's|DATA=.*|DATA=\"$ZOMBOID_DATA_DIR\"|' $ZOMBOID_SH"
    su - "$ZOMBOID_USER" -c "sed -i 's|IP=.*|IP=\"$LISTEN_IP\"|' $ZOMBOID_SH"
    su - "$ZOMBOID_USER" -c "sed -i 's|ADMINPASS=.*|ADMINPASS=\"$ADMIN_PASSWORD\"|' $ZOMBOID_SH"
else
    echo "zomboid.sh already exists."
fi

# Step 9: Set permissions
echo "Setting permissions..."
chown -R "$ZOMBOID_USER:$ZOMBOID_USER" "$STEAMCMD_DIR" "$PZSERVER_DIR" "$ZOMBOID_DATA_DIR" "$BACKUP_DIR" "$ZOMBOID_SH"
chmod 700 "$ZOMBOID_SH"

# Step 10: Test server start
echo "Testing server start..."
su - "$ZOMBOID_USER" -c "$ZOMBOID_SH start"
sleep 10
su - "$ZOMBOID_USER" -c "$ZOMBOID_SH status"
su - "$ZOMBOID_USER" -c "$ZOMBOID_SH stop"

# Step 11: Instructions
echo "Installation complete!"
echo "To manage the server, use the following as the zomboid user:"
echo "  su - $ZOMBOID_USER"
echo "  cd /home/$ZOMBOID_USER"
echo "  ./zomboid.sh [start|stop|restart|save|status|update|reset]"
echo "Admin password set to: $ADMIN_PASSWORD"
echo "Backup directory: $BACKUP_DIR"
echo "Connect to server at: <your_public_ip>:16261"
echo "Note: Ensure port forwarding for 16261-16262/UDP if hosting locally."
