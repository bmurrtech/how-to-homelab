# Satisfactory
[Ref. video](https://www.youtube.com/watch?v=b4ZrXxJ_DcM)

- __Create a VM__ running Ubuntu server (ideally cloud init 20.04)

- __Allocate 12-16GB of RAM__ to a VM

- __Ensure your user has admin priveledges__ to execute certain install commands below. Or log in as root and skip to __Install dependencies__ instead:

```
sudo -s
usermod -aG sudo [username]
```

- __Install dependencies__:

> Ensure you run commands as `root` or `admin` with proper permission level. Type `sudo -i` to switch to root user. Note: Some servers disable `root` by default, therefore, you need to give your user account root/admin permissions to run the commands required.

```
sudo add-apt-repository multiverse
sudo apt install software-properties-common
sudo dpkg --add-architecture i386
sudo apt update && apt -y upgrade
sudo apt install lib32gcc1
```

- __Configure/optomize settings for a gameserver__:

```
echo "fs.file-max=100000" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf
echo "*soft nofile 100000" >> /etc/security/limits.conf
echo "*hard nofile 100000" >> /etc/security/limits.conf
ulimit -n 100000
```

- __Install Steam__:

```
sudo apt install steamcmd
```

- __Create a Steam user__ (must run as admin)

```
sudo useradd -m -s /bin/bash steam
```

- __Set/create a password__

```
sudo passwd steam
```

- __Login as user__:

```
su - steam
```

- __Make a link to user and `steamcmd`__:

```
ln -s /usr/games/steamcmd steamcmd
```

- __Launch the `steamcmd`__ in this new `steam` user directory/folder as follows:

```
steamcmd +login anonymous +force_install_dir /home/steam/sfserver +app_update 1690800 -beta experimental validate +quit
```

> `app_update 1690800 -beta experimental` is an interchangable string depending on what Steam gameserver you wish to install. For example, you can install an Ark server by simple changing the string to: `steamcmd +login anonymous +force_install_dir /home/steam/__arkserver +app_update 376030__ +quit`

- __Wait for__ the __downloads and processes to complete__. Depending on the size of the download, it may take awhile, but you should see a message such as: _"Sucecss! App [number] fully installed."_
- Once console indicates full completion of process __type: `exit`__.
- __Change the user back__ to an admin user (i.e. `root`) to configure the firewall settings

```
su - [admin_user]
ufw status
```

- If the firewall settings return: `Status: inactive` then __enable it and open up the port__ as follows:

```
sudo ufw allow 22
sudo ufw enable
sudo ufw status
```

> The status should report port 22 as `ALLOW`.

- __Open up the additional port__ that is specific to __Satisfactory__ as follows:

```
sudo ufw allow 15777
```

- __Change the user back to `steam`__ and enter the password you set:

```
su - steam
```

- Now, __navigate to__:

```
cd /home/steam/sfserver
ls
```

- __Find the bash file `FactoryServer.sh`__ or similar and run it:

```
screen -S sfserver
./FactoryServer.sh
```

> This will start the actual Satisfactory game server up for the first time.

- On the Linux server screen, you can __type `CTRL + A, D`__ to _close out the screen_. See [more details about screen here](https://www.tecmint.com/screen-command-examples-to-manage-linux-terminals/).

```
# to see running screens/servers
screen -ls

# to bring the server screen back up
screen -r [screen_name]

# to kill the server
CTRL + A,  K
```

### Joining the Satisfactory Server

- Now, __open you copy of the game__, and __navigate to "Server Manager"__ in the game.

- You will be prompted to __enter the local IP address of the machine running the server__ (check your router DHCP server IPs and set it to a static IP so it doesn't change in the future) and the port # `15777`. Hit `Confrim`.

- __Enter a name__ for your server, and __set an admin password__.
- __Create a new game__ from the Satisfactory Server GUI
- __Configure your server settings__ as you wish
- __Click `Create Game`__ and __enter a unique session name__

> If you get a `timeout error`, just wait for the server to finish creating.

### Satisfactory Server Start on Reboot
In order to make the server start on boot automatically, you have to create a custom `systemd` service file. Systemd is the service management system installed for many Linux distributions. You can read more about the concepts of `systemd` [service files here](https://docs.linuxgsm.com/configuration/running-on-boot). Thankfully, the [SatisfactoryWiki already created the service file](https://satisfactory.fandom.com/wiki/Dedicated_servers/Running_as_a_Service) for gamers to implement. Here's how to do it:

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
ExecStartPre=/usr/games/steamcmd +force_install_dir "/home/steam/sfserver" +login anonymous +app_update 1690800 -beta experimental validate +quit
ExecStart=/home/steam/sfserver/FactoryServer.sh
User=steam
Group=steam
StandardOutput=journal
Restart=on-failure
WorkingDirectory=/home/steam/sfserver
StandardOutput=append:/var/log/satisfactory.log
StandardError=append:/var/log/satisfactory.err

[Install]
WantedBy=multi-user.target
```

> Note: If you changed the username or decided to run the non-experimental server, you will need to change this service file to reflect your customized configuration. See the [raw service file template from the SatisfactoryWiki for refrence.](https://satisfactory.fandom.com/wiki/Dedicated_servers/Running_as_a_Service)


- After creating the service, you will need to execute a daemon-reload to load the new service into systemd. To keep the server running enter:

```
sudo systemctl daemon-reload
```

- To start the Satisfactory server, enter the following to commands:

```
sudo systemctl enable satisfactory
sudo systemctl start satisfactory
```

- You can check the running status with:

```
sudo systemctl status satisfactory
```

- If configured correctly, the output should look something like:

```
● satisfactory.service - Satisfactory dedicated server
     Loaded: loaded (/etc/systemd/system/satisfactory.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2021-11-02 15:30:13 CET; 2min 21s ago
   Main PID: 2529 (FactoryServer.s)
      Tasks: 24 (limit: 7053)
     Memory: 4.4G
        CPU: 4min 5.965s
     CGroup: /system.slice/satisfactory.service
             ├─2529 /bin/sh /home/steam/SatisfactoryDedicatedServer/FactoryServer.sh
             └─2536 /home/steam/SatisfactoryDedicatedServer/Engine/Binaries/Linux/UE4Server-Linux-Shipping FactoryGame
```

- Once your server is up and running, you can create a `screen` and monitor the log in real-time with a `tail` command:

```
# monitor the log file
screen -S serverlog
tail -n3 -f /var/log/satisfactory.log
# to close the screen
CTRL + A, D

# monitor the log file
screen -S serverlog
tail -n3 -f /var/log/satisfactory.err
# to close the screen
CTRL + A, D
```

- To stop/restart the server, enter:

```
sudo systemctl stop satisfactory
sudo systemctl restart satisfactory
```

__FIN__

# Ark: Survival Evolved
[Ref video for ARK](https://www.youtube.com/watch?v=oPN08QKYGvg)

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
ExecStartPre=/home/steam/steamcmd +login anonymous +force_install_dir /home/steam/arkserver +app_update 376030 +quit
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

# Modded Minecraft
This tutorial assumes you already have an Ubuntu instance ready to go and that you want to run a __1.12.2__ Minecraft Server which requires `Java 8`. If you want to run Minecraft 1.16, then you will need to install a different version of `Java` with the following command: `apt install default-jre`

### Install Java 8
- As an admin user, run the following installation commands:

```
sudo apt install openjdk-8-jdk
java -version
```

- If the `Java` version is different from wahat you wish, you can change it using:

 ```
 sudo update-alternatives --config java
 ```
 
 ### Crafting Environment

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





