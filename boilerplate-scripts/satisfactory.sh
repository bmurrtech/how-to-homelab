#!/bin/bash
# satisfactory.sh
# This script sets up a Satisfactory dedicated server environment.
# It requires root (sudo) privileges to run.
#
# Enhancements in this version:
#   - Ask whether to use the experimental branch.
#   - Remind the user to change the Proxmox VM CPU type from "kvm64" to "host".
#   - Interactive firewall configuration:
#       (1) Selfhosted LAN Party: Allow only LAN (192.168.1.0/24) IPs on ports 22 and 7777 (both TCP and UDP).
#       (2) VPS-Hosted with Trusted IP Access: Prompt for a trusted SSH IP and whitelist additional player IPs via a file.
#
# Adjust these variables as needed:
INSTALL_DIR="/home/steam/sfserver"

#############################################
# 0. Preliminary Prompts and CPU Note
#############################################

# Prompt for experimental branch
echo "Do you want to use the experimental version of the Satisfactory server? (This may provide missing files)"
read -p "Enter y for yes or n for no [n]: " use_experimental_choice
if [[ "$use_experimental_choice" =~ ^[Yy]$ ]]; then
    USE_EXPERIMENTAL=true
    BETA_FLAG="-beta experimental"
    echo "Experimental branch selected."
else
    USE_EXPERIMENTAL=false
    BETA_FLAG=""
    echo "Stable branch selected."
fi

# CPU note for Proxmox users
echo "NOTE: For optimal performance in Proxmox, change your VM's CPU type from the default 'kvm64' to 'host' via the Proxmox web interface."
echo ""

#############################################
# 1. Check for Root Privileges
#############################################

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run with sudo or as the root user."
  echo "Usage: sudo ./$0"
  exit 1
fi

echo "---------------------------------------------"
echo "Starting Satisfactory server setup script..."
echo "---------------------------------------------"

#############################################
# 2. Repository and Package Setup
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
# 3. Firewall Configuration
#############################################

echo ""
echo "Select your firewall scenario:"
echo "1) Selfhosted LAN Party (firewall only allows incoming connections from local network 192.168.1.0/24 for SSH and game port 7777)"
echo "2) VPS-Hosted Server with Trusted IP Access (SSH only allowed from your trusted public IP, and a whitelist file is used for game port 7777)"
read -p "Enter 1 or 2: " firewall_choice

# Reset UFW (force-reset) and set defaults
echo "Resetting UFW and setting default policies..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

if [ "$firewall_choice" == "1" ]; then
    echo "Configuring UFW for Selfhosted LAN Party..."
    # Allow SSH and game traffic only from the local network (assumed 192.168.1.0/24)
    sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp
    sudo ufw allow from 192.168.1.0/24 to any port 7777 proto tcp
    sudo ufw allow from 192.168.1.0/24 to any port 7777 proto udp
    echo "UFW rules set: Only IPs in 192.168.1.0/24 can access ports 22 and 7777."
elif [ "$firewall_choice" == "2" ]; then
    echo "Configuring UFW for VPS-Hosted Server with Trusted IP Access..."
    read -p "Enter your trusted SSH IP (the public IP you use to access this server via SSH): " trusted_ssh_ip
    # Allow SSH and game port access from the trusted SSH IP
    sudo ufw allow from "$trusted_ssh_ip" to any port 22 proto tcp
    sudo ufw allow from "$trusted_ssh_ip" to any port 7777 proto tcp
    sudo ufw allow from "$trusted_ssh_ip" to any port 7777 proto udp

    # Define whitelist file for additional trusted player IPs
    WHITELIST_FILE="/etc/satisfactory/trusted_players_whitelist.txt"
    if [ ! -f "$WHITELIST_FILE" ]; then
        sudo mkdir -p /etc/satisfactory
        sudo bash -c "cat > $WHITELIST_FILE <<EOF
# Trusted Players Whitelist for Satisfactory Dedicated Server
# Add one IP address per line below.
# These IPs will be allowed access to port 7777 (game traffic).
# IMPORTANT:
# 1. After editing this file, reload UFW (e.g. sudo ufw reload) to apply changes.
# 2. Ensure that your router/firewall also forwards port 7777 (both TCP and UDP) to this server if external access is desired.
EOF"
        echo "Whitelist file created at $WHITELIST_FILE. Edit it to add additional trusted player IPs (one per line)."
    else
        echo "Using existing whitelist file at $WHITELIST_FILE."
    fi

    # Read the whitelist file and allow each IP for game port
    while IFS= read -r ip; do
        # Skip empty lines and lines starting with '#'
        if [[ -z "$ip" || "$ip" == \#* ]]; then
            continue
        fi
        sudo ufw allow from "$ip" to any port 7777 proto tcp
        sudo ufw allow from "$ip" to any port 7777 proto udp
    done < "$WHITELIST_FILE"
    echo "UFW rules set: SSH and game port 7777 allowed only from trusted IPs."
else
    echo "Invalid option selected. No additional UFW rules will be applied."
fi

# Enable UFW
yes | sudo ufw enable

echo "Current UFW status:"
sudo ufw status verbose
echo ""

#############################################
# 4. Steam User Setup
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
# 5. Install SteamCMD
#############################################

echo "Installing SteamCMD..."
apt-get install -y steamcmd

#############################################
# 6. Create Server Directory and Set Ownership
#############################################

echo "Creating installation directory $INSTALL_DIR and setting ownership..."
sudo -u steam mkdir -p "$INSTALL_DIR"
chown -R steam:steam "$INSTALL_DIR"

#############################################
# 7. Prepare SteamCMD Environment
#############################################

echo "Ensuring the /home/steam/.steam directories exist..."
sudo -u steam mkdir -p /home/steam/.steam/sdk64 /home/steam/.steam/root

echo "Creating a symbolic link for steamcmd in /home/steam/..."
sudo -u steam ln -sf /usr/games/steamcmd /home/steam/steamcmd

#############################################
# 8. Update Satisfactory Server Files Using SteamCMD
#############################################

echo "Updating Satisfactory Dedicated Server files using SteamCMD..."
sudo -u steam /home/steam/steamcmd +force_install_dir "$INSTALL_DIR" +login anonymous +app_update 1690800 $BETA_FLAG validate +quit

# Verify that the key project file exists (warning may be benign)
if [ ! -f "$INSTALL_DIR/FactoryGame/FactoryGame.uproject" ]; then
  echo "WARNING: FactoryGame.uproject not found in $INSTALL_DIR/FactoryGame."
  echo "This message is common with some dedicated server builds."
else
  echo "Satisfactory server files installed successfully."
fi

#############################################
# 9. Create the Systemd Service File
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
# ExecStartPre updates the server files on each start.
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
