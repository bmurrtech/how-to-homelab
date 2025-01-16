## How to Use Fail2ban Script
Save the script above to a file using wget:

```
wget https://raw.githubusercontent.com/bmurrtech/how-to-homelab/refs/heads/main/boilerplate-scripts/fail2ban-NGINX.sh -O fail2ban-setup.sh
```

### Make it executable:
```
chmod +x fail2ban-setup.sh
```

### Run as root or via sudo:
```
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
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo fail2ban-client status nginx-http-auth
# etc.
```

### Note

- Update and maintain /etc/fail2ban/jail.local for any additional jails or configuration changes.  
- If your home/VPN IP changes, you must update the ignoreip line accordingly and restart Fail2ban.  
- Make sure you fully understand the consequences of removing the script and logs: once deleted, they are not recoverable.

## Fail2ban Configuration for Self-Hosted Tools (n8n, NocoDB, etc.)

Fail2ban operates by scanning logs for suspicious activity and banning IPs that exceed certain thresholds. Because of this, certain web services—such as n8n, NocoDB, or other self-hosted tools—might inadvertently trigger Fail2ban jails if their logs contain entries that match Fail2ban’s ban criteria. This can happen for example if:

### Potential Causes of Fail2ban Triggers

- The service’s health checks or API calls appear as repeated “failures” in the logs.
- The service experiences periodic bursts of traffic (e.g., from integrations or cron jobs).
- The service uses an authentication mechanism that logs multiple “failed” events which fail2ban’s filters interpret as malicious traffic.

### Considerations and Potential Workarounds

1. ### Whitelist Your Internal/Trusted IP
   If n8n, NocoDB, or other tools run behind a reverse proxy such as NGINX and traffic always comes from a specific internal IP or Docker network, you could add that IP/range to the Fail2ban ignoreip list. This ensures Fail2ban doesn’t ban traffic from those known safe internal addresses.

   #### Pros:
   + Quick and easy solution if you have static IPs or well-defined networks.

   #### Cons:
   + If your legitimate service can be accessed from multiple or dynamic IP addresses, you’d have to keep updating your whitelist.

2. ### Create a Separate Fail2ban Filter or Jail Exclusion
   You can set up Fail2ban so that it does not interpret certain patterns in the logs as malicious. For instance, you could either:

   + **Create a Custom Filter**: Write a filter that specifically ignores the log lines from n8n or NocoDB.
   + **Disable/Skip certain jails**: If there is a jail targeting NGINX error logs or a particular log path, ensure that the lines from your known web service do not match the “fail” patterns.

   #### Example: Excluding Known Service Patterns
   In the custom filter or jail config, you can fine-tune the regex so that it either excludes certain user agents, paths, or request patterns that are known to be legitimate traffic from n8n/NocoDB.

   #### Pros:
   + Allows you to keep Fail2ban active for other suspicious traffic without accidentally banning a legitimate service.

   #### Cons:
   + Requires more advanced Fail2ban filter regex configuration.
   + Ongoing maintenance if the service’s logs or patterns change.

3. ### Adjust the Thresholds (findtime, maxretry, bantime)
   Sometimes legitimate services cause lots of “fail”-like entries that trigger a ban because the maxretry or findtime is set too aggressively.

   + **Increase maxretry**: This makes Fail2ban more tolerant of repeated requests before banning.
   + **Increase findtime**: If an IP’s attempts are spread out over a longer window, they might not trigger a ban so easily.
   + **Lower bantime**: Even if a legitimate service (or user) is banned, it will be re-enabled more quickly.

   This approach can reduce false positives at the risk of being slower to ban truly malicious traffic.

4. ### Create a Dedicated Jail for the Service
   Alternatively, create a dedicated jail that is specifically tuned for the logs of the web service you want to protect, rather than relying on a broad NGINX or “custom-rate-limit” jail. For example:

   + n8n might have its own logs (if you log errors or auth attempts).
   + NocoDB might have logs in a separate location.

   A dedicated jail can help focus on the events that truly indicate malicious behavior (like repeated auth failures) rather than routine request patterns.

### Overall Recommendation

If you see legitimate requests from n8n or NocoDB being banned:

1. **Check Fail2ban logs**:
   + `sudo fail2ban-client status <jail_name>`
   + Look for which IPs are banned and why.

2. **Identify Patterns**:
   + If these IPs belong to your own service or come from a known internal network, whitelist them in your ignoreip setting.

3. **Fine-Tune or Create a Custom Filter**:
   + If the problem persists, modify the relevant jail/filter so that legitimate events do not register as malicious.

4. **Adjust Thresholds**:
   + Tweak maxretry, findtime, and bantime to find the right balance between security and usability.

Taking these steps helps retain Fail2ban’s protective benefits while preventing it from interfering with legitimate traffic or self-hosted tools like n8n, NocoDB, and similar services.


