### **Any and all copyright materials used are for educational, non-commercial, illustrative (research, criticism, & comment), unpublished purposes only. Facts themselves are not copyrightable.**

### **Any other works of mine are under the Attribution NonCommercial ShareAlike 4.0 International license.**

Shield: [![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

This work is licensed under a
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License][cc-by-nc-sa].

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg

# How-to Guide about the PfSense firewall

### Install PfSense

> For reference, see PfSense's install guide ![pfsense_install_guide](https://docs.netgate.com/pfsense/en/latest/install/download-installer-image.html)
- Download a PfSense ```.iso``` from the official site: https://www.pfsense.org/download/

> Note: This guide assumes you are deploying the PfSense to a VM in Proxmox; however, if you wish to deploy to a dedicated machine you may wish to download the USB version or burn the ```.iso``` file to a bootable USB instead.
 
> At the time of writing this guide, PfSense does _not_ have a ```ARM``` compatible (i.e. RaspberryPi or ```ARM```-based cloud solutions won't work).

![pfsense_download_page](https://i.imgur.com/BYEXu0X.png)

- Upload the ```.iso``` to your Proxmox hypervisor.

![ISO_upload](https://i.imgur.com/mYBIRX7.png)

- Once you have uploaded the ```.iso```, click ```Create VM``` (button on the top right of Proxmox UI).

> Provision the VM to have the reccomended specs that PfSense advises. Check the [PfSense Min Hardware Reqs](https://docs.netgate.com/pfsense/en/latest/hardware/minimum-requirements.html), but here's what I found:
> - 64-bit amd64 (x86-64) compatible CPU
> - __1GB__ RAM or more
> - __8GB__ disk drive disk drive (SSD, HDD, etc) or larger
> - One or more compatible network interface cards. We will circle back NICs after the install, but see [Configure NICs](###configure-proxmox-nics) for to skip ahead to setting up VLANs on Proxmox.

### Configure Proxmox NICs
To leverage PfSense VLANs we need to configure Proxmox NICs and assign VLAN tags which will be passed through to the PfSense firewall VM.
