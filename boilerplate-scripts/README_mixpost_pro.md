# Mixpost Pro Deployment Script

A universal, cloud-agnostic deployment script for [Mixpost Pro](https://mixpost.app) that works on any Ubuntu VM.

## Quick Start

### 1. Download and Run (One Command)

> **Note:** Replace `YOUR_USERNAME` with your actual GitHub username or organization in the URLs below.

```bash
wget -O deploy_mixpost_pro.sh https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_FILE_DESTINATION/main/scripts/deploy_mixpost_pro.sh && chmod +x deploy_mixpost_pro.sh && ./deploy_mixpost_pro.sh
```

### 2. Step by Step

```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_FILE_DESTINATION/main/scripts/deploy_mixpost_pro.sh

# Make it executable
chmod +x deploy_mixpost_pro.sh

# Run with basic setup (interactive prompts for all required info)
./deploy_mixpost_pro.sh

# Or with S3 storage
./deploy_mixpost_pro.sh --s3

# Or with S3 and SSL
./deploy_mixpost_pro.sh --s3 --ssl

# For a clean reinstall (removes all data/volumes)
./deploy_mixpost_pro.sh --force
```

## Features

### 🌍 **Cloud-Agnostic Design**
- Works on any Ubuntu VM (AWS, GCP, Azure, DigitalOcean, etc.)
- No cloud-specific dependencies
- Universal wget download approach

### 🔧 **Advanced Configuration Options**
- `--s3` flag for S3 storage configuration
- `--ssl` flag for automatic SSL/TLS setup
- `--force` or `--reinstall` flag for a clean reinstall (removes all data/volumes)
- Pro-specific environment variables
- Interactive prompts with smart defaults for all required values

### 🔒 **Security Features**
- Auto-generated secure passwords
- UFW firewall configuration
- SSL certificate automation via Traefik
- Proper secret handling
- Sensitive data (like license key, DB password) is stored in `.env` (protect this file!)

### 📦 **Pro Features Support**
- License key validation (script will check and report issues)
- SMTP configuration for Pro features
- Two-factor authentication
- API access tokens
- Forgot password functionality

## Requirements

### Server Requirements
- **Operating System**: Ubuntu 18.04+ (tested on 20.04, 22.04)
- **CPU**: Minimum 2 cores
- **RAM**: Minimum 4GB
- **Storage**: Minimum 20GB free space
- **Network**: Internet access for downloading packages and Docker images

### Prerequisites
- **Sudo Access**: Script requires sudo privileges for system operations. Run as a sudo-enabled user.
- **Valid License**: Mixpost Pro license key (required, will be validated during setup)

### Cloud Provider Compatibility
This script works on any cloud provider or bare metal server:
- ✅ AWS EC2
- ✅ Google Cloud Compute Engine
- ✅ Microsoft Azure VMs
- ✅ DigitalOcean Droplets
- ✅ Linode
- ✅ Vultr
- ✅ Hetzner Cloud
- ✅ OVH Cloud
- ✅ Bare metal servers

## Usage Options

### Basic Deployment
```bash
./deploy_mixpost_pro.sh
```
Deploys Mixpost Pro with:
- Local file storage
- HTTP access
- MySQL database
- Redis cache

### With S3 Storage
```bash
./deploy_mixpost_pro.sh --s3
```
Deploys with AWS S3 or S3-compatible storage for media files. The script will prompt for S3 credentials and options, including path-style URLs for S3-compatible services.

### With SSL/TLS
```bash
./deploy_mixpost_pro.sh --ssl
```
Deploys with automatic SSL certificate generation via Let's Encrypt (Traefik). The script will prompt for an email address for certificate registration.

### Full Feature Deployment
```bash
./deploy_mixpost_pro.sh --s3 --ssl
```
Deploys with both S3 storage and SSL/TLS encryption.

### Clean Reinstall
```bash
./deploy_mixpost_pro.sh --force
```
Removes all existing containers, volumes, and data for a clean install. Use with caution!

### Help
```bash
./deploy_mixpost_pro.sh --help
```
Shows all available flags and usage information.

## Configuration

### Interactive Prompts
The script will prompt you for all required configuration values. Most fields have smart defaults. You can press Enter to accept the default, or provide your own value. Sensitive fields (like passwords) are hidden during input.

### Required Information

#### License & Basic Setup
- **Mixpost Pro License Key** (required, will be validated)
- **Mixpost Account Email** (required)
- **Application Name** (default: "Mixpost")
- **Domain Name** (optional, uses server IP if not provided)

#### Database Configuration
- **Database Name** (default: "mixpost_db")
- **Database Username** (default: "mixpost_user")
- **Database Password** (auto-generated)

#### Email/SMTP Configuration
- **SMTP Host** (default: "smtp.mailgun.org")
- **SMTP Port** (default: "587")
- **SMTP Username** (optional)
- **SMTP Password** (optional)
- **SMTP Encryption** (default: "tls")
- **From Email Address**

#### S3 Configuration (if --s3 flag used)
- **AWS Access Key ID**
- **AWS Secret Access Key**
- **AWS Region** (default: "us-east-1")
- **S3 Bucket Name**
- **S3 URL** (optional, for S3-compatible services)
- **S3 Endpoint** (optional, for S3-compatible services)
- **Use path-style URLs** (prompted for S3-compatible services)

#### SSL Configuration (if --ssl flag used)
- **Email for SSL Certificate**

### Pro Features
The script enables these Mixpost Pro features by default (can be toggled during setup):
- ✅ Forgot Password
- ✅ Two-Factor Authentication
- ✅ API Access Tokens

## Post-Installation

### Access Your Installation
After successful deployment, Mixpost Pro will be accessible at:
- **HTTP**: `http://your-server-ip:9000` or `http://your-domain.com:9000`
- **HTTPS**: `https://your-domain.com` (if SSL enabled)

**Port Information:**
- **HTTP Mode**: Main application on port `9000`, WebSocket/API on port `8080`
- **HTTPS Mode**: Standard ports `80` and `443` (handled by Traefik reverse proxy)

### Initial Setup
1. Visit your Mixpost URL
2. Create your first admin user
3. Configure your social media accounts
4. Start scheduling your content!

### Management Commands

> **Note:** Always `cd ~/mixpost` before running these commands.

```bash
# View running services
cd ~/mixpost && docker compose ps

# View logs
cd ~/mixpost && docker compose logs -f

# Restart services
cd ~/mixpost && docker compose restart

# Stop services
cd ~/mixpost && docker compose down

# Update Mixpost (pull latest image)
cd ~/mixpost && docker compose pull && docker compose up -d
```

## File Locations

### Installation Directory
```
~/mixpost/                    # Main installation directory (user home)
├── .env                      # Environment configuration (contains secrets, protect this file!)
├── docker-compose.yml        # Docker services definition
└── volumes/                  # Persistent data (managed by Docker)
    ├── mysql/                # Database files
    ├── redis/                # Redis data
    ├── storage/              # Application storage
    └── logs/                 # Application logs
```

## Troubleshooting

### Sudo Access Issues
- The script requires sudo privileges. If you get permission errors, make sure your user is in the sudo group.
- If you are added to the docker group during setup, you may need to log out and back in for changes to take effect.

### Docker Compose Compatibility
- The script supports both `docker compose` and `docker-compose`. It will use sudo if required.

### License Key Issues
- A valid Mixpost Pro license key is required. The script will check and report if the license is invalid.
- If you have issues, check your license at [Mixpost Support](https://mixpost.app/support).

### Services Not Starting
- Use `docker compose logs` and `docker compose ps` to check service status.
- The script will attempt to troubleshoot and provide log output if services fail to start.

### Clean Reinstall
- Use the `--force` or `--reinstall` flag to remove all data and start fresh.

### S3 Path-Style URLs
- For S3-compatible services (like MinIO, DigitalOcean Spaces), the script will prompt if you want to use path-style URLs.

### Composer Auth
- The script creates a Composer auth file for private Mixpost Pro repository access. This file is cleaned up after the script runs.

### Sensitive Data
- The `.env` file contains all secrets and credentials. Protect this file and do not share it.

## Security Considerations

### Automatic Security Features
The script automatically configures:
- **UFW Firewall**: Enables with SSH, HTTP, and HTTPS access
- **Strong Passwords**: Auto-generated 16+ character passwords
- **Secure Keys**: All secrets generated using OpenSSL
- **Container Isolation**: Docker provides process isolation

### Firewall Rules
```bash
# Default rules applied by script
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
```

### Manual Security Hardening
Additional security steps you can take:
```bash
# Install fail2ban for SSH protection
sudo apt install fail2ban
sudo systemctl enable fail2ban

# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure SSH key authentication (disable password auth)
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart ssh
```

## Advanced Configuration

### Environment Variables
Edit `~/mixpost/.env` to customize:
```bash
# Application settings
APP_NAME=Mixpost Pro
APP_DEBUG=false
APP_URL=http://your-domain.com

# Database settings
DB_DATABASE=mixpost_db
DB_USERNAME=mixpost_user

# Redis settings
REDIS_HOST=redis
REDIS_PORT=6379
```

### Custom Domain Setup
1. Point your domain to the server IP
2. Update `APP_URL` in `.env`
3. Restart services: `docker compose restart`

### Multiple Instances
You can run multiple instances by using different directories:
```bash
# Create separate directories
mkdir ~/mixpost-staging
mkdir ~/mixpost-production

# Copy and modify configuration for each
cp -r ~/mixpost/* ~/mixpost-staging/
# Edit .env files with different settings and ports
```

## S3-Compatible Services

The script supports various S3-compatible storage services:

### AWS S3
- Leave **S3 URL** and **S3 Endpoint** blank
- Use standard AWS credentials

### DigitalOcean Spaces
- **S3 URL**: `https://nyc3.digitaloceanspaces.com` (adjust region)
- **S3 Endpoint**: `https://nyc3.digitaloceanspaces.com`
- Enable **path-style URLs** when prompted

### MinIO
- **S3 URL**: `https://your-minio-server.com`
- **S3 Endpoint**: `https://your-minio-server.com`
- Enable **path-style URLs** when prompted

### Google Cloud Storage
Configure with S3-compatible access:
- **S3 Endpoint**: `https://storage.googleapis.com`

## Docker Management

### If Docker Installation Fails
1. **Install Docker manually**:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   ```

2. **Use Docker from official repository**:
   ```bash
   sudo apt update
   sudo apt install apt-transport-https ca-certificates curl software-properties-common
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
   echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt update
   sudo apt install docker-ce docker-ce-cli containerd.io
   ```

3. **Start Docker service**:
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

## Support

### Documentation
- [Mixpost Pro Documentation](https://docs.mixpost.app/pro/)
- [Environment Variables Reference](https://docs.mixpost.app/pro/configuration/environment-variables/)
- [Docker Installation Guide](https://docs.mixpost.app/pro/installation/docker)

### Community
- [Mixpost Discord](https://discord.gg/mixpost)
- [Mixpost Facebook Group](https://facebook.com/groups/mixpost)

### Commercial Support
- [Mixpost Support Portal](https://mixpost.app/support)

## Script Features

### Professional Design
- **Robust Error Handling**: Clear error messages and recovery suggestions
- **Progress Indicators**: Visual feedback during installation
- **Smart Defaults**: Sensible configuration options
- **Production Ready**: Suitable for production deployments

### User Experience
- **Interactive Prompts**: Guided configuration process
- **Validation**: Input validation and confirmation
- **Documentation**: Comprehensive help and troubleshooting
- **Maintenance**: Easy management commands

## License

This deployment script is provided as-is. Mixpost Pro requires a valid license from [mixpost.app](https://mixpost.app).

---

**Made with ❤️ for the Mixpost community**

**Deploy with confidence! 🚀**
