# Baremetal Multi-game Server Install

### Pterodactyl Game Server Manager
Pterodactly is a game server manager with a web UI for creating and managing mulitple game servers. If your server is dedicated for games, and you want the versatility of adding/removing/running different game servers on one dedicated VPS or VM, I reccommend installing it.

There are multiple dependencies required by Pterodactly, from Let's Encrypt to a MySQL database which complicates installation; however, thanks to the amazing gaming comminity, vilhelmprytz has created an automated `bash` script to make installing Pterodactyl a breeze!

#### Automated Pterodactyl Install Method

__Resources__:
- See the __unofficial__ Pterodactyl script by vilhelmprytz on his: [Github](https://github.com/pterodactyl-installer/pterodactyl-installer)
- And watch [SoulStriker's tutorial video](https://www.youtube.com/watch?v=E2hEork-DYc) on how to use vilhelmprytz installer script.

> Disclaimer: I have not verified if this `bash` script is malicious or not. Nor have I checked the Pterodactl code. If you are concerned about potential malware or boot/root-kits, exercise zero trust and read through source code line by line to verify nothing is malicous. If this is not worth it, you have to make a choice between convenience and manually installing Pterodactyl yourself.

__Start of My Guide__
- For starters, I'm installing Portainer as my Docker container manager. Open a new tab and [follow my Portainer install guide here](https://github.com/bmurrtech/how-to-homelab/blob/main/how-to_ultimate_proxmox.md#portainer) and come back to this guide.
- With Portainer installed, login and navigate to:

```
Local > Home > App Templates > Select Ubuntu from list
```

- Name the container __Pterodactyl__ and set the Network to __bridge__.
- Grant access conrol to __administrators__
- Click "Deploy the container" button (you should see a "running" status).
- Now, access the __console__ of the new container:

```
Containers > Click Name of Container > Console > Connect (as root)
```

![port_console](https://i.imgur.com/DBiQF3w.png)

- As root, you don't have to use `sudo`, but we want to update and install `curl` in the container first:

```
apt update && apt upgrade -y
apt install curl
```

- Next, run the `bash` install script from vilhelmprytz:

```
bash <(curl -s https://pterodactyl-installer.se)
```

- Choose to install both the __panel__ and __wings__ by entering __2__.
- Enter two separate, preferred usernames and passwords for both the panel access and the admin account (this will be used to access the Pterodactyl web UI in a moment).
- Enter you time zone (ex. `America/Chicago`, `America/New_york")
- Enter your FQDN for the panel.

> If you don't know what an FQDN is, use your server's public IP address or create `A` name records pointing to your server's public IP address (ex. Type: A, Name: panel, Conent: [serverIP], Proxy status: DNS only/off, TTL: 1min).

- Agree with `y` to all the prompts (i.e. ufw, MySQL, auto config user, etc.) with `y` to continue with the installation.
- Agree to install wings and all the automatic configurations (i.e. UFW, MySQL, database hosts, etc.).
- Ener the panel address (same as the FQDN you enter previously).
- Agree to allow traffic on port `3306`.

> Note: You must ensure that port `3306` and `2022` is open on your router or VPS firewall, too!

- You will be prompted to make a username and password for the pterodactyl database, also.

__Troubleshooting__
- If you get a response stating that the "host is down" something went wrong. Try restarting the container and enter the following to test:

```
sytemctl lsit-units --type=service
```

- Research the required ports to run Pterodactyl and ensure that the Portainer Dockerized netowrk is publishing those necessary ports for panel web UI access.

__WIP__


#### Manual Pterodactyl Install Method

If you are more concerned about security and running an unofficial `bash` installer script, then start with [TechnoTim's Pterodactyl install using Docker](https://www.youtube.com/watch?v=_ypAmCcIlBE&pp=ygUacHRlcm9kYWN0eWwgcGFuZWwgaW5zdGFsbCA%3D)

- For starters, I'm installing Portainer as my Docker container manager. Open a new tab and [follow my Portainer install guide here](https://github.com/bmurrtech/how-to-homelab/blob/main/how-to_ultimate_proxmox.md#portainer) and come back to this guide.
- Now, we need the contents of Pterodactyl's `docker-compose.yml`.
- I'm grabbing the `docker-compose-example.yml` [from Pterodactyl's official Github](https://github.com/pterodactyl/panel/blob/develop/docker-compose.example.yml)
- Next, I have modified the contents of the default `.yml` file according to [TechnoTim's Pterodactyl config](https://www.youtube.com/watch?v=_ypAmCcIlBE&pp=ygUacHRlcm9kYWN0eWwgcGFuZWwgaW5zdGFsbCA%3D) to enable my reverse proxy service with Cloudflare to work with Pterodactyl.

```
version: '3.8'
x-common:
  database:
    &db-environment
    # Do not remove the "&db-password" from the end of the line below, it is important
    # for Panel functionality.
    MYSQL_PASSWORD: &db-password "CHANGE_ME"
    MYSQL_ROOT_PASSWORD: "CHANGE_ME_TOO"
  panel:
    &panel-environment
    APP_URL: "http://example.com"
    # A list of valid timezones can be found here: http://php.net/manual/en/timezones.php
    APP_TIMEZONE: "UTC"
    APP_SERVICE_AUTHOR: "noreply@example.com"
    # Uncomment the line below and set to a non-empty value if you want to use Let's Encrypt
    # to generate an SSL certificate for the Panel.
    # LE_EMAIL: ""
  mail:
    &mail-environment
    MAIL_FROM: "noreply@example.com"
    MAIL_DRIVER: "smtp"
    MAIL_HOST: "mail"
    MAIL_PORT: "1025"
    MAIL_USERNAME: ""
    MAIL_PASSWORD: ""
    MAIL_ENCRYPTION: "true"

#
# ------------------------------------------------------------------------------------------
# DANGER ZONE BELOW
#
# The remainder of this file likely does not need to be changed. Please only make modifications
# below if you understand what you are doing.
#
services:
  database:
    image: mariadb:10.5
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - "/srv/pterodactyl/database:/var/lib/mysql"
    environment:
      <<: *db-environment
      MYSQL_DATABASE: "panel"
      MYSQL_USER: "pterodactyl"
  cache:
    image: redis:alpine
    restart: always
  panel:
    image: ghcr.io/pterodactyl/panel:latest
    restart: always
    ports:
      - "80:80"
      - "443:443"
    links:
      - database
      - cache
    volumes:
      - "/srv/pterodactyl/var/:/app/var/"
      - "/srv/pterodactyl/nginx/:/etc/nginx/http.d/"
      - "/srv/pterodactyl/certs/:/etc/letsencrypt/"
      - "/srv/pterodactyl/logs/:/app/storage/logs"
    environment:
      <<: [*panel-environment, *mail-environment]
      DB_PASSWORD: *db-password
      APP_ENV: "production"
      APP_ENVIRONMENT_ONLY: "false"
      CACHE_DRIVER: "redis"
      SESSION_DRIVER: "redis"
      QUEUE_DRIVER: "redis"
      REDIS_HOST: "cache"
      DB_HOST: "database"
      DB_PORT: "3306"
networks:
  default:
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

- Since no user was created via the `.yml` file, we need to run a specific command to set one so we can access the Pterodactyl web UI. Run the following command to create an admin user:

```
docker-compose run --rm panel php artisan p:user:mak
```

- Follow the on-screen prompts to create an admin user.
- Once completed, try to login to your Pterodactyl web UI (ex. https://x.x.x.x:xxxx).

__WIP__

# Baremetal Single Game Server Install

### Satisfactory
[Ref. video](https://www.youtube.com/watch?v=b4ZrXxJ_DcM)

- __Create a VM__ running Ubuntu server. Ideally, clone a VM from a [cloud init 20.04 on Proxmox hypervisor](https://github.com/bmurrtech/how-to-homelab/blob/main/how-to_ultimate_proxmox.md)!

- __Allocate 12-16GB of RAM__ to the VM

- __Install dependencies as `root`__:

> Ensure you run commands as `root` or `admin` with proper permission level. Type `sudo -i` to switch to root user. Note: Some servers disable `root` by default, therefore, you need to give your user account root/admin permissions to run the commands required for a _64-bit machine_.

```
sudo add-apt-repository multiverse
sudo apt install software-properties-common
sudo dpkg --add-architecture i386
sudo apt update && apt -y upgrade
sudo apt install lib32gcc1
```

- __Make a new directory for `sfserver`__ to live insdie:

```
sudo mkdir /home/steam/sfserver
```

- __Check the firewall__ settings:

```
sudo ufw status
```

- If the firewall settings return: `Status: inactive` then __enable it and open up the right ports__.
- __Open up the port__ that is __specific to Satisfactory__ as follows:

```
sudo ufw allow 15777
sudo ufw allow 22
sudo ufw enable
sudo ufw status
```

> The status should report port 22 as `ALLOW`.

- __Create a Steam user__ (must run as admin)

```
sudo useradd -m -s /bin/bash steam
```

- __Set/create a password__

```
sudo passwd steam
```

```
sudo -s
usermod -aG sudo steam
su - steam
```

- __Install `steamcmd`__:

```
sudo apt-get install steamcmd
```

> Learn more about `steamcmd` and how it functions from the [Steam developer Wiki](https://developer.valvesoftware.com/wiki/SteamCMD)

- __Login as `steam` user__:

```
su - steam
```

- Choose your path 1) [Make the sever start automatically on boot](#automatically-start-satisfactory-server) or 2) [Start the server manually every time](#manually-start-satisfactory-server). See paths below:

### Automatically Start Satisfactory Server
In order to make the server start on boot automatically, you have to create a custom `systemd` service file. Systemd is the service management system installed for many Linux distributions. You can read more about the concepts of `systemd` [service files here](https://docs.linuxgsm.com/configuration/running-on-boot). Thankfully, the [SatisfactoryWiki already created the service file](https://satisfactory.fandom.com/wiki/Dedicated_servers/Running_as_a_Service) for gamers to implement. Here's how to do it:

- First, __login as an admin user__ (required for `sudo` to work when creating a `service.file`).
- __Make a link__ from `/user/steam/steamcmd` to /home/steam/:

```
ln -s /usr/games/steamcmd steamcmd
```

-__Create a new service file__ for Satisfactory:

```
sudo nano /etc/systemd/system/satisfactory.service
```

- __Copy & paste__ the following contents into the new file:

```
[Unit]
Description=Satisfactory dedicated server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Environment="LD_LIBRARY_PATH=./linux64"
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
```

- __Save it__:

```
CTRL + X, Y, ENTER
```

> Note: If you changed the username or decided to run the non-experimental server, you will need to change this service file to reflect your customized configuration. See the [raw service file template from the SatisfactoryWiki for refrence.](https://satisfactory.fandom.com/wiki/Dedicated_servers/Running_as_a_Service)


- After creating the service, you will need to __execute a daemon-reload__ to load the new `service.file` into systemd. To keep the server running enter:

```
sudo systemctl daemon-reload
```

- To __start the Satisfactory server__, enter the following to commands:

```
sudo systemctl start satisfactory
```

- You can __check the running status__ with:

```
sudo systemctl status satisfactory.service
```

- If configured correctly, the output should look something like:

```
● satisfactory.service - Satisfactory dedicated server
     Loaded: loaded (/etc/systemd/system/satisfactory.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2021-11-02 15:30:13 CET; 2min 21s ago
   Main PID: 2529 (FactoryServer.s)
      Tasks: 24 (limit: 7053)
     Memory: 8G
        CPU: 4min 5.965s
     CGroup: /system.slice/satisfactory.service
             ├─2529 /bin/sh /home/steam/sfserver/FactoryServer.sh
             └─2536 /home/steam/sfserver/Engine/Binaries/Linux/UE4Server-Linux-Shipping FactoryGame
```

- To stop/restart the server, enter:

```
sudo systemctl stop satisfactory
sudo systemctl restart satisfactory
```

- Once your server is up and running, you can create a `screen` and monitor the log in real-time with a `tail` command:

```
# monitor the log file
tail -n3 -f /var/log/satisfactory.log

# monitor the log file
tail -n3 -f /var/log/satisfactory.err
```

#### Joining the Satisfactory Server for the First Time

- Now, __open you copy of the game__, and __navigate to "Server Manager"__ in the game.

- You will be prompted to __enter the local IP address of the machine running the server__ (check your router DHCP server IPs and set it to a static IP so it doesn't change in the future) and the port # `15777`. Hit `Confrim`.

- __Enter a name__ for your server, and __set an admin password__.
- __Create a new game__ from the Satisfactory Server GUI
- __Configure your server settings__ as you wish
- __Click `Create Game`__ and __enter a unique session name__

> If you get a `timeout error`, just wait for the server to finish creating.

#### Manually Start Satisfactory Server

- __Invoke the `steamcmd` to install the Satisfactory server__ in this new `steam` user directory/folder as follows:

```
steamcmd
force_install_dir /home/steam/sfserver/
login anonymous
app_update 1690800 -validate
```

> You can also run it as one line:
> ```
> steamcmd +force_install_dir /home/steam/sfserver/ +login anonymous +app_update 1690800 validate +quit
> ```
> Change the line after `+login anonymous` to `+app_update 1690800 -beta experimental +quit` if you want to install the experimental gamer server version.

- __Wait for__ the __downloads and processes to complete__. Depending on the size of the download, it may take awhile, but you should see a message such as: _"Sucecss! App '1690800' fully installed."_


- We could start the server as-is, right now (see below on how) __BUT if you want the Satisfactory server to start AUTOMATICALLY on boot__, then you'll want to follow the steps outlined in [this section](###satisfactory-server-start-on-reboot):

> ```
> cd /home/steam/sfserver
> ls
> ```
> - __Finding the bash file `FactoryServer.sh`__ or similar and run it:
> ```
> screen -S sfserver
> cd sfserver
> ./FactoryServer.sh
> ```
> This will start the actual Satisfactory game server with logs inside a `screen`.
> - On the Linux server screen, you can __type `CTRL + A, D`__ to _close out the screen_. See [more details about screen here](https://www.tecmint.com/screen-command-examples-to-manage-linux-terminals/).
> ```
> # to see running screens/servers
> screen -ls
> # to bring the server screen back up
> screen -r [screen_name]
> # to kill the server
> CTRL + A,  K
> ```

__FIN__


### Ark: Survival Evolved
[Ref video for ARK](https://www.youtube.com/watch?v=oPN08QKYGvg)

- __Configure/optomize settings for the Ark gameserver__:

```
echo "fs.file-max=100000" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf
echo "*soft nofile 100000" >> /etc/security/limits.conf
echo "*hard nofile 100000" >> /etc/security/limits.conf
ulimit -n 100000
```

- Follow all prior steps to get `steamcmd` installed, but this time, __create a folder within `/home/steam/` called `ark`__ specifically for Ark.
- Once you have created a new ARK directory, __run the fullowing__ `steamcmd` to install the ARK server:

```
steamcmd +login anonymous +force_install_dir /home/steam/__arkserver +app_update 376030__ +quit
```

- Now we need to add custom parameters to an `ark.service` file. Change to the admin user and __edit the file as follows__:

```
nano /etc/systemd/system/ark.service
```

- __Copy and paste__ the following into that `ark.service` file:


```
[Unit]
Description=ARK Survival Evolved
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3
User=steam
Group=steam
ExecStartPre=/home/steam/steamcmd +force_install_dir /home/steam/arkserver +login anonymous +app_update 376030 +quit
ExecStart=/home/steam/arkserver/ShooterGame/Binaries/Linux/ShooterGameServer TheIsland?listen?SessionName=ArkServer -server -log -NoBattlEye
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s INT $MAINPID
WorkingDirectory=/home/steam/arkserver/ShooterGame/Binaries/Linux
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
```

> To be cross compatiable with the EPIC game launcher, add `-NoBattlEye` after `-log` on the `ExecStart` line (already included in the above configuration).

- __Set the server password and admin server password__:

```
sudo nano /home/steam/arkserver/ShooterGame/Saved/Config/LinuxServer/GameUserSettings.ini

# add and modify these lines in the .ini file
ServerPassword=YourServerPassword
ServerAdminPassword=YourServerAdminPassword
```

- __Whitelist the following ports__ in the Ubuntu server:

```
sudo ufw 7777
sudo ufw 27015
```

- Also, __don't forget to port forward `777` and `27015` on your router__.

- To ensure the VM starts the ARK server on reboot, enter the following commands:

```
systemctl daemon-reload
systemctl start ark
systemctl status ark.service

# restart or stop the server
systemctl restart ark
systemctl stop ark
```

### Modded Minecraft
This tutorial assumes you already have an Ubuntu instance ready to go and that you want to run a __1.12.2__ Minecraft Server which requires `Java 8`. If you want to run Minecraft 1.16, then you will need to install a different version of `Java` with the following command: `apt install default-jre`

#### Install Java 8
- As an admin user, run the following installation commands:

```
sudo apt install openjdk-8-jdk
java -version
```

- If the `Java` version is different from wahat you wish, you can change it using:

 ```
 sudo update-alternatives --config java
 ```
 
 #### Crafting Environment

- If you haven't already, run an update on your Ubutnu system:

```
sudo apt update && apt -y upgrade
```

- Update `Screen`, a command that will contain and tail the server logs:

```
sudo apt install screen
```

- __Create a new user__ (must run as admin)

```
sudo useradd -m minecraft
```

- __Set/create a password__

```
sudo passwd minecraft
```

- __Change to new user__

```
su - minecraft
```

- Now, __create a new directory__ for the `sfserver`

```
cd /opt
mkdir modserver
cd modserver
```

> If you type `pwd` you should see the file path as follows: `/home/minecraft/modserver` you will need to __copy/input this path__ after you install the `steamcmd` package.

- __Download the Forge Installer__ (necessary for modded Minecraft):





