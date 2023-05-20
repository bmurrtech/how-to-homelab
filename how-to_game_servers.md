# Satisfactory

- __Create a VM__ running Ubuntu server (ideally cloud init 20.04)

- __Allocate 12-16GB of RAM__ to a VM
- __Install dependencies__:

> Ensure you run commands as `root` or `admin` with proper permission level. Type `sudo -i` to switch to root user. Note: Some servers disable `root` by default, therefore, you need to give your user account root/admin permissions to run the commands required.

```
sudo add-apt-repository multiverse
sudo apt install software-properties-common
sudo dpkg --add-architecture i386
sudo apt update && apt -y upgrade
sudo apt install lib32gcc1
```

- __Configure settings__:

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

> `app_update 1690800 -beta experimental` is an interchangable string depending on what Steam gameserver you wish to install.

- __Now `exit`__ the `steamcmd`

- __Change the user back__ to an admin user (i.e. `root`) to check the firewall settings

```
su - [admin_user]
sudo ufw status
```

- If the firewall settings return: `Status: inactive` then __enable it and open up the port__ as follows:

```
sudo ufw allow 22
sudo ufw enable -y
sudo ufw status
```

> The status should report port 22 as allowed.

- __Open up the additional port__ as follows:

```
sudo ufw allow 15777
```

- __Change the user back to `sfserver`__ and enter the password you set

```
su - sfserver
```

- Now, navigate to:

```
screen -S server
cd server/
ls
```

- __Find the bash file `FactoryServer.sh`__ or similar and run it:

```
./FactoryServer.sh
```

- Now, __open you copy of the game__, and __navigate to "Server Manager"__ in the game.

- You will be prompted to __enter your public IP address__ (for the local network, enter `localhost`) and the port # `15777`. Hit `Confrim`.

- __Enter a name__ for your server, and __set an admin password__.
- __Configure your server settings__ as you wish
- __Click `Create Game`__ and __enter a unique session name__

> If you get a `timeout error`, just wait for the server to finish creating.

- On the Linux server screen, you can type `CTRL + A, D` to close out the screen.

```
# to see running screens/servers
screen -ls

# to bring the server screen back up
screen -r

# to kill the server
CTRL + A,  K
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





