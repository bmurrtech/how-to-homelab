
# How-to Email Server

### Step 1 Get a VPS

> Self-hosting is not ideal for running an email server b/c 1) you need to manage reverse DNS 2) you need a dedicated, static IP. If you have these for your homelab, go for it.

__Minimum Email Server Specs for 1 Email User__

| vCPU        | RAM         | HHD/SSD     |
| ----------- | ----------- | ----------- |
| 2 vCPU      | 4GB         | 20GB

- [A2 Hosting](https://www.a2hosting.com/vps-hosting/managed?aid=presearchnode&bid=3b8941fc) offers an __unmanaged__ VPS (cheaper than managed) that would work great.
- Alternatively, if you're lucky and there's resources available in your nearest Oracle datatcenter, you can [create a free cloud account with Oracle](https://www.oracle.com/cloud/sign-in.html) (get a free 4 ARM-based CPUs, 28GB RAM, w/50GB of block storage for free!).
- After making your account, create a new Oracle cloud instance:
  - Select Ubuntu 18.04 as the OS.
  - Must select ARM as your CPU for the free verision.
- Create a 50GB block volume and attach it to your instance.
  - See [Oracle's documentation](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/addingstorage.htm) on how to attach the block storage to the instance.
  - Or this [Oracle Learning video](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/addingstorage.htm)

### Step 2 Secure Your System
- Create a new user/password:

```
sudo -s
sudo useradd -m -s /bin/bash [user]
sudo passwd [user]
su - [user]
```

- Update your system:

```
sudo apt update -y && apt upgrade -y
```

- [Configure SSH, passwordless login](https://linuxize.com/post/how-to-setup-passwordless-ssh-login/) (if you haven't already).

- Prevent brute force attacks by installing `Fail2Ban`

```
sudo apt install fail2ban -y
```

### Step 3 Install Portainer

> This step is optional, but Portainer is a great tool for creating other docker containers for other services (such as a Wireguard VPN, Unbound DNS server and much more), so I made it a part of this email server tutorial.

- I've written a [Portainer install guide](https://github.com/bmurrtech/how-to-homelab/blob/main/how-to_ultimate_proxmox.md#portainer). <-- Open that link in a new tab, follow the guide to install Portainer on your VPS, then come back here.

- Most VPS providers will lock down your network and ports to prevent unautorized access. Therefore, you must check your provider's documentatio on how to edit the ingress rules to allow traffic on ports `8000` and `9443`. For Oracle Cloud, navigate to:

```
Networking > Vitrual could networks > [your_network] > Ingress Rules > Add Ingress Rules
```

- Enter the following parameters to your ingress rules:

```
# Portainer ingress rule 1
Source CIDR: 0.0.0.0/0
IP Protocol: TCP
Sorce Port Range: All
Destination Port Range: 8000
Description: Portainer 8000/tcp

# Portainer ingress rule 2
Source CIDR: 0.0.0.0/0
IP Protocol: TCP
Sorce Port Range: All
Destination Port Range: 9443
Description: Portainer 9443/tcp
```

- Now, we need to open these same ports on your VPS server instance:
  - Install `UFW` (Uncomplicated Firewall) and run the following commands:

```
sudo apt install ufw
sudo ufw allow 9443/tcp
sudo ufw allow 8000/tcp
sudo ufw enable
sudo ufw status
```

- Restart your Portainer docker by running:

```
# if you get a timeout error, restart Portainer:
sudo docker restart portainer

# check Portainer status
docker ps

# update docker compose plugin
sudo apt install docker-compose-plugin
```

- Now, try to access the Portainer web UI by typing the following in your web browser:

```
https://[your_VPS_IP_address]:9443
```

> Note: You _must_ use the secure __https://__ protocol to access the Portainer web UI. If you get a warning, ignore it and proceed (by default Portainer doesn't use SSL, and this is expected behavior). If you still cannot access your Portainer, you may need to check that your `UFW` firewall and VPS ingress rules are properly configured before continuing.

- If all goes well, you should see a Portainer login screen where you will set the admin user and password (_make it a good password_ as this is accessible to anyone on the internet by default!).
- Check if docker has SELinux support enabled:

```
sudo docker info | grep selinux
```

- If the above command returns an empty or no output, see notes below. Otherwise, skip it.
 
> Create or edit `/etc/docker/daemon.json` and add:
> ```
> {
> "selinux-enabled": true
> }
> ```
> - Then, you'll need to restart the Docker `daemon`:
> ```
> sudo systemctl restart docker
> ```
> - Refresh your Portainer web UI (and re-login if necessary)

### Step 4 Install Mailcow Email Server

- Make sure your `umask` equals `0022` __before__ you clone the `Mailcow` git.

```
umask
0022 # <-- Verify it is 0022

# if it returns 0002, then change to root by running:
sudo -s
umask
0022 # <-- Verify it is 0022
```

- If `umask` is showing `0022` now, you are good to go:

```
cd /opt
git clone https://github.com/mailcow/mailcow-dockerized
cd mailcow-dockerized
./generate_config.sh
```

- Enter your `FQDN`. This should be _your server's public IP address_, which is why a self-hosted homelab isn't ideal for an email server.
- Enter your timezone (ex. `America/New_York`).
- Select the `master branch` as we wish to have the most stable version of `Mailcow`.
- Now, the `Mailcow` `bash` script should have created a config file which you may edit to your liking:

```
sudo nano mailcow.conf
```

- Mailcow __requires Docker Compose v2__. Run the following to install it:

```
LATEST=$(curl -Ls -w %{url_effective} -o /dev/null https://github.com/docker/compose/releases/latest) && LATEST=${LATEST##*/} && curl -L https://github.com/docker/compose/releases/download/$LATEST/docker-compose-$(uname -s)-$(uname -m) > /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

- Now, apply the changes made and start the mail server:

```
sudo docker-compose up -d
```

> Note, the first run will take some time as there are numerous downloads required.

- After the completion, you should see some green "done" indicators on screen. To check the status, run:

```
sudo docker-compose ps
```

- You should notice an "Up" text maker in the `STATUS` column.
- If all looks good, time to configure the firewall rules.
- 
### Step 5 Configure Firewall Rules

#### VPS Firewall Config
- Every VPS provider may be a little different, but you need to find the firewall/security, port, ingress/egress settings and configure them. I am working in [Oracle Cloud's ingress rules](https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/apache-on-ubuntu/01oci-ubuntu-apache-summary.htm), so this tutorial assumes as much.
- Add ingress rules for `22, 25, 80, 110, 443, 465, 587, 993, 995, 4190/tcp` ports. Follow the template configuration below when configuring your ingress rules:

```
# Mailcow ingress/egress rule
Stateless: Checked
Source CIDR: 0.0.0.0/0
IP Protocol: TCP
Sorce Port Range: All (leave blank)
Destination Port Range: 22
Description: Mailcow

# Mailcow ingress rule 
Stateless: Checked/egress
Source CIDR: 0.0.0.0/0
IP Protocol: TCP
Sorce Port Range: All (leave blank)
Destination Port Range: 25
Description: Mailcow

# continue to add ingress rules for every port listed above
```

#### Docker Firewall Config
Turns out that Docker firewall settings are difficult. ["One of the most annoying things with Docker has been how it interacts with iptables. And ufw. And firewalld."](https://unrouted.io/2017/08/15/docker-firewall/) But, thanks to a recent Docker 17.06 update and higher, ["you can add rules to a new table called `DOCKER-USER`. This can be useful if you need to pre-populate iptables rules that need to be in place before Docker runs."](https://docs.docker.com/engine/userguide/networking/#links)
- To demonstrate the port issues of Docker before configuration, run a `telnet` to check if port `25` is open and listening:

```
telnet 127.0.0.1 25
```

- If it returns a `Connection refused`, then we know the Docker firewall is still blocking it. In which case, we need to update the firewall rules.
- First, create a new `iptables.conf`

```
nano /etc/iptables.conf
```

- Next, copy and paste the following contents into that file and save it:

```
*filter
:INPUT ACCEPT [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:FILTERS - [0:0]
:DOCKER-USER - [0:0]

-F INPUT
-F DOCKER-USER
-F FILTERS

-A INPUT -i lo -j ACCEPT
-A INPUT -p icmp --icmp-type any -j ACCEPT
-A INPUT -j FILTERS

-A DOCKER-USER -i ens33 -j FILTERS
-A FILTERS -m state --state ESTABLISHED,RELATED -j ACCEPT
-A FILTERS -m state --state NEW -s 1.2.3.4/32 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 25 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 110 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 465 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 587 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 993 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 995 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 4190 -j ACCEPT
-A FILTERS -j REJECT --reject-with icmp-host-prohibited

COMMIT
```

- Now, load this config into the kernel with:

```
sudo iptables-restore -n /etc/iptables.conf
```

> "That `-n` flag is crucial to avoid breaking Docker. This firewall avoids touching areas Docker is likely to interfere with. You can restart Docker over and over again and it will not harm or hinder our rules in `INPUT`, `DOCKER-USER` or `FILTERS`."

- And start the firewall at boot by creating a new `systemd.service` file:

```
# creates the file
sudo nano /etc/systemd/system/iptables.service

# contents to be added to file
[Unit]
Description=Restore iptables firewall rules
Before=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore -n /etc/iptables.conf

[Install]
WantedBy=multi-user.target

# now, enable it to start at boot
sudo systemctl enable --now iptables

# if the above failes to start it, try:
sudo systemctl enable iptables
sudo systemctl start iptables
```

- To make changes, open the firewall settings in your favourite text editor, add or remove a rule from the `FILTERS` section, then reload the firewall with:

```
# open firewall settings
sudo nano /etc/iptables.conf

# save changes then update with:
sudo systemctl restart iptables
```

__Troubleshooting__
- To confirm this suspicion further, run `netstat -tulpen` and `telnet 127.0.0.1 25` and see what ports are open. If you the ports are still returning "Connection refused" dig deeper into your `iptables`, VPS ingress/network port settings, and check Portainer > Local > Networks for anything that looks off.


#### Protainer x Ngix x Mailcow
If you wish to run `Nginx`, then you will need to make special configurations. We have to create a number of custom files to make Portainer and Mailcow play nicely together.

- Within the `mailcow-dockerized` root folder, create a new new file as follows:

```
cd /
cd /opt/mailcow-dockerized
sudo nano docker-compose.override.yml
```

- Copy and paste the following contents into that new `.yml` file:

```
version: '2.1'
services:
    portainer-mailcow:
      image: portainer/portainer-ce
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
        - ./data/conf/portainer:/data
      restart: always
      dns:
        - 172.22.1.254
      dns_search: mailcow-network
      networks:
        mailcow-network:
          aliases:
            - portainer
```

- Save and exit that `.yml` file.
- Create a `data/conf/nginx/portainer.conf` config file:

```
sudo nano data/conf/nginx/portainer.conf
```

- Copy and paste the following contents into that new `data/conf/nginx/portainer.conf` file:

```
upstream portainer {
  server portainer-mailcow:9000;
}

map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}
```

- Save and exit that `.conf` file.
- Insert a new location to the default mailcow site by creating the file `data/conf/nginx/site.portainer.custom`:

```
sudo nano data/conf/nginx/site.portainer.custom
```

- Copy and paste the following conents:

```
  location /portainer/ {
    proxy_http_version 1.1;
    proxy_set_header Host              $http_host;   # required for docker client's sake
    proxy_set_header X-Real-IP         $remote_addr; # pass on real client's IP
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout                 900;

    proxy_set_header Connection "";
    proxy_buffers 32 4k;
    proxy_pass http://portainer/;
  }

  location /portainer/api/websocket/ {
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_pass http://portainer/api/websocket/;
  }
```
- Save and exit that `.custom` file.

```
sudo docker-compose up -d && docker-compose restart nginx-mailcow
```

> Note: The nginx-mailcow restart seems to always produce the following error: `
ERROR: Invalid interpolation format for "environment" option in service "postfix-mailcow": "REDIS_SLAVEOF_IP=${REDIS_SLAVEOF_IP:-}"`

### Resources
- [Opentaq! - SELF-HOSTED | Set up and run your own Mailserver with Mailcow | DNS, Security, Installation, Test](https://www.youtube.com/watch?v=_z6do5BSJmg&t=287s)
- [Install a mail server on Linux in 10 minutes - docker, docker-compose, mailcow
](https://www.youtube.com/watch?v=4rzc0hWRSPg)
- [Portainer Install Ubuntu tutorial - manage your docker containers
](https://www.youtube.com/watch?v=ljDI5jykjE8)
- [Mailcow Docker Compose](https://docs.mailcow.email/i_u_m/i_u_m_install/)
- [Mailcow Nginx Configurations](https://docs.mailcow.email/third_party/portainer/third_party-portainer/)
- [Opening port 80 on Oracle Cloud Infrastructure Compute](https://stackoverflow.com/questions/54794217/opening-port-80-on-oracle-cloud-infrastructure-compute-node)
- [See 3 "Enable Internet Access" section of Oracle Cloud doc](https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/apache-on-ubuntu/01oci-ubuntu-apache-summary.htm)
