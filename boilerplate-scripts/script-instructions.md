# How to Use the Lightweight Fail2ban Installer

Save the script locally (rename if you like):

```bash
wget https://raw.githubusercontent.com/bmurrtech/how-to-homelab/refs/heads/main/boilerplate-scripts/f2b-install.sh -O f2b-install.sh
chmod +x f2b-install.sh
```

Run as root (or via sudo):

```bash
sudo ./f2b-install.sh [flags...]
```

This installer focuses on **outside-only** protection. By default it:
- Whitelists loopback and **RFC1918** ranges (10/8, 172.16/12, 192.168/16) so you don’t lock yourself out from inside your network.
- Auto-picks `nftables-multiport` (or falls back to `iptables-multiport`).
- Enables only “externally relevant” jails if the service exists: **sshd**, **postfix**, **dovecot**, **sieve**, **coturn**.
- Leaves **nginx** jails **disabled** unless you explicitly enable them (recommended only if your logs show **real client IPs**, not just Cloudflare IPs).

---

## Quickstart Scenarios (with flags)

### 1) Default (home / on-prem)
RFC1918 is auto-whitelisted; no extra flags needed.

```bash
sudo ./f2b-install.sh
```

### 2) Cloud VM — whitelist your public IP for SSH
```bash
sudo ./f2b-install.sh --whitelist "203.0.113.7"
```

### 3) Multiple IPs/CIDRs
Comma-separated **or** repeat the flag:
```bash
sudo ./f2b-install.sh --whitelist "203.0.113.7,198.51.100.10/32"
# or
sudo ./f2b-install.sh --whitelist 203.0.113.7 --whitelist 198.51.100.10/32
```

### 4) Load a list from file
(One IP/CIDR per line; `#` comments allowed.)
```bash
echo -e "203.0.113.7\n2001:db8::/48" > /root/allow.txt
sudo ./f2b-install.sh --whitelist-file /root/allow.txt
```

### 5) Cloud-only host — do **not** auto-whitelist RFC1918
(Use if the server has no LAN peers and you want stricter behavior.)
```bash
sudo ./f2b-install.sh --no-rfc1918
```

### 6) Enable nginx jails (only if logs contain real client IPs)
If you’ve configured `real_ip_header CF-Connecting-IP` and `set_real_ip_from` for Cloudflare ranges:
```bash
sudo ./f2b-install.sh --enable-nginx
```

> Tip: If your nginx access/error logs still show Cloudflare IPs, keep nginx jails **disabled** and rely on Cloudflare WAF/rate-limits.

---

## What the Script Does

- Installs Fail2ban
- Writes `/etc/fail2ban/jail.local` with:
  - Your **ignoreip** set to loopback + RFC1918 (unless `--no-rfc1918`) + any `--whitelist`/`--whitelist-file` entries
  - Light defaults: `backend=systemd`, `bantime=1h`, `findtime=10m`, `maxretry=6`
- Adds modular jails in `/etc/fail2ban/jail.d/` for services actually present:
  - `sshd`, `postfix`, `dovecot`, `sieve` (always created), `coturn` (if installed)
  - `nginx` jails are created **disabled** unless `--enable-nginx`
- Enables and starts Fail2ban

---

## Verify / Operate

Check overall status:
```bash
sudo fail2ban-client status
```

Check a specific jail:
```bash
sudo fail2ban-client status sshd
sudo fail2ban-client status dovecot
sudo fail2ban-client status postfix
sudo fail2ban-client status sieve
sudo fail2ban-client status coturn
```

Emergency unban (from console):
```bash
sudo fail2ban-client set <jail> unbanip <IP>
# worst case:
sudo fail2ban-client unban --all
```

---

## Updating Your Whitelist Later

Edit `/etc/fail2ban/jail.local` and append IPs/CIDRs to `ignoreip` (space-separated), then:

```bash
sudo systemctl restart fail2ban
```

If you maintain a file of trusted IPs, re-run the installer with `--whitelist-file /path/to/file` (it’s idempotent and safe to rerun).

---

## Notes for Reverse-Proxied Apps (n8n, NocoDB, etc.)

- If behind Cloudflare or another proxy, ensure your app/nginx logs **real client IPs** before enabling nginx jails (`--enable-nginx`), or just keep them off and use your proxy/WAF for HTTP brute-force controls.
- For apps that spam “failed” log entries (health checks, API bursts), consider:
  - Whitelisting your internal/proxy subnet in `ignoreip`
  - Raising `maxretry`/`findtime`
  - Creating a small custom filter that ignores known-good user-agents/paths

---

## Troubleshooting

- “I locked myself out” (remote): use your provider’s console/serial to run `fail2ban-client unban --all`, then add your IP to `ignoreip`.
- coturn logs not found: ensure turnserver logging to `/var/log/turnserver/turnserver.log` is enabled, or update the jail’s `logpath`.
- nftables vs iptables: the script auto-detects; if you’ve customized, set `banaction` manually in `/etc/fail2ban/jail.local`.

---

That's it. This keeps things light, blocks outside abuse, and won’t kneecap you on your own network.
