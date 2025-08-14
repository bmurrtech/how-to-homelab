set -euo pipefail

# --- Packages ---
sudo apt-get update
sudo apt-get install -y wireguard-tools qrencode iptables jq curl

# --- Enable forwarding (IPv4 + IPv6) ---
sudo tee /etc/sysctl.d/99-wireguard.conf >/dev/null <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sudo sysctl --system >/dev/null

# --- Vars & helpers ---
DEFAULT_USER="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$DEFAULT_USER" | cut -d: -f6)"
WG_ETC="/etc/wireguard"
WG_IF="wg0"
WG_SUBNET="10.7.0.0/24"
WG_ADDR="10.7.0.1/24"
WG_PORT="51820"
NIC="$(ip route show default 2>/dev/null | awk '{print $5}' | head -n1)"
[ -n "$NIC" ] || NIC="$(ls -1 /sys/class/net | grep -v -E 'lo|wg.*' | head -n1)"
umask 077

next_client_ip() {
  local used
  used=$(grep -E 'AllowedIPs *= *10\.7\.0\.[0-9]+/32' -o "$WG_ETC/$WG_IF.conf" 2>/dev/null \
         | grep -oE '10\.7\.0\.[0-9]+' | awk -F. '{print $4}' | sort -n | xargs || true)
  for i in $(seq 2 254); do
    if ! grep -qw "$i" <<< "$used"; then echo "$i"; return 0; fi
  done
  echo "No free IPs in 10.7.0.0/24" >&2; return 1
}

get_public_ip() {
  curl -4fsS https://ifconfig.co 2>/dev/null \
  || curl -4fsS https://ipinfo.io/ip 2>/dev/null \
  || ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1
}

# --- Server keys ---
sudo install -d -m 700 "$WG_ETC"
if [ ! -f "$WG_ETC/server_private.key" ] || [ ! -f "$WG_ETC/server_public.key" ]; then
  (umask 077; wg genkey | sudo tee "$WG_ETC/server_private.key" >/dev/null)
  sudo bash -c "wg pubkey < '$WG_ETC/server_private.key' > '$WG_ETC/server_public.key'"
  sudo chmod 600 "$WG_ETC"/server_*.key
fi
SERVER_PRIV="$(sudo cat "$WG_ETC/server_private.key")"

# --- Server config (/etc/wireguard/wg0.conf) ---
if [ ! -f "$WG_ETC/$WG_IF.conf" ]; then
  sudo tee "$WG_ETC/$WG_IF.conf" >/dev/null <<EOF
[Interface]
PrivateKey = ${SERVER_PRIV}
Address = ${WG_ADDR}
ListenPort = ${WG_PORT}
# NAT and forwarding (iptables-nft backend on Ubuntu 24.04)
PostUp = iptables -t nat -A POSTROUTING -o ${NIC} -s ${WG_SUBNET} -j MASQUERADE
PostUp = iptables -A FORWARD -i ${NIC} -o ${WG_IF} -m state --state RELATED,ESTABLISHED -j ACCEPT
PostUp = iptables -A FORWARD -i ${WG_IF} -o ${NIC} -j ACCEPT
PreDown = iptables -t nat -D POSTROUTING -o ${NIC} -s ${WG_SUBNET} -j MASQUERADE
PreDown = iptables -D FORWARD -i ${NIC} -o ${WG_IF} -m state --state RELATED,ESTABLISHED -j ACCEPT
PreDown = iptables -D FORWARD -i ${WG_IF} -o ${NIC} -j ACCEPT

# Peers will be appended below
EOF
  sudo chmod 600 "$WG_ETC/$WG_IF.conf"
fi

# --- Bring server up ---
sudo systemctl enable wg-quick@"$WG_IF"
sudo systemctl restart wg-quick@"$WG_IF"

# --- Create client1 if missing ---
install -d -m 700 "$USER_HOME/.wireguard"
if [ ! -f "$USER_HOME/.wireguard/client1.conf" ]; then
  CNAME="client1"
  C_PRIV="$(wg genkey)"
  C_PUB="$(printf '%s' "$C_PRIV" | wg pubkey)"
  PSK="$(wg genpsk)"
  HOSTBYTE="$(next_client_ip)"
  C_IP="10.7.0.${HOSTBYTE}/32"
  S_PUB="$(sudo bash -c "wg pubkey < '$WG_ETC/server_private.key'")"
  ENDPOINT_IP="$(get_public_ip)"
  ENDPOINT="${ENDPOINT_IP:-your.public.ip}:${WG_PORT}"

  # Append to server config (idempotent)
  if ! grep -q "^# BEGIN_PEER ${CNAME}$" "$WG_ETC/$WG_IF.conf"; then
    sudo tee -a "$WG_ETC/$WG_IF.conf" >/dev/null <<EOF

# BEGIN_PEER ${CNAME}
[Peer]
PublicKey = ${C_PUB}
PresharedKey = ${PSK}
AllowedIPs = ${C_IP}
# END_PEER ${CNAME}
EOF
    sudo systemctl restart wg-quick@"$WG_IF"
  fi

  # Write client file
  umask 077
  cat > "$USER_HOME/.wireguard/${CNAME}.conf" <<EOF
[Interface]
PrivateKey = ${C_PRIV}
Address = ${C_IP}
DNS = 1.1.1.1

[Peer]
PublicKey = ${S_PUB}
PresharedKey = ${PSK}
Endpoint = ${ENDPOINT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
  chmod 600 "$USER_HOME/.wireguard/${CNAME}.conf"
fi
sudo chown -R "$DEFAULT_USER:$DEFAULT_USER" "$USER_HOME/.wireguard"

# --- Sudo-only helpers ---
sudo tee /usr/local/sbin/wg-show >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "Use: sudo wg-show [client-name]"; exit 1; }
OWNER="${SUDO_USER:-}"; [ -n "$OWNER" ] || { echo "SUDO_USER not set; run with sudo"; exit 1; }
OWNER_HOME="$(getent passwd "$OWNER" | cut -d: -f6)"
NAME="${1:-client1}"
FILE="$OWNER_HOME/.wireguard/${NAME}.conf"
[ -f "$FILE" ] || { echo "Config not found: $FILE"; exit 1; }
cat "$FILE"
EOF
sudo chmod 750 /usr/local/sbin/wg-show

sudo tee /usr/local/sbin/wg-qr >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "Use: sudo wg-qr [client-name]"; exit 1; }
OWNER="${SUDO_USER:-}"; [ -n "$OWNER" ] || { echo "SUDO_USER not set; run with sudo"; exit 1; }
OWNER_HOME="$(getent passwd "$OWNER" | cut -d: -f6)"
NAME="${1:-client1}"
FILE="$OWNER_HOME/.wireguard/${NAME}.conf"
command -v qrencode >/dev/null 2>&1 || { echo "qrencode not installed"; exit 1; }
[ -f "$FILE" ] || { echo "Config not found: $FILE"; exit 1; }
exec qrencode -t ansiutf8 < "$FILE"
EOF
sudo chmod 750 /usr/local/sbin/wg-qr

sudo tee /usr/local/sbin/wg-add >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "Use: sudo wg-add <client-name>"; exit 1; }
[ $# -eq 1 ] || { echo "Usage: sudo wg-add <client-name>"; exit 1; }
NAME="$1"
OWNER="${SUDO_USER:-}"; [ -n "$OWNER" ] || { echo "SUDO_USER not set; run with sudo"; exit 1; }
OWNER_HOME="$(getent passwd "$OWNER" | cut -d: -f6)"
DST="$OWNER_HOME/.wireguard"
IFACE="wg0"; ETC="/etc/wireguard"; PORT="51820"

next_ip() {
  local used
  used=$(grep -E 'AllowedIPs *= *10\.7\.0\.[0-9]+/32' -o "$ETC/$IFACE.conf" 2>/dev/null \
         | grep -oE '10\.7\.0\.[0-9]+' | awk -F. '{print $4}' | sort -n | xargs || true)
  for i in $(seq 2 254); do
    if ! grep -qw "$i" <<< "$used"; then echo "$i"; return 0; fi
  done
  echo "No free IPs in 10.7.0.0/24" >&2; return 1
}
get_pubip() {
  curl -4fsS https://ifconfig.co 2>/dev/null || curl -4fsS https://ipinfo.io/ip 2>/dev/null \
  || ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1
}

PRIV=$(wg genkey); PUB=$(printf '%s' "$PRIV" | wg pubkey); PSK=$(wg genpsk)
HOSTBYTE=$(next_ip); C_IP="10.7.0.${HOSTBYTE}/32"
S_PUB=$(awk '/^\[Interface\]/{f=1} f&&/^PrivateKey/{print $3; exit}' "$ETC/$IFACE.conf" | wg pubkey)
ENDPOINT_IP=$(get_pubip); ENDPOINT="${ENDPOINT_IP:-your.public.ip}:${PORT}"

# Append to server if not present
if ! grep -q "^# BEGIN_PEER ${NAME}$" "$ETC/$IFACE.conf"; then
  {
    echo ""
    echo "# BEGIN_PEER ${NAME}"
    echo "[Peer]"
    echo "PublicKey = ${PUB}"
    echo "PresharedKey = ${PSK}"
    echo "AllowedIPs = ${C_IP}"
    echo "# END_PEER ${NAME}"
  } | tee -a "$ETC/$IFACE.conf" >/dev/null
fi

install -d -m 700 "$DST"
cat > "$DST/${NAME}.conf" <<CFG
[Interface]
PrivateKey = ${PRIV}
Address = ${C_IP}
DNS = 1.1.1.1

[Peer]
PublicKey = ${S_PUB}
PresharedKey = ${PSK}
Endpoint = ${ENDPOINT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
CFG
chown -R "$OWNER:$OWNER" "$DST"
chmod 600 "$DST/${NAME}.conf"

systemctl restart wg-quick@${IFACE} >/dev/null 2>&1 || true
echo "Created ${NAME}: $DST/${NAME}.conf"
EOF
sudo chmod 750 /usr/local/sbin/wg-add
