
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

- Install `UFW` (Uncomplicated Firewall) to prevent unwanted traffic from accessing your server.
