#!/bin/bash
# setup_satisfactory.sh
# This script sets up a Satisfactory dedicated server environment.
# It requires root (sudo) privileges to run.
#
# This script has been enhanced to:
#   - Ask whether to use the experimental version of the server.
#   - Warn that for better performance in Proxmox, you should change the CPU type from kvm64 to host.
#
# IMPORTANT:
#   - Ensure your Proxmox VM CPU type is set to "host" (instead of the default "kvm64")
#     for improved single-core performance. This change is made via the Proxmox VM configuration,
#     not within this script.
#
# Adjust the following variables as needed:
INSTALL_DIR="/home/steam/sfserver"

# Prompt the user whether to run the experimental version
echo "Do you want to use the experimental version of the Satisfactory server? (This may provide the missing files)"
read -p "Enter y for yes or n for no [n]: " use_experimental_choice
if [[ "$use_experimental_choice" =~ ^[Yy]$ ]]; then
    USE_EXPERIMENTAL=true
else
    USE_EXPERIMENTAL=false
fi

# Build the beta flag based on the choice.
BETA_FLAG=""
if [ "$USE_EXPERIMENTAL" = true ]; then
  BETA_FLAG="-beta experimental"
  echo "Experimental branch selected."
else
  echo "Stable branch selected."
fi

# Print a note regarding Proxmox CPU settings.
echo "NOTE: For optimal performance, ensure your Proxmox VM is not using the default kvm64 CPU type."
echo "It is recommended to change it to 'host' in the Proxmox VM configuration."
echo "See the Proxmox documentation for details on changing the CPU type."

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if the script is run as root.
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run with sudo or as the root user."
  echo "Usage: sudo ./$0"
  exit 1
fi

echo "---------------------------------------------"
echo "Starting Satisfactory server setup script..."
echo "---------------------------------------------"

#############################################
# 1. Repository and Package Setup
#############################################

echo "Adding the 'multiverse' repository..."
add-apt-repository multiverse -y

echo "Installing software-properties-common..."
apt install software-properties-common -y

echo "Adding i386 architecture support..."
dpkg --add-architecture i386

echo "Updating package lists and upgrading installed packages..."
apt update && apt -y upgrade

echo "Installing lib32gcc-s1..."
apt install lib32gcc-s1 -y

#############################################
# 2. Firewall Configuration
#############################################

echo "Configuring UFW firewall rules..."
FIREWALL_STATUS=$(ufw status | head -n 1)

if echo "$FIREWALL_STATUS" | grep -qi "inactive"; then
  echo "Firewall is inactive. Enabling and adding rules..."
  ufw allow 7777/tcp    # Satisfactory game traffic (TCP)
  ufw allow 7777/udp    # Satisfactory game traffic (UDP)
  ufw allow 22/tcp      # SSH access
  yes | ufw enable
else
  echo "Firewall is active. Ensuring required ports are allowed..."
  ufw allow 7777/tcp
  ufw allow 7777/udp
  ufw allow 22/tcp
fi

echo "Current firewall status:"
ufw status

#############################################
# 3. Steam User Setup
#############################################

echo "Checking if the 'steam' user exists..."
if id "steam" &>/dev/null; then
  echo "User 'steam' already exists. Skipping creation."
else
  echo "Creating user 'steam' with home directory and bash shell..."
  useradd -m -s /bin/bash steam
fi

echo "Adding 'steam' to the sudo group..."
usermod -aG sudo steam

echo "Please set a password for the 'steam' user."
echo "You will be prompted now:"
passwd steam

#############################################
# 4. Install SteamCMD
#############################################

echo "Installing SteamCMD..."
apt-get install -y steamcmd

#############################################
# 5. Create Server Directory and Set Ownership
#############################################

echo "Creating installation directory $INSTALL_DIR and setting ownership..."
sudo -u steam mkdir -p "$INSTALL_DIR"
chown -R steam:steam "$INSTALL_DIR"

#############################################
# 6. Prepare SteamCMD Environment
#############################################

echo "Ensuring the /home/steam/.steam directory exists..."
sudo -u steam mkdir -p /home/steam/.steam

echo "Creating a symbolic link for steamcmd in /home/steam/..."
sudo -u steam ln -sf /usr/games/steamcmd /home/steam/steamcmd

#############################################
# 7. Update Satisfactory Server Files Using SteamCMD
#############################################

echo "Updating Satisfactory Dedicated Server files using SteamCMD..."
sudo -u steam /home/steam/steamcmd +force_install_dir "$INSTALL_DIR" +login anonymous +app_update 1690800 $BETA_FLAG validate +quit

# Verify that the key project file exists.
if [ ! -f "$INSTALL_DIR/FactoryGame/FactoryGame.uproject" ]; then
  echo "WARNING: FactoryGame.uproject not found in $INSTALL_DIR/FactoryGame."
  echo "The server files may not have been installed correctly."
  echo "Suggestions:"
  echo "  - Check your network connection and SteamCMD logs for errors."
  echo "  - Consider using the experimental branch (if not already selected)."
  echo "  - Verify that your disk has sufficient space."
else
  echo "Satisfactory server files installed successfully."
fi

#############################################
# 8. Create the Systemd Service File
#############################################

SERVICE_FILE="/etc/systemd/system/satisfactory.service"
echo "Creating systemd service file at ${SERVICE_FILE}..."

cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Satisfactory dedicated server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Environment="LD_LIBRARY_PATH=./linux64"
# The ExecStartPre command updates the server files.
ExecStartPre=/home/steam/steamcmd +force_install_dir "$INSTALL_DIR" +login anonymous +app_update 1690800 $BETA_FLAG validate +quit
ExecStart=/bin/sh "$INSTALL_DIR/FactoryServer.sh"
User=steam
Group=steam
StandardOutput=append:/var/log/satisfactory.log
StandardError=append:/var/log/satisfactory.err
Restart=on-failure
WorkingDirectory=$INSTALL_DIR
TimeoutSec=240

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon to recognize the new service..."
systemctl daemon-reload

echo "Enabling the Satisfactory server service to start on boot..."
systemctl enable satisfactory

echo "Starting the Satisfactory server service..."
systemctl start satisfactory

echo "------------------------------------------------------"
echo "Satisfactory server service status:"
systemctl status satisfactory.service --no-pager
echo "------------------------------------------------------"

echo "Setup complete!"
echo "To monitor the server log in real time, run:"
echo "   tail -n3 -f /var/log/satisfactory.log"
