#!/bin/bash
# Make it executable un it with sudo bash wg-deploy.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[1/6] Updating package lists..."
apt-get update -y >/dev/null

echo "[2/6] Installing WireGuard and tools..."
apt-get install -y wireguard wireguard-tools qrencode curl >/dev/null

SERVER_IP=$(curl -s http://checkip.amazonaws.com || hostname -I | awk '{print $1}')
SERVER_PORT=51820
WG_CONF_DIR=/etc/wireguard

echo "[3/6] Generating server keys (not displayed for security)..."
SERVER_PRIV_KEY=$(wg genkey)
SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)

echo "[4/6] Creating WireGuard server configuration..."
mkdir -p $WG_CONF_DIR
umask 077
cat > $WG_CONF_DIR/wg0.conf <<EOF
[Interface]
Address = 10.7.0.1/24
SaveConfig = true
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIV_KEY
EOF

chmod 600 $WG_CONF_DIR/wg0.conf

echo "[5/6] Enabling and starting WireGuard service..."
systemctl enable wg-quick@wg0 >/dev/null
systemctl start wg-quick@wg0

echo "[6/6] WireGuard server is running."
echo
echo "✅ Deployment complete."
echo "--------------------------------------"
echo "Server IP:     $SERVER_IP"
echo "Listen Port:   $SERVER_PORT"
echo
echo "📌 Next steps:"
echo "  • Check VPN status:   sudo wg show"
echo "  • Add a client:       sudo bash /opt/wg-selfhost.sh add-client <name>"
echo "  • Show QR for client: sudo qrencode -t ansiutf8 < /root/<name>.conf"
echo "  • Config files:       Stored in /root/"
echo "--------------------------------------"

# Add client helper (optional run: sudo bash wg-selfhost.sh add-client <name>)
if [[ "${1:-}" == "add-client" && -n "${2:-}" ]]; then
  CLIENT_NAME=$2
  echo "[*] Adding client: $CLIENT_NAME"
  CLIENT_PRIV_KEY=$(wg genkey)
  CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)
  CLIENT_PSK=$(wg genpsk)

  CLIENT_IP="10.7.0.$((2 + $(grep -c "AllowedIPs" $WG_CONF_DIR/wg0.conf)))"

  cat >> $WG_CONF_DIR/wg0.conf <<EOP
# BEGIN_PEER $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUB_KEY
PresharedKey = $CLIENT_PSK
AllowedIPs = $CLIENT_IP/32
# END_PEER $CLIENT_NAME
EOP

  cat > /root/${CLIENT_NAME}.conf <<EOC
[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = $CLIENT_IP/24
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB_KEY
PresharedKey = $CLIENT_PSK
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0, ::/0
EOC

  chmod 600 /root/${CLIENT_NAME}.conf
  systemctl restart wg-quick@wg0
  echo "[*] Client config saved to /root/${CLIENT_NAME}.conf"
  echo "[*] View QR code with: sudo qrencode -t ansiutf8 < /root/${CLIENT_NAME}.conf"
fi
