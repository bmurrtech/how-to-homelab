### **Any and all copyright materials used are for educational, non-commercial, illustrative (research, criticism, & comment), unpublished purposes only. Facts themselves are not copyrightable.**

### **Any other works of mine are under the Attribution NonCommercial ShareAlike 4.0 International license.**

Shield: [![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

This work is licensed under a
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License][cc-by-nc-sa].

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg

# Acknowledgements
- Ben Heater's OG pfSense VLAN guide was immensley helpful. Go check out [Ben's other great guides](https://benheater.com/) no his website! 
- BobCares website to [force a DHCP release](https://bobcares.com/blog/force-dhcp-client-to-renew-ip-address/) came in handy! I guess Bob really does care.

# Table of Contents
- [Provisioning pfSense VM](#provisioning-pfsense)
- [Setup VLANs in Proxmox](#configure-proxmox-nics)
- [Deploy pfSense](#deploy-pfsense)
- [Configure pfSense](#configure-vlans)

# How-to Guide about the PfSense firewall
Why you want a pfSense firewall:
- Protect your network.
- Limit vulnerbilities.
- Separate VMs from other devices on the network.

This guide will teach you how to seperate (VLAN) your VMs from your home/prodcution network so you can stop attackers/guests/gaming-buddies from moving laterally in your network and viewing/accessing/infecting/compromising other machines on the same network.

### Provisioning pfSense

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

## Deploy pfSense

### pfSense Proxmox Conigurations
- Select the pfSense VM > __Options > OS Type > Edit (button) > Select "other"__
![pfsensexproxmox_opt_config](https://i.imgur.com/eJiiC92.png)

### Ensure your pfSense VM has a staticly assigned IP address from your router:
If the IP address of the DHCP server (usually assigned by your router) changes, you will have issues. To mitigate this problem:
- access your router settings to change the DHCP server settings (usually in LAN > DHCP Server > Mannual IP Assignment)
- identify your pfSense VM's __WAN__ IP/MAC address (usually assigned by DHCP dynamically),
- change it to a static IP,
- then apply the settings in your router.

![pfsense_mac_address](https://i.imgur.com/vdWeoFA.png)

### Add the vmbr1 NIC to the pfSense VM
The following action adds the pfSense internal switch NIC created earlier to the pfSense VM. Once the VM is stopped, you can add the secondary NIC we made before.
- Proxmox Node > pfSense VM > __Hardware > Add (button) > Network Device__ > Bridge: `vmbr1`

![vmbr1_NIC_add](https://i.imgur.com/XixvZFz.png)

> Note: If you get the following error, then reboot your Proxmox machine and try to launch the pfSense VM again.
> ![VM_start_error](https://i.imgur.com/WF782h0.png)

### Start the pfSense VM to begin the setup:

- Click on the VM > __Start__ (button, top right) 
- Open a console or `ssh` session to the pfSense
- Wait for the intiial load screen
- Hit `Enter` to accept the terms

![accept_pfsense_terms](https://i.imgur.com/WlM8hBh.png)

- Progress through the GUI installer

![install_pfsense_GUI](https://i.imgur.com/QfYn7bs.png)

> Note: You may need to enter the advance disk settings to create a mount point if the auto installer method fails. Format as `MBR`, create a partition, then use the auto installer thereafter.

### Interface Setup

- When prompted to setup VLANs, enter `n` for now.
- Enter the __WAN interface__ name (enter what is provided in the prompt;for me it was `vtnet0`), and do not use the auto-detection `a` as it will fail.
- When prompted to enter a 2nd NIC for the __LAN interface__ type: `vtnet1`
- Type `y` to proceed.

![pfsense_install_wizard1](https://i.imgur.com/yfncxX3.png)

- After the installer runs, you should come to an end screen, you should see the WAN and LAN and an IP address to the web UI for pfSense.

![pfsense_end_install_screen](https://i.imgur.com/jLj9gQH.png)

- Take note of the IP that was assigned (or statically set) by the DHCP Server. _This IP is how you will access the pfSense web UI later._ Does it match what you assigned? If not, you may need to renew the IP.

> Note: You may need to manually __invoke a ```dhclient -r <interface>```__ command from the shell of the VM __and reboot the VM__ in order to get the static IP to apply. If you don't know what the interface is on your VM, simply run ```nmcli con``` to get the name of the interface.

### Configure VLANs

- Start the pfSense VM
- Select option `1` to assing the new NIC and setup VLANs
![](https://i.imgur.com/bt1eFtr.png)

1. __Should VLANs be setup now [y|n]__
  - Enter `Y`
2. __Enter the parent interface name for the new VLAN__
  - Enter `vtnet1` (vtnet1 is the LAN interface)
    - Enter tag `666`
- Enter `vtnet1` (again)
    - Enter `999`
3. Press `Enter` to complete the VLAN setup

> You should come this screen in the VLAN setup stage:
> ![progressofvlan](https://i.imgur.com/3ja9EMq.png)

4. __Enter the parent interface for the new VLAN__
  - Enter the __WAN__ interface name which is: `vtnet0`
5. Enter the __LAN__ interface
  - Enter `vtnet1`
6. Enter the __Optional 1 interface__
  - Enter `vtnet1.666`
7. Enter the __Optional 2 interface__
  - Enter `vtnet1.999`.
> If configured corretly, you should see a screen like this:
>![progressofvlan2](https://i.imgur.com/r76oCgo.png)
6. Do you want to proceed?
  - Enter `Y`
- Wait for additional setup steps to complete

> Special thanks to Ben Heater for these excellently defined steps in [his guide](https://benheater.com/proxmox-lab-pfsense-firewall/). Thanks, Ben!

### Configure LAN IP Range 10.0.0.1
- Enter `2` at the pfSense config screen to change the LAN IP range from the default.
![lanipconfig](https://i.imgur.com/bT0Vo81.png)
- Select the interface you wish to configure the IP range.
- Configure IPv4 address LAN interface via DHCP? (y/n)
    - Enter `n`
- Enter the new IPv4 address as: `10.0.0.1`
    - Enter `24`
    - Press `Enter` (for LAN)
- Configure IPv6 address LAN interface via DHCP6? (y/n)
    - Enter `n`
- Enter the new LAN IPv6 address. Press `Enter` for none.
- Do you want to enable the DHCP server on LAN? (y/n)
    - Enter `y`
    - Start of range: 10.0.0.11
    - End of range: 10.0.0.244
- Do you want to revert to HTTP?
    - Enter `n`
    - Press `Enter` to complete
- You should see an output that reflects the changes made that looks similar to this:
![iprangeconfigured](https://i.imgur.com/zDRamzn.png)

 ### Configure LAN IP Range 10.6.6.1
- Enter `2` at the pfSense config screen to change the LAN IP range from the default.
![lanipconfig](https://i.imgur.com/bT0Vo81.png)
- Select the interface you wish to configure the IP range.
- Configure IPv4 address LAN interface via DHCP? (y/n)
    - Enter `n`
- Enter the new IPv4 address as: `10.6.6.1`
    - Enter `24`
    - Press `Enter` (for LAN)
- Configure IPv6 address LAN interface via DHCP6? (y/n)
    - Enter `n`
- Enter the new LAN IPv6 address. Press `Enter` for none.
- Do you want to enable the DHCP server on LAN? (y/n)
    - Enter `y`
    - Start of range: 10.0.0.11
    - End of range: 10.0.0.244
- Do you want to revert to HTTP?
    - Enter `n`
    - Press `Enter` to complete

 ### Configure LAN IP Range 10.9.9.1
- Enter `2` at the pfSense config screen to change the LAN IP range from the default.
![lanipconfig](https://i.imgur.com/bT0Vo81.png)
- Select the interface you wish to configure the IP range.
- Configure IPv4 address LAN interface via DHCP? (y/n)
    - Enter `n`
- Enter the new IPv4 address as: `10.9.9.1`
    - Enter `24`
    - Press `Enter` (for LAN)
- Configure IPv6 address LAN interface via DHCP6? (y/n)
    - Enter `n`
- Enter the new LAN IPv6 address. Press `Enter` for none.
- Do you want to enable the DHCP server on LAN? (y/n)
    - Enter `y`
    - Start of range: 10.0.0.11
    - End of range: 10.0.0.244
- Do you want to revert to HTTP?
    - Enter `n`
    - Press `Enter` to complete

### pfSense Config Summary
After completing the intial pfSense configuration via CLI, you should see a result as shown in the screenshot below: 
![pfsenseconfigsummary](https://i.imgur.com/LUisItB.png)

### Troubleshooting pfSense CLI Config
If something goes wrong or the prompts do not match this guide, simply select option `4` at the main prompt screen to restore factory defaults and start over.

![troubleshootingpfsensecliconfig](https://i.imgur.com/bt1eFtr.png)

### Add Other VLANs

- Repeat the steps to create a new NIC (i.e `vmbr1`, VLAN tag `300`, VLAN tag `400`, etc.) in Proxmox
-  Repeat the Configure LAN IP Range for the new VLAN (i.e. "OPT3 > 10.3.3.11, OPT4 10.4.4.11, etc.)

### Enable web UI access to pfSense
- From the pfSense UI, enter `8` and type in `pfctl -d` to enable the pfSense web UI access needed to change other settings using the GUI instead of CLI.
![pfsensewebuienable](https://i.imgur.com/i68Kbtu.png)

> Note: A reboot will cause the web UI to revert to defaults and you'll have to repeat this step after a reboot to regain access to the web GUI again. Ben Heater explains on [his website](https://benheater.com/proxmox-lab-pfsense-firewall/): "pfSense is blocking WAN access to the web console. This is a good thing if your pfSense router is sitting at the edge of your network. You wouldn't want any body to be able to reach the login page of your home router from the internet. In reality, the IP address on the WAN port is a private IP address – which is not accessible from the Internet without some workarounds. So, _in this case, it's perfectly safe to open the WAN port inside our home network_."

### Access the web GUI
- Enter the IP address you assigned in the DHCP Server in the URL address (ex. http://192.168.1.24).
- If you encounter a screen in your browser that warns you about your connection not being private, ignore it and proceed (to unsafe), it's safe because it's your pfSense router on your network.
- Enter the default credentials: `admin` (username) and `pfsense` (password)
- Enter a host name: `<name>-<name>` (ex. pfsense-fw)
- Enter a domain name: `<name>.<name> (ex. pf.range)

![hostnamedomainname](https://i.imgur.com/7It6Wiz.png)

- If you use a DNS resolver you wish pfSense to use, check the `Override DNS`, if not, enter a DNS resolver of your choice. 
- NPT Server: set the __timezone__ and click next to accept the default. 
- Set the DHCP Hostname to the name you assigned and uncheck the `Block RFC1918 Private Networks` since we want to allow private IPs through the WAN, not block them.

![](https://i.imgur.com/WespfwB.png)

- Skip the LAN interfance config since we already configured it prior.
- __Important__: Change the default admin password!
- Click `Reload` and then `Finish` to complete the wizard.

> Note: You'll lose connection to the web GUI and you'll need to run `pfctl -d` in the VM console to access again.

### Enable web GUI access permantely - add WAN rule 
- Navigate to: __Firewall > Rules > WAN__
![wanruleedit1](https://i.imgur.com/7AIAM5h.png)

- Add the following firewall settings:

![wanruleedit2](https://i.imgur.com/uwcLZpt.png)

- __Save__ and __Apply Changes__

### Rename OP1 and OPT2
What you rename these to is up to you and depends on your purposes, but the goal of this guide is to A) create a separate network from prodcution/home (completed via `vmbr1`) and B) create two VLANs for security sandbox tools that is segragated from 10.0.0.1/24. Therefore, we will name the OPTs accordingly. See below:

- In the pfSense web GUI, navitage to: __Interfaces > Assignments__
- Click on the cooresponding interface and change the description as follows:
- Rename `OPT1` to `SEC_EGRESS`
- Rename `OPT2` to `SEC_ISOLATED`

> If you have other VLAN goals, then change or add new VLAN tags by creating a new `OVS IntPort`in the Proxmox network node. Revisit [NIC Settings](#apply-the-new-nic-settings) to extrapolate.

- `Save` each change and click `Apply Changes` after to submit the changes.

### Create an Alias for `RFC1918`
The alias serves as an alternate name for all private IPv4 addresses.
- __Firewall > Aliases > Add__
- Fill in the fields and add networks as follows:

![rfc1918networks](https://i.imgur.com/lUIkBeH.png)

> If you change the `Type` to `Host(s)` you can assign an static IP in  __Firewall > Aliases > Add__ for the DHCP server to assign.

### Create WAN firewall fules for security lab
> To allow the home network to reach the internal LAN, we need to set a `Pass` action for all addresses and protocols. This is necessary if we wish to `ssh` or create an `RDP` session to the Kali Linux VM on the `SEC_EGRESS` VLAN.

-  __Firewall > Rules > WAN > Add (down arrow)__
- Add the following configuration to your WAN rules:

![wanruleforlantalk](https://i.imgur.com/6kh0N0K.png)

- Click `Save`

### Allow WAN net to ping WAN address
-  __Firewall > Rules > WAN > Add (down arrow)__
![wanping](https://i.imgur.com/VO0Ed0d.png)

### Block ALL WAN access to `SEC_EGRESS` LAN
> It's paramount that we do not allow any packets to reach the LAN from the WAN. We only want egress, no ingress.

- Click `Save`

- __Firewall > Rules > WAN > Add (down arrow)__

![blockWANingressonSECegress](https://i.imgur.com/uaaLkis.png)

- And `Save`

### Block ALL WAN ingress to `SEC_ISOLATED`
> The same impiteous applies to `SEC_ISOLATED` -- we don't want the isolated VLAN to have internet ingress access.

__Firewall > Rules > WAN > Add (down arrow)__
- Add the following configuration to your WAN rules:

![blockWANingressonSECisolated](https://i.imgur.com/myC8lPG.png)

- Click `Save` on this new rule.

### WAN outcome summary
> The outcome of the rules shouel read as follows:

![idealWANruleoutcome](https://i.imgur.com/9F0H5NP.png)

> Leave the LAN firewall rules alone. It is good as-is.

### `SEC_EGRESS` rules - allow traffic to local gateway
> Because `RFC1918` will be blocked in future rules, we can allow the default gateway access to the Internet.

- __Firewall > Rules > `SEC_EGRESS` > Add (up arrow)__

![secegress1](https://i.imgur.com/cXq0Pb8.png)

- Add the following rules:

![](https://i.imgur.com/lZ80dKh.png)

- `Save`

### Create `Kali1` alias host
- Navitgate to __Firewall > Aliases > IP > Add__
- Enter the following details to create the `Kali1` alias:

![](https://i.imgur.com/60ylsXZ.png)

- `Save` the alias.
- `Apply Changes`

![applykali1changes](https://i.imgur.com/uGgrZio.png)

### Allow packets to Kali malware lab analysis

- __Firewall > Rules > `SEC_EGRESS` > Add (DOWN arrow)__
- Create the following rules for for the `Kali1` VM to access the `SEC_EGRESS` VLAN:

![rulesforsecegresstoakali](https://i.imgur.com/tbZpJTz.png)

- `Save` the rules.
- If you get an error, check the name you created the for the Kali VM matches what you enterd.

![kalivmnotfound](https://i.imgur.com/b3u41WT.png)

### Allow packets to Internet (for non-private IPs)

- __Firewall > Rules > `SEC_EGRESS` > Add (DOWN arrow)__
- Add the following rules (make sure to check the "invert match" box):

![invertmatchsecegresshost](https://i.imgur.com/BwNEBsN.png)

### Block everything else for `SEC_EGRESS`

- __Firewall > Rules > `SEC_EGRESS` > Add (DOWN arrow)__
- Create the following rules:

![blockallthethingsnow](https://i.imgur.com/DHAqjAx.png)

### Check `SEC_EGRESS` final rule state
- Do your rules match the following?

![finalSECegressstate](https://i.imgur.com/WesC5Bh.png)

- If the rules match, click `Apply Changes`

### `SEC_ISOLATED` rule setup - allow to Kali1

- Navigate to the `SEC_ISOLATED` rules __Firewall > Rules > `SEC_ISOLATED`__

![SEC_ISOLATEDfirewallrules](https://i.imgur.com/m4SDiDH.png)

- Click __Add (UP arrow)__ and input the following rules:

![allowpacketstokali1](https://i.imgur.com/5d8vGDE.png)

- Click `Save`

### Block everything else on `SEC_ISOLATED`
- __Firewall > Rules > `SEC_EGRESS` > Add (DOWN arrow)__
- Now to block everything other than `Kali1`

![blockallthethingsnow2](https://i.imgur.com/w17b7bq.png)

> Rules have an order or execution based upon position. If a rule is above, it ignores all other rules BELOW it. In this case, because the block all rule is last, anything before it is allowed. But if I moved the `Kali1` allow rule BELOW the block all rule, `Kali1` couldn't communicate with the `SEC_ISOLATED` hosts.

### Check `SEC_ISOLATED` final rule state

![finalstateofSECisolatedrules](https://i.imgur.com/Q4buCSq.png)

> No "Block Bogon" found? That's becuase you have to check the box at the bottom of the page on __Interfaces > <Inteface Name> > Block Bogon Networks (checkbox)__

![blockthebogonnetwork](https://i.imgur.com/i4wRt4A.png)

- If the rules match, click `Apply Changes`

### Configure DNS Resolver Settings
- Nav to __Services > DNS Resolver__
- Check these two boxes for __DHCP Registration__ and __Static DHCP__

![dhcpregandstaticdhcp](https://i.imgur.com/2NibZ6d.png)

- Now, nav to __Advanced Settings__ and ensure that your settings match the following configuration:

![matchadvconfigopts](https://i.imgur.com/MKiW2Jw.png)

### How to add additional VLANs to pfSense
- Nav to: __Proxmox Node > Network__
- Add a new VLAN tag to `vmbr1` by: __Create > OVS IntPort__ and select `vmbr1` and enter a new VLAN tag and comment.
- Apply the by clicking `Apply Configuration` (button)
- Add the new VLAN to pfSense by accessing the pfSense web GUI (i.e. URL)
- Nav to: __Interfaces > Assignments > VLANs > Add__
- Fill in the VLAN Configuration with:
  - Parent Interface: `vtnet1`
  - VLAN Tag: `<your VLAN tag number>`
  - Descritpion (optional)" `<designation comment for your own organizational sanity>`
- Nav to: __Interface Assignments > Add__ (next to the newly added interface)
- Click `Save` and you should now see an `OPT#` interfance populate.

### Configure new VLAN interface
- Click on the new `OPT#` name to conifigure.
- Enter a description if you like.
- Set the IPv4 Configuration Type to `Static IPv4` (no need for IPv6, so leave as "none")
- For the Static IPv4 Configuration, enter the desired IP range youw want (i.e. 10.1.1.1/24 not 10.1.1.0/24).
- At the bottom of the __Interfaces > <Inteface Name>__ be sure to check the __Block Bogon Networks__ (checkbox).

### Configure DHCP server over new interface
- Nav to: __Services > DHCP Server > <interface_name> > Enable__
- Set the desire IP range (i.e. 10.1.1.11 - 10.1.1.244)
- Hit `Save` and `Apply Changes` if you are happy with it.

### Don't forget to add some firewall rules
- Nav to: __Firewall > Rules > <interface_name>__ to add new rules.

> There are not going to be any rules by default (except if you’re blocking bogon nets). Therefore, it's your call on how you configure the firewall rules. For assistance, I check out [RaidOwl's YouTube video about configuring various firewall rules](https://youtu.be/rHE6MCL4Gz8?si=GSpluLibUKUrewvL&t=545) for some tips.
