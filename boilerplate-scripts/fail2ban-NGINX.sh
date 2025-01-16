#!/usr/bin/env bash
#
# fail2ban-setup.sh - Boilerplate script to install & configure Fail2ban
#                     on a Debian/Ubuntu system, whitelisting user-provided IPs.
#
# -----------------------------------------------------
# 1. Prompts user (hidden input) for IP(s) to whitelist
# 2. Installs Fail2ban
# 3. Creates /etc/fail2ban/jail.local with default jails (SSH, Nginx)
# 4. Whitelists user-provided IP(s)
# 5. Restarts Fail2ban
# 6. Removes the script-generated log & self-deletes
# -----------------------------------------------------

######################################
# 0. Safety Checks & Logging
######################################

# Ensure script is run as root/sudo
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo). Exiting..."
  exit 1
fi

# Redirect output (stdout and stderr) to a temporary setup log.
# We will delete this log at the end for security reasons.
exec 1>/tmp/fail2ban-setup.log 2>&1

######################################
# 1. Prompt User for Whitelist IP(s)
######################################

# Prompt (with hidden input) for IP address or addresses
echo "Please enter the IP address(es) you want to whitelist (hidden):"
echo "  (e.g., your home public IP or VPN IP, space-separated if multiple)"
read -s -p "> " WHITELIST_IPS
echo
echo "IP address(es) recorded. They will NOT be echoed to the screen."

######################################
# 2. Update & Install Fail2ban
######################################

echo "Updating package lists..."
apt-get update -y

echo "Installing Fail2ban..."
apt-get install fail2ban -y

######################################
# 3. Create jail.local Configuration
######################################

echo "Creating /etc/fail2ban/jail.local..."
cat <<EOF >/etc/fail2ban/jail.local
[DEFAULT]
# Whitelist user-provided IP(s) + localhost
ignoreip = 127.0.0.1/8 ::1 $WHITELIST_IPS

# Ban settings
bantime  = 3600
findtime = 600
maxretry = 5

destemail = root@localhost
banaction = iptables-multiport
mta       = sendmail
protocol  = tcp
chain     = INPUT
loglevel  = INFO

########################
# Jails
########################

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 5

[nginx-http-auth]
enabled  = true
filter   = nginx-http-auth
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 5

########################
# Custom Rate-Limit (Example)
########################
[custom-rate-limit]
enabled  = true
port     = http,https
filter   = custom-rate-limit
logpath  = /var/log/nginx/access.log
maxretry = 20
findtime = 60
bantime  = 600
EOF

echo "Fail2ban jail.local created."

######################################
# 4. Restart Fail2ban & Verify
######################################

echo "Restarting Fail2ban to apply changes..."
systemctl restart fail2ban

echo "Checking Fail2ban status..."
fail2ban-client status || true

######################################
# 5. Cleanup (Remove Logs & Script)
######################################

# Remove the script-generated log
echo "Removing the temporary setup log..."
rm -f /tmp/fail2ban-setup.log

# Self-delete this script
SCRIPT_PATH="$(readlink -f "$0")"
echo "Self-deleting script: $SCRIPT_PATH"
rm -f "$SCRIPT_PATH"
