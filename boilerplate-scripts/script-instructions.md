## How to Use Fail2ban Script
Save the script above to a file using wget:

```
bash
Copy
wget https://raw.githubusercontent.com/bmurrtech/how-to-homelab/refs/heads/main/boilerplate-scripts/fail2ban-NGINX.sh -O fail2ban-setup.sh
```

### Make it executable:
```
bash
Copy
chmod +x fail2ban-setup.sh
```

### Run as root or via sudo:
```
bash
Copy
sudo ./fail2ban-setup.sh
```

It will ask for the IP address(es) you want to whitelist. Nothing will appear as you type (hidden input).  
Press Enter when done.  
The script will:

- Install Fail2ban,  
- Create/overwrite /etc/fail2ban/jail.local with a sample configuration (including SSH, NGINX, and a custom rate-limit example),  
- Insert the IP(s) you provided into the ignoreip directive,  
- Restart Fail2ban,  
- Remove its own temporary log,  
- And self-delete for security.  

### You can check Fail2ban status anytime with:
```
bash
Copy
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo fail2ban-client status nginx-http-auth
# etc.
```

### Note

- Update and maintain /etc/fail2ban/jail.local for any additional jails or configuration changes.  
- If your home/VPN IP changes, you must update the ignoreip line accordingly and restart Fail2ban.  
- Make sure you fully understand the consequences of removing the script and logs: once deleted, they are not recoverable.

