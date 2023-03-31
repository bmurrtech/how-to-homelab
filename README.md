Shield: [![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

This work is licensed under a
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License][cc-by-nc-sa].

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg

# Homelab How-to
- [How-to Create the ULTIMATE Proxmox Hypervisor](https://github.com/bmurrtech/how-to-homelab/blob/main/how-to_proxmox_hypervisor.md)
- [How-to Remotely Access Your Servers via Cloudflare](https://github.com/bmurrtech/how-to-homelab/blob/main/how-to_cloudflare.md)
- [How-to Make a 24-7 Youtube Livestream](https://github.com/bmurrtech/how-to-homelab/blob/main/how-to_24-7_livestream.md)
- [How-to Create a Flux Node on Proxmox](https://github.com/bmurrtech/how-to-homelab/blob/main/how-to_flux_proxmox_node.md)
- [How-to Setup Kemp Load-balancer](https://github.com/bmurrtech/how-to-homelab/blob/main/how-to_kemp_loadmaster.md)

# My Homelab Projects To-do

See MikeRoyal's [Master HomeLab Guide](https://github.com/mikeroyal/Self-Hosting-Guide) for nearly unlimited homelab ideas!

- [x] [Set up secure tunnel via CloudFlare's DNS](https://www.youtube.com/watch?v=ey4u7OUAF3c)
- [x] [Expose Proxmox hypervisor to the internet](https://www.youtube.com/watch?v=ey4u7OUAF3c)
- [x] Setup MFA to connect to [Cloudflare Tunnel](https://github.com/bmurrtech/how-to_homelab/blob/main/how-to_cloudflare.md)
- [x] Create [Proxmox Ubuntu 20.04 LTS Cloud Init Template](https://github.com/bmurrtech/how-to-homelab/blob/main/how-to_proxmox_hypervisor.md#create-cloud-image-vms)
- [ ] Create a Cloud init VM for [Ansible, the agentless automation tool](https://docs.technotim.live/posts/ansible-automation/)
- [ ] Create HA Kubernetes cluster via Ansible playbook; [see Techno Tim's doc](https://docs.technotim.live/posts/k3s-etcd-ansible/)
- [ ] [Install Rancher on top of Kubernetes cluster](https://ranchermanager.docs.rancher.com/v2.5/pages-for-subheaders/install-upgrade-on-a-kubernetes-cluster)
- [x] Create Ubuntu Desktop VM and setup:
  - [ ] Live [Stock Ticker in terminal](https://github.com/bmurrtech/mind-dump/blob/main/rtsp_rss_feed.md)
  - [ ] [Scrolling RSS Feed](https://github.com/bmurrtech/mind-dump/blob/main/rtsp_rss_feed.md)
  - [ ] [OBS screen capture](https://resources.antmedia.io/docs/simulcasting-to-social-media-channels) and also see [this](https://medium.com/@khan_honney/webrtc-replay-from-obs-hosted-rtmp-stream-b995d168497)
  - [ ] Stream to [Ant Media Server](https://github.com/bmurrtech/mind-dump/blob/main/rtsp_rss_feed.md)
  - [ ] Upload [stream to YouTube](https://resources.antmedia.io/docs/simulcasting-to-social-media-channels) for 24/7 RSS and stock ticker
  - [ ] RSS Feed Reader
- [ ] Build Docker containers via Rancher w/K3S to run all the following web apps:
  - [ ] Secure network access via [TailScale](https://tailscale.com/kb/1039/install-ubuntu-2004/)
  - [ ] Reverse Proxy via:
    - [ ] [Traefik](https://perfectmediaserver.com/remote-access/traefik101/)
    - [ ] [VPNs](https://perfectmediaserver.com/remote-access/vpns/)
    - [ ] [Kemp Loadmaster](https://github.com/bmurrtech/my-road-to-tech-job-in-22-days#kemp-loadmaster)
  - [ ] VNC Remote Access to Homelab apps via [Guacamole}(https://www.youtube.com/watch?v=gsvS2M5knOw)
  - [ ] Create a validating, recursive, caching DNS resolver fpr home network
    - [ ] Create [Unbound DNS Server](https://unbound.docs.nlnetlabs.nl/en/latest/use-cases/home-resolver.html)
    - [ ] [Configure clients](https://stevessmarthomeguide.com/home-network-dns-dnsmasq/) to local Unbound DNS
  - [ ] Setup [Cloudron](https://www.cloudron.io/store/index.html) free account
    - [ ] See [a list of Remote Access methods](https://github.com/mikeroyal/Self-Hosting-Guide#Remote-Access)
  - [ ] [Cybersecurity](https://github.com/bmurrtech/0-100-days-cloud-engineer/blob/main/home_network_cybersecurity.md) steps to secure homelab.
    - [ ] SSO Authelia Setup
  - [ ] Pterodactyl + Docker [game server](https://docs.technotim.live/posts/pterodactyl-game-server/)
  - [ ] Homer (interface for NAS)
  - [ ] [ownCloud](https://owncloud.com/pricing/) - self-hosted cloud with mobile apps; [see support docs](https://owncloud.com/docs-guides/)
  - [ ] Backup software for Windows/Mac and more via [BackupPC](https://github.com/backuppc/backuppc) or [Kopia](https://kopia.io/)
  - [ ] [PhotoSync for iOS](https://www.photosync-app.com/home.html)
  - [ ] Build HTML Website using [Hugo](https://gohugo.io/getting-started/quick-start/) or [Kopage](https://www.kopage.com/tour)
    - [ ] View Hugo [themes](https://themes.gohugo.io/)
  - [ ] Self-host website; see [self-hosted web server options](https://github.com/awesome-foss/awesome-sysadmin#web)
  - [ ] [MongoDB Database](https://www.mongodb.com/pricing) 512MB "Shared" free version - for building user database (i.e. Ant Media Server, Wordpress users, etc.)
    - [ ] Read about MongoDB basics in [this book](https://github.com/miollek/Free-Database-Books/blob/master/book/MongoDB%20Basics.pdf)
  - [ ] Jellyfin media server (install on Synology NAS)
  - [ ] Openbooks (ebooks media server)
  - [ ] Deluge (BitTorrent client written in Python)
  - [ ] Jakcett (torrent tracker) + Sonarr & Radarr
  - [ ] PhotoPrism - The iPhone Photo Killer (set up automation in WebDav to auto-upload)
  - [ ] BitWarden | run [VaultWarden - open-source compatible server](https://github.com/dani-garcia/vaultwarden)
  - [ ] PiHole (VPN into home network, local DNS server, recursive DNS resolver, run Unbound)
  - [ ] pfSense (VLANs, cybersecurity, port-forwarding)
  - [ ] HomeAssistant (for home automation)
  - [ ] [Paperless-ngx](https://docs.paperless-ngx.com/) - open-sorce document managment system that transforms physical documents into a searchable online archive. Can install via Cloudron.
- [ ] Pi-KVM (video-capture of home server: HDMI capture card + Raspberry Pi)

# Cloud Provider Projects
- [ ] [Deploy WordPress website in AWS](https://www.aosnote.com/offers/xFzqby9z/checkout) (use `TECHWITHLUCY` promo code at check out for 20% off)
  - [ ] Add "AWS Project. Deployed and hosted a highly-available WordPress app using EC2, RDS, Route 53, ASG, and VPC." to resume
- [ ] [Serverless Web Application on AWS](https://aws.amazon.com/getting-started/hands-on/build-serverless-web-app-lambda-apigateway-s3-dynamodb-cognito/)
- [ ] [Chat Bot Amazon Connect Call Center on AWS](https://github.com/aws-samples/amazon-lex-connect-workshop)
