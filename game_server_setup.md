# Satisfactory

- __Create a VM__ running Ubuntu server (ideally cloud init 20.04)

- __Allocate 12-16GB of RAM__ to a VM

```
sudo add-apt-repository multiverse
sudo apt install software-properties-common
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install lib32gcc-s1 steamcmd
```

- __Create a new user__

```
sudo add user sfserver
```

- __Set/create a password__

- __Change to new user__

```
su - sfserver
```

- Now, __create a new directory__ for the `sfserver`

```
mkdir server
cd server
```

> If you type `pwd` you should see the file path as follows: `/home/sfserver/server` you will need to __copy/input this path__ after you install the `steamcmd` package.

- __Launch the `steamcmd`__ in this new directory/folder.

```
steamcmd
force_install_dir /home/sfserver/server
```

- Login as `anonymous`

```
login anonymous
```

- Validate the app update:

```
app_update 1690800 -beta experimental validate
```

> `app_update 1690800` is an interchangable string depending on what version of the game server you wish to install.

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
