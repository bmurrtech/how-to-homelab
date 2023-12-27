# JupyterLab Setup

### Provision JupyterLab
> This guide assumes you are have a Proxmox hypervisor already configured to spin up new VMs, but you could create with a VPS, [Docker](https://jupyter-docker-stacks.readthedocs.io/en/latest/), and more!

- Create an Ubuntu VM to host your Jupyter Lab

> I went with an Ubuntu Desktop, but you could use [Ubuntu 22.04 server on a baremetal server VPS](https://docs.vultr.com/how-to-set-up-a-jupyterlab-environment-on-ubuntu-22-04) for example (just take special note of the the `virtualenv` section if you go the server route). If you choose to go with an Unbuntu server, deploy using my using [cloud-init guide](https://github.com/bmurrtech/how-to-homelab/blob/main/how-to_ultimate_proxmox.md#cloud-init-template) (much faster deployment, trust me, it's worth setting up in Proxmox!). 

### JupyterLab `pip` Install Method
> Jupyter Lab KB ref.: https://jupyterlab.readthedocs.io/en/stable/getting_started/installation.html

- Open a terminal and run:
```
pip install jupyterlab
```

### Start JupyterLab
- In a terminal window run:

```
jupyter lab
```
- JupyterLab will open automatically in your browser.

![JupyterLabinabrowser](https://i.imgur.com/k81QlMH.png)

- The default workspace is in the main `/lab` URL: `http(s)://<server:port>/<lab-location>/lab`

### Set Your Wokring Directory
> JupyterLab's suggests: "If your notebook files are not in the current directory, you can pass your working directory path as argument when starting JupyterLab. Avoid running it from your root volume (e.g. C:\ on Windows or / on Linux) to limit the risk of modifying system files."

- Set you preferred directory
```
#Windows Example
jupyter lab --notebook-dir=E:/ --preferred-dir E:/Documents/Somewhere/Else
#Linux Example
jupyter lab --notebook-dir=/var/ --preferred-dir /var/www/html/example-app/
```

Fin

# GitHub in JupyterLab

### Install Git with `pip`

![installinggittojl](https://i.imgur.com/DgvkAUh.png)

- To install, open a terminal and enter:

```
pip install --upgrade jupyterlab jupyterlab-git
```

- After the command runs, simply close the JupyterLab from the browser tab and re-run the following in terminal to relaunch:

```
jupyter lab
```

- End result: You should now see the "Git" tab and icon in your JupyterLab environment.

### Initialize a Repository to GitHub

- Create a new folder at `/your/path/`

![](https://i.imgur.com/A9LXy51.png)

- Create a new notebook (Python3) by right-clicking and selecting New Notebook.

![](https://i.imgur.com/2xJy5Fr.png)

- Rename your notebook (right-click > rename)
- Enter some placeholder text/code you push to your GitHub (testing purposes).

![](https://i.imgur.com/08PNPCR.png)

- Initialize this as a Repository: Git (tab) > Initialize a Repository

![](https://i.imgur.com/WrVYb5v.png)

- When prompted, choose `Yes` to Initialize as a Repository.

- Login to your GitHub account: https://github.com/login

WIP
