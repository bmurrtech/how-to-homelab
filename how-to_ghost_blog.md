
ref: https://ghost.org/docs/install/ubuntu/

ref. 2: https://codecurated.com/blog/how-to-set-up-a-self-hosted-ghost-blogging-platform/

ref. 3: non-docker install: https://www.youtube.com/watch?v=99FzAidIHXs&t=78s

ref. 4: ghost-cli: https://ghost.org/docs/ghost-cli/

# Contents
- Docker Compose `yaml` Files
- [Setting Up DNS Records in Cloudflare for a Blog Subdomain](#setting-up-dns-records-in-cloudflare-for-a-blog-subdomain)
- [Configure Cloud Firewall for Cloud Self-hosting](#configuring-a-firewall-on-a-digital-ocean-droplet)

IMPORTANT: You MUST make the ${GHOST_DB_NAME} and ${MYSQL_DATABASE} DIFFERENT than "mysql" (i.e. "ghostdb") or else you'll get errors such as "CREATE DATABASE mysql CHARACTER SET utf8mb4; - Access to system schema 'mysql' is rejected."

IF getting continual database errors after making changes to the docker compose, simply delete the stack and delete the associated volumes from Portainer, and redeploy the same stack with the changes you want.

_______________________

TRAEFIK-DOCKER-COMPOSE:
_______________________

```yaml
version: '3.7'

services:
  traefik:
    image: traefik:latest
    container_name: traefik
    ports:
      - "80:80"
      - "443:443"
      # -- (Optional) Enable Dashboard, don't do in production
      # - "8081:<your_port>"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "/home/btm/traefik/config/traefik.yaml:/etc/traefik/traefik.yaml:ro"
      - "/home/btm/traefik/config/conf/:/etc/traefik/conf/"
      - "/home/btm/traefik/config/certs/:/etc/traefik/certs/"
    # -- (Optional) When using Cloudflare as Cert Resolver
    # environment:
    #   - CF_DNS_API_TOKEN=your-cloudflare-api-token
    networks:
      - frontend
    restart: unless-stopped

networks:
  frontend:
    external: true
```
___________________

TRAEFIK-CONFIG-YAML
___________________
Trafik is necessary if you want to configure a self-signed certificate (SSL) for your Ghost blog website.

```yaml
global:
  checkNewVersion: false
  sendAnonymousUsage: false

# -- (Optional) Change Log Level and Format here...
#     - loglevels [DEBUG, INFO, WARNING, ERROR, CRITICAL]
#     - format [common, json, logfmt]
# log:
#  level: ERROR
#  format: common
#  filePath: /var/log/traefik/traefik.log

# -- (Optional) Enable Accesslog and change Format here...
#     - format [common, json, logfmt]
# accesslog:
#   format: common
#   filePath: /var/log/traefik/access.log

# -- (Optional) Enable API and Dashboard here, don't do in production
# api:
#   dashboard: true
#   insecure: true

# -- Change EntryPoints here...
entryPoints:
  web:
    address: :80
    # -- (Optional) Redirect all HTTP to HTTPS
    # http:
    #   redirections:
    #     entryPoint:
    #       to: websecure
    #       scheme: https
  websecure:
    address: :443
  # -- (Optional) Add custom Entrypoint
  # custom:
  #   address: :8080

# -- Configure your CertificateResolver here...
# certificatesResolvers:
#   staging:
#     acme:
#       email: your-email@example.com
#       storage: /etc/traefik/certs/acme.json
#       caServer: "https://acme-staging-v02.api.letsencrypt.org/directory"
#       -- (Optional) Remove this section, when using DNS Challenge
#       httpChallenge:
#         entryPoint: web
#       -- (Optional) Configure DNS Challenge
#       dnsChallenge:
#         provider: your-resolver (e.g. cloudflare)
#         resolvers:
#           - "1.1.1.1:53"
#           - "8.8.8.8:53"
  production:
    acme:
      email: your-email@example.com
      storage: /etc/traefik/certs/acme.json
      caServer: "https://acme-v02.api.letsencrypt.org/directory"
#       -- (Optional) Remove this section, when using DNS Challenge
#       httpChallenge:
#         entryPoint: web
#       -- (Optional) Configure DNS Challenge
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"

# -- (Optional) Disable TLS Cert verification check
# serversTransport:
#   insecureSkipVerify: true

# -- (Optional) Overwrite Default Certificates
# tls:
#   stores:
#     default:
#       defaultCertificate:
#         certFile: /etc/traefik/certs/cert.pem
#         keyFile: /etc/traefik/certs/cert-key.pem
# -- (Optional) Disable TLS version 1.0 and 1.1
#   options:
#     default:
#       minVersion: VersionTLS12

providers:
  docker:
    # -- (Optional) Enable this, if you want to expose all containers automatically
    exposedByDefault: false
  file:
    directory: /etc/traefik/conf
    watch: true
```
__________________________

GHOST-STACK-DOCKER-COMPOSE
___________________________

```yaml
version: "3.8"

services:
  ghost:
    image: ghost:latest
    restart: always
    environment:
      - database__client=mysql
      - database__connection__host=db
      - database__connection__user=ghost # Ensure this matches MYSQL_USER below
      - database__connection__password=<yourPW> # Ensure this matches MYSQL_PASSWORD below
      - database__connection__database=ghostdb
      - url=http://<YOUR_IP>:2368
    volumes:
      - ghost-content:/var/lib/ghost/content
    ports:
      - "2368:2368"
    depends_on:
      db
        condition: service_healthy

  db:
    image: mysql:8.0
    restart: always
    volumes:
      - mysql-data:/var/lib/mysql
    environment:
      - MYSQL_USER=ghost # This creates a user named 'ghost'
      - MYSQL_DATABASE=ghostdb # This creates a database named 'ghostdb'
      - MYSQL_PASSWORD=<yourPW> # Password for the 'ghost' user
      - MYSQL_ROOT_PASSWORD=yourPWw> # Root password (can be different)
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

volumes:
  ghost-content:
  mysql-data:
```

## Setting Up DNS Records in Cloudflare for a Blog Subdomain

When using Cloudflare as your DNS provider to set up an A record for a VPS serving a blog at a subdomain (e.g., `blog.yourdomain.com`), and ensuring that the main domain (e.g., `yourdomain.com`) routes to a different web server, here’s how you can configure your DNS settings. Additionally, I'll cover setting up a CNAME record for `www.blog.yourdomain.com` rerouting to your blog for completeness.

### Step 1: Add an A Record for the Blog Subdomain

1. **Log in to Cloudflare**: Go to your Cloudflare dashboard and select the domain you're working with.
2. **Navigate to the DNS Management Section**: Find the DNS settings page.
3. **Create an A Record**:
   - **Type**: Select "A" from the dropdown menu.
   - **Name**: Enter `blog` as the name. Cloudflare automatically appends the domain to it, resulting in `blog.yourdomain.com`.
   - **IPv4 address**: Enter the IPv4 address of your VPS server where the blog is hosted.
   - **TTL**: Choose "Auto" or specify your preferred TTL value.
   - **Proxy status**: Decide if you want the traffic to be proxied through Cloudflare (orange cloud icon) for additional features like performance optimization and security, or DNS only (grey cloud icon). Proxied is recommended for most cases.
   - **Save**: Add the record by clicking on the "Save" button.

### Step 2: Configure CNAME Record for WWW Subdomain

If you want `www.blog.yourdomain.com` to reroute to `blog.yourdomain.com`, you should create a CNAME record:

1. **Create a CNAME Record**:
   - **Type**: Select "CNAME" from the dropdown menu.
   - **Name**: Enter `www.blog` as the name. This will automatically become `www.blog.yourdomain.com`.
   - **Target**: Enter `blog.yourdomain.com` as the target. This is where the CNAME points to.
   - **TTL**: Choose "Auto" or your preferred TTL.
   - **Proxy status**: As with the A record, decide on the proxy status. Typically, you'd keep it consistent with what you chose for your A record.
   - **Save**: Click on the "Save" button to add the CNAME record.

### Step 3: Ensure Main Domain Routes Correctly

Since you mentioned wanting the main domain to route to a different webserver, make sure you have an appropriate A record (or CNAME, depending on your setup) for `yourdomain.com` pointing to the IP address of the different webserver:

- **Type**: A
- **Name**: `@` (represents your root domain, `yourdomain.com`)
- **IPv4 address**: The IP address of the different web server
- **TTL**: Auto or your preference
- **Proxy status**: Decide based on your needs

### Additional Notes

- **Cloudflare Proxy**: If you enable Cloudflare's proxy (orange cloud), it will also provide additional features like DDoS protection and CDN services. This might slightly alter how you configure your web server or application, especially regarding SSL/TLS certificates and headers.
- **SSL/TLS Configuration**: Ensure you have configured SSL/TLS certificates for your domain and subdomains to serve traffic over HTTPS. Cloudflare offers flexible SSL settings and can automatically provision certificates for domains proxied through it.

After setting up these DNS records in Cloudflare, you'll have `blog.yourdomain.com` pointing to your VPS (and `www.blog.yourdomain.com` redirecting to it), while `yourdomain.com` points to a different web server, allowing you to serve content from two separate sources under the same domain.


## Configuring a Firewall on a Digital Ocean Droplet

When configuring a firewall on a Digital Ocean droplet (or any VPS) that's serving as an Nginx reverse proxy for a blog site, along with SSH access and a MySQL database, you'll want to ensure that only the necessary ports are open to maintain security. Here's a basic setup using `ufw` (Uncomplicated Firewall) on Ubuntu, which is commonly pre-installed. If your VPS uses a different operating system or you prefer another firewall tool, the principles remain the same but the commands might differ.

### Step 1: Enable UFW and Deny All Incoming Traffic by Default

```bash
sudo ufw default deny incoming
```

This command sets the firewall to deny all incoming connections, which is a secure default stance.

### Step 2: Allow Necessary Ports

You'll need to allow traffic on a few specific ports:

- **SSH (Port 22)**: To manage your server.
- **HTTP (Port 80) and HTTPS (Port 443)**: For web traffic to your Nginx reverse proxy.
- **MySQL (Port 3306)**: Only if necessary from external sources. It's more secure to only allow local connections unless remote access is absolutely needed.

```bash
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
```

For MySQL, consider if you truly need remote access. If your application and database run on the same server, or if you can connect to the database via an SSH tunnel, you don't need to open the MySQL port (3306) to the public. If your application is on a different server than your database, then you'll need to:

```bash
sudo ufw allow from [Application Server IP] to any port 3306
```

Replace `[Application Server IP]` with the IP address of the server needing to access MySQL.

### Step 3: Enable UFW

After configuring your rules:

```bash
sudo ufw enable
```

This command starts the firewall and applies your configuration.

### Step 4: Check Your Firewall Status

```bash
sudo ufw status
```

This command shows which rules are active to verify your configuration.

### Best Practices for Firewall Configuration

1. **Principle of Least Privilege**: Only open the ports that are absolutely necessary for your application to function. If a service doesn't need to be accessed from outside, it's best to keep its ports closed or restrict access to specific IP addresses.

2. **Secure SSH Access**:
   - Consider changing the default SSH port (22) to a non-standard port.
   - Use SSH key-based authentication instead of passwords for added security.
   - Implement fail2ban or a similar tool to protect against brute-force attacks.

3. **Database Security**:
   - If possible, avoid exposing your MySQL server to the public internet. Use local connections or secure, encrypted tunnels for remote access.
   - Regularly update and patch your MySQL server to protect against vulnerabilities.

4. **Regularly Review Firewall Rules**: Over time, your application's requirements may change. Regularly review and update firewall rules to remove unnecessary allowances.

5. **Use Connection Limiting and Rate Limiting**: `ufw` is relatively basic, but if you're using more advanced firewall tools or directly configuring iptables, consider rules that limit connection attempts and rates to mitigate DDoS attacks.

By following these steps and best practices, you'll significantly enhance the security of your Digital Ocean droplet or any other VPS running a blog with Nginx, SSH access, and a MySQL database.
