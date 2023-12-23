### **Any and all copyright materials used are for educational, non-commercial, illustrative (research, criticism, & comment), unpublished purposes only. Facts themselves are not copyrightable.**

### **Any other works of mine are under the Attribution NonCommercial ShareAlike 4.0 International license.**

Shield: [![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

This work is licensed under a
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License][cc-by-nc-sa].

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg

# Table of Contents
- [Install pfSense VM](#install-pfsense)
- [Setup VLANs](#configure-proxmox-nics)

# How-to Guide about the PfSense firewall
Why you want a pfSense firewall:
- Protect your network.
- Limit vulnerbilities.
- Separate VMs from other devices on the network.

This guide will teach you how to seperate (VLAN) your VMs from your home/prodcution network so you can stop attackers/guests/gaming-buddies from moving laterally in your network and viewing/accessing/infecting/compromising other machines on the same network.

### Install pfSense

> For reference, see [pfSense's install guide](https://docs.netgate.com/pfsense/en/latest/install/download-installer-image.html).
- Download a pfSense ```.iso``` from the official site: https://www.pfsense.org/download/

> Note: This guide assumes you are deploying the pfSense to a VM in Proxmox; however, if you wish to deploy to a dedicated machine you may wish to download the USB version or burn the ```.iso``` file to a bootable USB instead.
 
> At the time of writing this guide, pfSense does _not_ have a ```ARM``` compatible (i.e. RaspberryPi or ```ARM```-based cloud solutions won't work).

![pfsense_download_page](https://i.imgur.com/BYEXu0X.png)

- Upload the ```.iso``` to your Proxmox hypervisor.

![ISO_upload](https://i.imgur.com/mYBIRX7.png)

- Once you have uploaded the ```.iso```, click ```Create VM``` (button on the top right of Proxmox UI).

> Provision the VM to have the reccomended specs that PfSense advises. Check the [PfSense Min Hardware Reqs](https://docs.netgate.com/pfsense/en/latest/hardware/minimum-requirements.html), but here's what I found:
> - 64-bit amd64 (x86-64) compatible CPU
> - __1GB__ RAM or more
> - __8GB__ disk drive disk drive (SSD, HDD, etc) or larger
> - One or more compatible network interface cards. We will circle back NICs after the install, but see [Configure NICs](###configure-proxmox-nics) for to skip ahead to setting up VLANs on Proxmox.

## Configure Proxmox NICs
To leverage pfSense VLANs we need to configure Proxmox NICs and assign VLAN tags which will be passed through to the pfSense firewall VM.

### Install network dependencies on the Proxmox node: 

- Select Proxmox node > Shell (button) > copy and paste the following:

```pash
apt clean && apt update
apt install ifupdown2 openvswitch-switch -y
```

### Backup your network interface (in case something goes wrong).

- Open a shell to your Proxmox node and run the following:

```bash
cp /etc/network/interfaces /etc/network/interfaces.bak
```

![interfaces_bak](https://i.imgur.com/hIOktIa.png)

> Backup Note: You can always restore the original configuration by overwritting the ```interfaces``` file with your backup ```interfaces.bak``` file.
- Click on your __Proxmox Node > Network__. Select ```vmbr0``` and choose __Remove__.

![remove_linux_bridge](https://i.imgur.com/pDyX8PE.png)

### Create open vSwtiches:

- __Create > OVS Bridge > Bridge ports__: ```<your physical eth interface>```

![ovsbridge1](https://i.imgur.com/3hfa4to.png)

- Fill in the fields as seen in the screenshot below and click __Create__.

![ovsbridge2](https://i.imgur.com/2pmnSVI.png)

>  __Note__: Your physical interface will likely be different than mine. Therefore you MUST enter YOUR physical interface name instead. To get your interface name, open a shell to the Proxmox node and enter ```ip addr``` and it will list the interface(s).

![interfacename](https://i.imgur.com/ZQWSHMQ.png)

### Create the management interface for the Proxmox UI:

- __Create > OVS IntPort__

![ovs_int_port](https://i.imgur.com/AHeuNdq.png)

### Create a pfSense internal switch:

- __Create > OVS Bridge__ > Name: ```vmbr1``` > Comment: ```<pfSense int>```

![pfsense_int_bridge](https://i.imgur.com/OQIwhiY.png)

### Create a VLAN for publically accessible (internet-facing), _non-isloated_ and _unsecure_ VMs:

- __Create > OVS IntPort__ > Name: "vmbr1_```<VLAN tag>```" > VLAN Tag: ```<number you choose>``` > Comment: ```<pfsense egress>```

![pfsense_egress](https://i.imgur.com/FOJ1qHq.png)

### Create VLAN for publically acessible (internet-facing), _isolated_ and _unsecure_ VMs:

- __Create > OVS IntPort__ > Name: "vmbr1_```<VLAN tag>```" > VLAN Tag: ```<number you choose>``` > Comment: ```<pfsense isloated egress>```

![pfsense_egress_isolated](https://i.imgur.com/YTOEiNg.png)

### Apply the New NIC Settings

![apply_proxmox_nic_config](https://i.imgur.com/I0FpMmQ.png)

### Summary of VLANs on Proxmox
You should have a configuration that is similar to the following:

![px_vlan_config_summary](https://i.imgur.com/l5kw4j1.png)

### Troublehooting Connectivity

If you encountered connectivity issues to the ProxMox UI _after_ applying the NIC config changes (i.e. OVS Bridge and VLAN), then you can restore your known working session by logging into your Proxmox server _locally_ (i.e. physically connect a keyboard and monitor to the Proxmox machine) and run the following command from the shell:

```bash
cp /etc/network/interfaces.bak /etc/network/interfaces
ifreload -a
```

This will restore the original, functional network configurations to that you _should_ be able to access your Proxmox web UI again from another computer on the network just as before.
