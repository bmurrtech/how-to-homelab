# Table of Contents
- [ProxMox Hypervisor Installation](#proxmox-install)
- [Creating a ZFS Pool](#zfs-configuration)
- [Create Cloud Image VM Template](#create-cloud-image-vms)
- [Access Your Lab Anywhere](#remote-access)
- [Homelab Cybersecurity](#secure-homelab)
- [Block Ads](#ad-blocking)
- [VNC, RDP, SSH - Remotely Control VMs](#vnc)


# ProxMox Install 
- Download the latest "ProxMox ISO [version#] ISO installer" from the [official website](https://www.proxmox.com/en/downloads/category/iso-images-pve)
- Flash the ISO image to a USB drive (at least 8GB in size) using BalenaEtcher or Rufus (free Windows programs)
- Plug the flashed USB drive into the PC you wish to use as your hypervisor
> Note: Ensure that the device has a conenction to your local network so it can auto-poulate the IP settings.
- Press `F12` or `DEL` or the other BIOS key to enter your boot disk selection or BIOS.
- Force the PC to boot from the flash drive you created by selecting the flashdrive from the BIOS menu (google your PC BIOS for how to find the boot drive settings)
 - The installer page should popup. Proceed with "Install Proxmox VE"
 - Agree to the EULA
 - Select the target disk and continue (if you wish to create a ZFS pool with a second cached drive, see [below](creating-zfs-pool-and-cache) to modify the target drive.
> Note: This action will erase the drive. If you have files you don't want to lose, first back them up before proceeding.
 - Select your country and timezone.
 - Enter a password that you wish to use to access the Proxmox web UI (remember this).
 - Select your managment interface (if you have more than one NIC).
 - Enter your preferred hostname (FQDN is not required, "pve.lan" or "pve0.lan" will work).
 - Enter the static IP address you wish to use to connect to the Proxmox UI (ex. 192.168.1.100).
 - The DNS server and gateway should already be auto-populated. Typically, the default gateway for most routers is 192.168.1.1.
 - The final screen is the install screen (again, take note of the IP address, you will need this to access Proxmox.) Hit the install button and wait.
 - Remove the installer media after your computer finishes the install and successfully rebootsv (there's a confirmation screen at the end).
 - If everything was successfull, you should see a mostly black login screen (if you don't see this screen, skip to [Installation Issues](Installation-issues) below).
 - After ProxMox has finished installing, it will automatically reboot (reboot manually if it did not).
 - Now, enter the `https://[IP_address_you_set];8006` in a web browser on another machine connected to the same router and network.
 - Enter the IP address you set to access the Proxmox UI (ex. https://192.168.1.100:8006).

 > Don't forget to include "https://" and add ":8006" at the end of the IP address.

 - You will get a warning screen from your web browser telling you the URL address you went to is unsafe, but that's just because you don't have SSL for your ProxMox. It's a false alarm. Just click on whatever options you have to continue to the site.
 - Enter `root` for the username and enter the password you created at setup to access. Done!
- Next, you will be prompted to login to ProxMox. Input `root` for the username and enter the password you created at setup to gain access.

> Before deploying and VMs, you can consolidate and expand your storage. Do this *before* creating VMs.

#### Installation Issues
- If an install goes ary, you can always use the PrxoMox debug mode built into the bootable .iso installer.
- Try rebooting with the .iso installer plugged in, but this time select "Advance Options" (underneath "Install Proxmox VE") and choose the "Install Proxmox VE (Debug mode)" option.
- This will boot up in a Linux Debian CLI mode that allows you access to powerful CLI commands (i.e. wipe the drives and try reinstalling ProxMox). Type `exit` after it loads and the prompt is ready.
- You want to find the drive names. Drive names usually end in "1n1" or "0n1" depending on how many drives you have mounted.
- The drives are listed in the `/dev` folder path. Type `cd /dev` then type `ls` to list the contents of the folder to get the names of the disks (ex. `/dev/nvme0n1`). Take note of this as you will need it for the next drive wipe command.
- To wipe a corrupted install, type `wipefs -a /dev/[drive_name] [path_to_second_drive_if_applicable]`. After that, `exit` and `reboot` the endpoint and try the install again.
- Type `exit` again, wait a second, then type `reboot`. (Make sure the bootable drive is still attached.)
- The EULA should popup, and you can now attempt to reinstall Proxmox.
- You can also access BusyBox in dev/debug mode to fix a ZFS error, see below for the error message:

#### Boot fails and goes into busybox
If booting fails with something like:

```
No pool imported. Manually import the root pool
at the command prompt and then exit.
Hint: try: zpool import -R /rpool -N rpool
```
- This is because zfs is invoked too soon (it has happen sometime when connecting a SSD for future ZIL configuration).
- To prevent it, boot into debug mode, run Busybox (type `busybox` and hit `ENTER`), then try __ONE__ of the following:
 - a) edit /etc/default/grub and add "rootdelay=10" at GRUB_CMDLINE_LINUX_DEFAULT (i.e. GRUB_CMDLINE_LINUX_DEFAULT="rootdelay=10 quiet") and then issue a # update-grub
 - b) edit /etc/default/zfs, set ZFS_INITRD_PRE_MOUNTROOT_SLEEP='4', and then issue a "update-initramfs -k 4.2.6-1-pve -u"

# ZFS Configuration

#### Creating a ZFS Pool and Cache
> Note:  RAID0 forces stripped drives to the _smallest_ drive size (i.e. 2TB + 118GB = 118GB storage pool size).
> Note: RAID-Z or mirrored (RAID1) ZFS configurations will _not_ work with cache drive setups. 
- When selecting a disk, choose the primary (largest) disk and then click the options button.
- Change the file system type to the ZFS RAID0 configuration and max out the disk space allotted (should be maxed by default).
- Exclude the cache disk from the ZFS pool at this time (we will add it later).
- Choose the l4x compression, and finish out the disk wizard prompts.
- Finish the Proxmox installation, login, and open a shell to enter the following command `zpool add rpool cache [name_of_cache_drive]` and hit enter to add the cache drive to the ZFS pool created at install.
- You can check the status of the pool by typing `zpool status [name_of_pool]` (the default pool name is `rpool`). Or, you can check it in the UI. Navigate to Node (pve) > Disks > ZFS. You should see the cache drive in the pool.

#### Adding a Cache Drive
- Using SSH or the console, type the following: `zpool create rpool /dev/[primary_drive_name] cache /dev/[cache_drive_name]
- Type `zpool status tank` for an overivew of your new ZFS pool with cache.

#### Create ZFS Datasets
- You can view your current ZFS pool via `zpool list` and `zfs list`. Take note of the `mountpoint` name (if you created a ZFS pool at installation, this will be called `rpool` by default).
- To create datasets for storing `ISOs` and VM storage and more, type the following:
 - `zfs create [mountpoint_pool_name]/backups`
 - `zfs create [mountpoint_pool_name]/iso`
 - `zfs create [mountpoint_pool_name]/vm`
- These dataset will share the total pool size. It dynamically allocates disk space as needed.
- Now we need to mount/add these datasets at the `Datacenter` level:
 - Navigate to > [Datacenter (node, left-most pane) > Storage (subset) > Add > Directory](https://i.imgur.com/5QuSsWl.png) > Enter the name of the dataset (i.e. `backups`, `iso`, `vm`), and add them one at a time.
  - ID: `iso` | Directory: `/rpool/iso` | Content: `ISO image` and `Container templates`
  - ID: `vm` | Directory: `/rpool/vm` | Content: `Disk image` and `Container`
  - ID: `backups` | Directory: `/rpool/backups` | Disk Image: `VZDump backup file` and `Snippets`
 - See an [example configuration here](https://i.imgur.com/T9JzxXK.png).
 - Once the new ZFS Datasets have been successfully mapped to your Datacenter, you should [see them listed in the left navigation pane](https://i.imgur.com/1eOFcHR.png).

#### Move the Root Disk of VMs
- Navigate to > Datacenter > PVE Node > [VM] > Resources > Click on Root Disk > Click on Volume Action (button) > Move Storage > Target Storage (dropdown) > Select the `VM` dataset > Check the Delete source (box) > Move Volume (button).

#### Creating a Backup and Restore
- Now that you have created a place to store your backups, you can schedule and restore your VM or containers

> Restoring from a backup is also another way to change the number of the VM/Container.

- To create a backup repository, navigate to: Datacenter (left-most pane) > Backup (menu option) > Add (button) > Schedule: Everyday [3AM] > Selection mode: All > Storage: Backups > Create (button).
- See [an example backup configuration here](https://i.imgur.com/qAxMYoc.png). 
- To restore a backup, navigate to: Datacenter > [proxmox_node_name] > Click on Backups (ZFS dataset) > Backups (menu option on right) > Click on the backup file (ending in `.tar.zst`) > Click Restore (button, top) > Storage: VM (_not_ local) > CT: Enter the desired number (100-999) > Check the "Start after restore" box (if desired) > Do not change the default priviledge settings > Click Restore (button)
- Now, wait for the backup to be restored and you should eventually see it populate under the Datacenter > Proxmox Node > [VM/Container_Name]

# Create Cloud Image VMs

> Cloud images and cloud init work together to make lightweight, optimized, distibutions for super-fast deployment possible. Cloud services such AWS, Azure, GCP, etc use cloud init to provision Linux machines and more. To tap into that power, we can create the perfect Proxmox tempate for launching these cloud images for all subesquent VMs we may want to spin up. There's [reference documentation](https://pve.proxmox.com/pve-docs/qm.1.html), but here's how:

- Find a focal (current) cloud distro you want. I went with [Ubuntu 20.04](https://cloud-images.ubuntu.com/daily/server/focal/current/).
- Inside this focal cloud folder, you scroll until you find the [focal-server-cloudimg.amd64.img](https://i.imgur.com/XKVAyIP.png) file and then __copy the URL__ and __paste__ it in a note for later (this image will be used as the hardrive of our vitrual machines).
- Open up the shell or SSH into your Proxmox server, and type `wget` followed by a space and then the that URL link to the cloud `.img` file. Here is a sample of that command:

Ubuntu __18.04__ LTS
```
wget https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img
```

Ubuntu __20.04__ LTS
```
wget https://cloud-images.ubuntu.com/daily/server/focal/current/focal-server-cloudimg-amd64.img
```

- Wait for the image to download to your Proxmox server. Next, we need to run the following command to create a virtual machine and attach that image to this VM:  
```
qm create 8000 --memory 2048 --name 20.04-server --net0 virtio,bridge=vmbr0
```

> You can always change the name in the GUI, but you can't change the ID: `8000` is the ID of the template. This can be whatever you wish, but I set mine to a high number to distinguish it as a template.

- If you ran the command successfully, you should now see that VM listed under your Proxmox node, but we aren't finished yet. Next, we to set the disk storage: 

```
qm importdisk 8000 focal-server-cloudimg-amd64.img vm --format qcow2
```

> Note: You can also upload this ISO to a different storage dataset (i.e. local-lvm). Also, any mispellings or deviations from the precise `img` file name will produce errors. Make sure you type in the right `<source>` name.

- I had issues trying to run the `qm set --scsi0` command, so I suggest using the GUI to assign the Cloud drive to the VM.

![gui_scsi](https://i.imgur.com/o4eyart.png)

- To do this, navitagte to: Datacenter > Node > VM ("8000") > Hardware > click on Unused Disk > Edit (button) and select "SCSI" and "0" from the dropdown menus. Do not change any other settings here, and click the _Add_ button. You should now see the unused disk disappear and the [Hard Disk appear in the VM](https://i.imgur.com/p1D3l8l.png).
- Now, we need to create a virtual CD-ROM and attach it to the VM template we created:

```
qm set 8000 -ide2 vm:cloudinit
```

- The following command enables our VM to boot from the cloud drive. As an added bonus, it will speed up boot times.

```
qm set 8000 --boot c --bootdisk scsi0
```

- Next, let's create a serial console for the added ability of the web VNC capability to see the terminal.

```
qm set 8000 --serial0 socket --vga serial0`
```

- Return to the Proxmox GUI > Datacenter > Node > ubuntu-cloud VM > Cloud-init (menu), and you should now see a the cloud icon for this VM.

![cloud_init_settings](https://i.imgur.com/lukuLXY.png)

- Edit the Cloud-init settings as follows:
  - _User_: `admin`
  - _Password_: `<your_password>` (you can modify this later in VM > Cloud-init > Password and then reboot the VM)
  - _Host_: Leave as default or customize to your preference
  - _SSH Public Key_: `ssh-rsa[insert_your_public_SSH_key]`. You can readily find documentation on [how to generate a SSH Public key using PuTTYgen](https://docs.digitalocean.com/products/droplets/how-to/add-ssh-keys/create-with-putty/).

> Proxmox SSH Key ZFS Bug: When attempting to add a public key, I got the following error: _SSH public key validation error (500)_ . As it turns out, [this is a known bug](https://bugzilla.proxmox.com/show_bug.cgi?id=1188), but it does appear to be fixed. _Make sure to select_ Key > __SSH-2 RSA__ > RSA (radio button) when generating your SSH keys _or else it will not work._ Your public key should start with `ssh-rsa`. See example PuTTYGen screenshot below, and don't forget to password protect and save your private key.

![ssh_2_RSA](https://i.imgur.com/xbsItrt.png)

  - _IP Config: IPv4_ `DHCP` (radio selector). Note: The default IP value is nothing, so will not get any network access at all by default. Therefore, __you must set it to DHCP__ at or edit the values manually.

![ip_dhcp](https://i.imgur.com/KJN61by.png)

- Change the SCSI Controller from the default setting to VirtIO SCSI from the Proxmox GUI.

![VirtIO_SCSI](https://i.imgur.com/Exs2OAE.png)

> CAUTION: Do __not__ start the VM. If started, it will be boostrap the machine ID and UUID.

- In the end, you should have a hardware configuration that looks similar to this:
 
![cloud-hardware](https://i.imgur.com/JAX8z1Q.png).

- Of course, you can play with the default CPU, RAM, and disk space settings, but if anything else looks off, modify the VM to match or delete the VM and start from scratch (it's not that hard).
- When you are 100% satisfied with the results, right-click the ubuntu-cloud VM and click "Convert to template" or:

```
qm template [vm_id]
```

- You should see the icon change to a paper icon with a monitor, indicating that it has become a template.


#### Cloning Cloud Template
- Proxmox has [documentation on the process here](https://pve.proxmox.com/wiki/Cloud-Init_Support).
- Either clone via the GUI:

![clone_GUI_mode](https://i.imgur.com/RBwBLCy.png)

- Or via CLI:

```
qm clone 8000 [new_vm_id] --name [vm_name]
```

#### Increase Disk Space

> Note: Disk must be formated to __QEMU__/__qcow2__ to be able to resize. VMDK format will not work.

- By default, the VM will not have much hard drive space unless you chagned the settings prior to saving this template.
- Therfore, you must add more storage to the VM. It's not difficult. Navigat to > VM > Hardware > Hard Disk > Disk Action (top, button dropdown) > Resize > Add the desired amount.

> Note: Decreasing the disk space is more difficult than increasing, so don't give it more than necessary, and you can always increase it later if needed.

#### SSH to VM
> Tip: You can always generate or add key pairs to a server via SCP, see [Step 2 of this article](https://www.digitalocean.com/community/tutorials/how-to-configure-ssh-key-based-authentication-on-a-linux-server#step-2-copying-an-ssh-public-key-to-your-server)

- If you already know the IP addresses on your network open a Command Prompt (Windows) and type `arp -a` to get a list of IPs on your network.
- If you need more intel, run [Advance IP Scanner](https://www.advanced-ip-scanner.com/) to locate your new VM by its name to identify the IP address you can use for SSH.
- Once you have your IP address (i.e. 192.168.1.x), download and install (if you haven't already done so) [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html).
- Open PuTTY, type in the IP address (Host Name), then navigate to Connection > SSH > Auth > Browse (button) and open the `.ppk` private key that you generated and saved when you made your public key (this is necessary to access your server).
- Enter the user name you created (i.e. `admin`)
- Enter the password you set for the private key (if applicable), and your in!

![puTTY_ssh_IP](https://i.imgur.com/yeq7QN8.png)

[puTTY_ssh_key](https://i.imgur.com/6cygvoL.png)

> Tip: You can save the profile of this server for future use. You can also assign a static IP so the IP address in your router and do the necessary port forwarding you need for any web apps so it doesn't change via DHCP. 

(Optional)
```
qm set [new_vm_id] --sshkey ~/.ssh/id_rsa.pub
```

#### Transfer Files via SFTP using FileZilla
See [FileZilla's How-to](https://wiki.filezilla-project.org/Howto) for more details.
- Download FileZilla and run it.
- Navigate to File (top left tab) > Site Manager.
- Enter the IP address and port (i.e. 22).
- Enter the username you made for the VM.
- Browse and add the `.ppk` private key you generated.
- Connect to the server and transfer the files drag-n-drop style.

![sftp_filezilla](https://i.imgur.com/raDY9mj.png)

# Remote Access

#### Cloudflare DDNS Reverse Proxy
- Instead of Tailscale or enduring the ardous process of installing an enterprise-grade load-balancer like Kemp, you can get a DDNS and reverse proxy setup via CloudFlare in 15 minutes. See my [Cloudflare documentation](https://github.com/bmurrtech/how-to_homelab/blob/main/how-to_cloudflare.md) for more details on how to setup a Cloudflare tunnel and securing your homelab.
- [NetworkChuck made a video tutorial](https://www.youtube.com/watch?v=ey4u7OUAF3c) about this, but here's the steps:

> Note: You must buy a domain and create a Cloudflare Nameserver (DNS > Records > Nameservers).

- Copy the nameservers and add them to your domain registrar (nameserver updates can take up to 24hrs, but it is usually updated within minutes).
- Using [ZeroTrust](https://one.dash.cloudflare.com/899e8be9fba8f3cc125ebdf9263380e0/home/quick-start) create a new tunnel: [ZeroTrust](https://i.imgur.com/FipaEgQ.png) (left navigation pane) > Cloudflare ZeroTrust (navigation pane) > Access (dropdown) > [Tunnels](https://i.imgur.com/nnONYTE.png) > Create at tunnel (button)
 - To contine the process, see my [Cloudflare documentation](https://github.com/bmurrtech/how-to_homelab/blob/main/how-to_cloudflare.md)

#### Apache Guacamole

#### TailScale