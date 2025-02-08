#!/bin/bash
# setup_satisfactory.sh
# This script sets up a Satisfactory dedicated server environment.
# It requires root (sudo) privileges to run.

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

echo "Installing lib32gcc1..."
apt install lib32gcc1 -y

#############################################
# 2. Firewall Configuration
#############################################

echo "Checking UFW firewall status..."
FIREWALL_STATUS=$(ufw status | head -n 1)

if echo "$FIREWALL_STATUS" | grep -qi "inactive"; then
  echo "Firewall is inactive. Configuring and enabling firewall..."
  ufw allow 15777   # Port for Satisfactory
  ufw allow 22      # SSH port
  # The following command automatically answers "yes" to the enable prompt.
  yes | ufw enable
else
  echo "Firewall is active. Ensuring required ports are allowed..."
  ufw allow 15777
  ufw allow 22
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
# 4. Install steamcmd
#############################################

echo "Installing steamcmd..."
apt-get install -y steamcmd

#############################################
# 5. Configure Satisfactory Dedicated Server Service
#############################################

# Create a symbolic link for steamcmd in steam's home directory.
echo "Creating a symbolic link for steamcmd in /home/steam/..."
sudo -u steam ln -sf /usr/games/steamcmd /home/steam/steamcmd

# Create the systemd service file.
SERVICE_FILE="/etc/systemd/system/satisfactory.service"
echo "Creating systemd service file at ${SERVICE_FILE}..."
cat << 'EOF' > "$SERVICE_FILE"
[Unit]
Description=Satisfactory dedicated server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Environment="LD_LIBRARY_PATH=./linux64"
# The ExecStartPre command installs or updates the server.
ExecStartPre=/home/steam/steamcmd +force_install_dir "/home/steam/sfserver" +login anonymous +app_update 1690800 validate +quit
ExecStart=/home/steam/sfserver/FactoryServer.sh
User=steam
Group=steam
StandardOutput=append:/var/log/satisfactory.log
StandardError=append:/var/log/satisfactory.err
Restart=on-failure
WorkingDirectory=/home/steam/sfserver
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
echo "To monitor the server log in real-time, you can run:"
echo "   tail -n3 -f /var/log/satisfactory.log"
