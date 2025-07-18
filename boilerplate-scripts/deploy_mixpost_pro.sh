#!/usr/bin/env bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper: show usage
usage() {
    cat <<EOF
Usage: $(basename "$0") [--s3] [--ssl] [--force|--reinstall] [--help]

Deploy Mixpost Pro to any Ubuntu VM

Options:
  --s3        Enable S3 file storage and prompt for AWS credentials
  --ssl       Enable SSL/TLS with automatic certificate generation
  --force|--reinstall
              Force a clean reinstall of the application
  -h|--help   Show this help message

Examples:
  # Basic deployment
  bash $(basename "$0")
  
  # With S3 storage
  bash $(basename "$0") --s3
  
  # With S3 and SSL
  bash $(basename "$0") --s3 --ssl

EOF
}

# --- Parse command line flags
ASK_S3=false
ENABLE_SSL=false
FORCE_CLEAN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --s3)
            ASK_S3=true
            shift
            ;;
        --ssl)
            ENABLE_SSL=true
            shift
            ;;
        --force|--reinstall)
            FORCE_CLEAN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown option: $1"
            usage >&2
            exit 1
            ;;
    esac
done

# Helper functions
prompt_input() {
    local var_name="$1"
    local prompt_msg="$2"
    local secret="${3:-false}"
    local required="${4:-true}"
    local default="${5:-}"
    
    local input=""
    while true; do
        if [[ -n "$default" ]]; then
            if [[ "$secret" == true ]]; then
                read -s -p "$prompt_msg [$default]: " input
                echo
            else
                read -p "$prompt_msg [$default]: " input
            fi
            input=${input:-$default}
        else
            if [[ "$secret" == true ]]; then
                read -s -p "$prompt_msg: " input
                echo
            else
                read -p "$prompt_msg: " input
            fi
        fi

        if [[ "$required" == false ]] || [[ -n "$input" ]]; then
            break
        fi
        echo "This field is required. Please enter a value."
    done

    eval "$var_name=\"$input\""
}

prompt_yes_no() {
    local var_name="$1"
    local prompt_msg="$2"
    local default="${3:-y}"
    
    local prompt_suffix=" [y/n]: "
    if [[ "$default" == "y" ]]; then
        prompt_suffix=" [Y/n]: "
    else
        prompt_suffix=" [y/N]: "
    fi
    
    while true; do
        read -p "$prompt_msg$prompt_suffix" input
        input=${input:-$default}
        case "${input,,}" in
            y|yes) eval "$var_name=true"; break ;;
            n|no) eval "$var_name=false"; break ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

generate_random_string() {
    local length="${1:-32}"
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Script header
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}     Mixpost Pro Deployment Script       ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}This script will deploy Mixpost Pro on Ubuntu${NC}"
echo -e "${GREEN}Minimum requirements: 2 CPUs, 4GB RAM${NC}"
echo

# Check for sudo privileges
if ! sudo -v; then
    echo -e "${RED}This script requires sudo access. Please run as a sudo-enabled user.${NC}"
    exit 1
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}Warning: Running as root. This is acceptable for VMs but not recommended for shared systems.${NC}"
fi

# Check Ubuntu version
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    echo -e "${YELLOW}Warning: This script is designed for Ubuntu. Proceed with caution on other distributions.${NC}"
fi

# Update system packages
echo -e "${GREEN}📦 Updating system packages...${NC}"
sudo apt update
sudo apt upgrade -y

# Install required packages
echo -e "${GREEN}📦 Installing required packages...${NC}"
sudo apt install -y curl wget gnupg lsb-release software-properties-common ca-certificates apt-transport-https

# --- Ensure Git is installed (needed for source fallback in Composer)
if ! check_command git; then
    echo -e "${YELLOW}⚠️ Git is not installed. Installing...${NC}"
    sudo apt update && sudo apt install -y git
    echo -e "${GREEN}✅ Git installed${NC}"
else
    echo -e "${GREEN}✅ Git is already installed${NC}"
fi

# Install Docker
echo -e "${GREEN}🐳 Installing Docker...${NC}"
if ! check_command docker; then
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    echo -e "${GREEN}✅ Docker installed successfully${NC}"
else
    echo -e "${GREEN}✅ Docker already installed${NC}"
fi

# Add current user to docker group if not already added
if ! id -nG | grep -q docker; then
    echo -e "${YELLOW}⚠️ Adding current user to the docker group...${NC}"
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}⚠️ You may need to log out and back in for group changes to take effect${NC}"
    echo -e "${YELLOW}⚠️ For now, we'll continue using sudo for docker commands${NC}"
    USE_SUDO=true
else
    USE_SUDO=false
fi

# Check if Docker daemon is running and start if needed
echo -e "${GREEN}🔍 Checking Docker daemon status...${NC}"
if ! systemctl is-active --quiet docker; then
    echo -e "${YELLOW}⚠️ Docker daemon is not running. Starting Docker...${NC}"
    sudo systemctl start docker
    
    # Wait for Docker to start
    echo -e "${YELLOW}⏳ Waiting for Docker daemon to start...${NC}"
    for i in {1..30}; do
        if systemctl is-active --quiet docker; then
            echo -e "${GREEN}✅ Docker daemon started successfully${NC}"
            break
        fi
        echo -n "."
        sleep 1
        if [[ $i -eq 30 ]]; then
            echo -e "\n${RED}❌ Failed to start Docker daemon after 30 seconds${NC}"
            echo -e "${YELLOW}Please check Docker installation:${NC}"
            echo -e "  sudo systemctl status docker"
            echo -e "  sudo journalctl -u docker.service"
            exit 1
        fi
    done
else
    echo -e "${GREEN}✅ Docker daemon is running${NC}"
fi

# Verify Docker is accessible
echo -e "${GREEN}🧪 Testing Docker access...${NC}"
if docker info >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker is accessible without sudo${NC}"
    USE_SUDO=false
elif sudo docker info >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ Docker requires sudo access${NC}"
    USE_SUDO=true
else
    echo -e "${RED}❌ Cannot access Docker daemon${NC}"
    echo -e "${YELLOW}Troubleshooting steps:${NC}"
    echo -e "  1. Check if Docker is running: sudo systemctl status docker"
    echo -e "  2. Restart Docker: sudo systemctl restart docker"
    echo -e "  3. Check Docker socket permissions: ls -la /var/run/docker.sock"
    echo -e "  4. Add user to docker group: sudo usermod -aG docker \$USER"
    echo -e "  5. Log out and back in, then try again"
    exit 1
fi

# Configure firewall
echo -e "${GREEN}🔥 Configuring firewall...${NC}"
if check_command ufw; then
    sudo ufw --force enable
    sudo ufw allow 22/tcp  # SSH
    sudo ufw allow 80/tcp  # HTTP
    sudo ufw allow 443/tcp # HTTPS
    echo -e "${GREEN}✅ Firewall configured${NC}"
fi

# Get server IP
PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "localhost")
echo -e "${GREEN}📍 Detected public IP: $PUBLIC_IP${NC}"

# Collect configuration
echo -e "${GREEN}🔧 Collecting Mixpost Pro configuration...${NC}"

# License key (required for Pro)
prompt_input LICENSE_KEY "Enter your Mixpost Pro license key" true true
prompt_input LICENSE_EMAIL "Enter your Mixpost account email" false true

# Basic app configuration
prompt_input APP_NAME "Enter application name" false true "Mixpost"
prompt_input APP_DOMAIN "Enter your domain (or leave blank to use IP)" false false "$PUBLIC_IP"

if [[ -z "$APP_DOMAIN" ]]; then
    APP_DOMAIN="$PUBLIC_IP"
fi

# SSL configuration
if [[ "$ENABLE_SSL" == true ]]; then
    APP_URL="https://$APP_DOMAIN"
    prompt_input SSL_EMAIL "Enter email for SSL certificate" false true
else
    APP_URL="http://$APP_DOMAIN:9000"
fi

# Generate secure keys
APP_KEY="base64:$(openssl rand -base64 32)"
DB_PASSWORD=$(generate_random_string 16)
REDIS_PASSWORD=$(generate_random_string 16)

echo -e "${GREEN}🔑 Generated secure keys automatically${NC}"

# Database configuration
prompt_input DB_DATABASE "Database name" false true "mixpost_db"
prompt_input DB_USERNAME "Database username" false true "mixpost_user"

# SMTP configuration
echo -e "${GREEN}📧 SMTP Configuration (required for Pro features)${NC}"
prompt_input MAIL_HOST "SMTP host" false true "smtp.mailgun.org"
prompt_input MAIL_PORT "SMTP port" false true "587"
prompt_input MAIL_USERNAME "SMTP username" false false
prompt_input MAIL_PASSWORD "SMTP password" true false
prompt_input MAIL_ENCRYPTION "SMTP encryption (tls/ssl)" false true "tls"
prompt_input MAIL_FROM_ADDRESS "From email address" false true "hello@$APP_DOMAIN"

# S3 configuration (if --s3 flag provided)
if [[ "$ASK_S3" == true ]]; then
    echo -e "${GREEN}☁️ S3 Storage Configuration${NC}"
    MIXPOST_DISK="s3"
    prompt_input AWS_ACCESS_KEY_ID "AWS Access Key ID" false true
    prompt_input AWS_SECRET_ACCESS_KEY "AWS Secret Access Key" true true
    prompt_input AWS_DEFAULT_REGION "AWS Region" false true "us-east-1"
    prompt_input AWS_BUCKET "S3 Bucket name" false true
    prompt_input AWS_URL "S3 URL (leave blank for AWS)" false false
    prompt_input AWS_ENDPOINT "S3 Endpoint (leave blank for AWS)" false false
    
    prompt_yes_no AWS_USE_PATH_STYLE "Use path-style URLs" "n"
    if [[ "$AWS_USE_PATH_STYLE" == true ]]; then
        AWS_USE_PATH_STYLE_ENDPOINT="true"
    else
        AWS_USE_PATH_STYLE_ENDPOINT="false"
    fi
else
    MIXPOST_DISK="public"
fi

# Additional Pro features
echo -e "${GREEN}⚙️ Additional Pro Features${NC}"
prompt_yes_no MIXPOST_FORGOT_PASSWORD "Enable forgot password feature" "y"
prompt_yes_no MIXPOST_TWO_FACTOR_AUTH "Enable two-factor authentication" "y"
prompt_yes_no MIXPOST_API_ACCESS_TOKENS "Enable API access tokens" "y"

# Convert boolean responses
[[ "$MIXPOST_FORGOT_PASSWORD" == true ]] && MIXPOST_FORGOT_PASSWORD="true" || MIXPOST_FORGOT_PASSWORD="false"
[[ "$MIXPOST_TWO_FACTOR_AUTH" == true ]] && MIXPOST_TWO_FACTOR_AUTH="true" || MIXPOST_TWO_FACTOR_AUTH="false"
[[ "$MIXPOST_API_ACCESS_TOKENS" == true ]] && MIXPOST_API_ACCESS_TOKENS="true" || MIXPOST_API_ACCESS_TOKENS="false"

# Create project directory
WORKDIR="$HOME/mixpost"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo -e "${GREEN}📝 Creating configuration files...${NC}"

# Create .env file
cat > .env <<EOF
# License (required for Mixpost Pro)
LICENSE_KEY=$LICENSE_KEY

# Application Configuration
APP_NAME=$APP_NAME
APP_KEY=$APP_KEY
APP_DEBUG=false
APP_DOMAIN=$APP_DOMAIN
APP_URL=$APP_URL

# Mixpost Configuration
MIXPOST_DEFAULT_LOCALE=en-GB
MIXPOST_CORE_PATH=mixpost
MIXPOST_PUBLIC_PAGES_PREFIX=pages

# Database Configuration
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=$DB_DATABASE
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD

# Redis Configuration
REDIS_HOST=redis
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_PORT=6379

# Queue Configuration
QUEUE_CONNECTION=redis
HORIZON_REDIS_CONNECTION=default

# Broadcasting Configuration
BROADCAST_DRIVER=reverb
REVERB_APP_ID=mixpost
REVERB_APP_KEY=mixpost-key
REVERB_APP_SECRET=mixpost-secret
REVERB_HOST=localhost
REVERB_PORT=8080
REVERB_SCHEME=http

# Features
MIXPOST_FORGOT_PASSWORD=$MIXPOST_FORGOT_PASSWORD
MIXPOST_TWO_FACTOR_AUTH=$MIXPOST_TWO_FACTOR_AUTH
MIXPOST_API_ACCESS_TOKENS=$MIXPOST_API_ACCESS_TOKENS
MIXPOST_AUTO_SUBSCRIBE_POST_ACTIVITIES=false

# SMTP Configuration
MAIL_MAILER=smtp
MAIL_HOST=$MAIL_HOST
MAIL_PORT=$MAIL_PORT
MAIL_USERNAME=$MAIL_USERNAME
MAIL_PASSWORD=$MAIL_PASSWORD
MAIL_ENCRYPTION=$MAIL_ENCRYPTION
MAIL_FROM_ADDRESS=$MAIL_FROM_ADDRESS
MAIL_FROM_NAME=\${APP_NAME}

# File Storage
MIXPOST_DISK=$MIXPOST_DISK
FILESYSTEM_DISK=local

# Session and Cache
SESSION_DRIVER=redis
CACHE_DRIVER=redis

# Logging
LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug
EOF

# Add S3 configuration if enabled
if [[ "$ASK_S3" == true ]]; then
    cat >> .env <<EOF

# S3 Configuration
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
AWS_BUCKET=$AWS_BUCKET
AWS_URL=$AWS_URL
AWS_ENDPOINT=$AWS_ENDPOINT
AWS_USE_PATH_STYLE_ENDPOINT=$AWS_USE_PATH_STYLE_ENDPOINT
EOF
fi

# Add SSL configuration if enabled
if [[ "$ENABLE_SSL" == true ]]; then
    cat >> .env <<EOF

# SSL Configuration
SSL_EMAIL=$SSL_EMAIL
EOF
fi

# --- Setup Composer Auth for Mixpost Pro private repository
echo -e "${GREEN}🔐 Configuring Composer authentication for Mixpost Pro...${NC}"
mkdir -p ~/.composer
cat > ~/.composer/auth.json <<EOF
{
  "http-basic": {
    "packages.inovector.com": {
      "username": "$LICENSE_EMAIL",
      "password": "$LICENSE_KEY"
    }
  }
}
EOF
echo -e "${GREEN}✅ Composer authentication configured${NC}"
# Secure the Composer auth file
chmod 600 ~/.composer/auth.json
# Clean up Composer auth file on exit
trap 'rm -f ~/.composer/auth.json' EXIT

# Create docker-compose.yml based on SSL choice
if [[ "$ENABLE_SSL" == true ]]; then
    echo -e "${GREEN}📄 Creating Docker Compose file with SSL support...${NC}"
    # NOTE: For stability, you can pin the Mixpost image version, e.g. image: inovector/mixpost-pro-team:1.3.0
    # NOTE: If you need git inside the container for Composer, build a custom image:
    #   Dockerfile:
    #     FROM inovector/mixpost-pro-team:latest
    #     RUN apt update && apt install -y git
    #   Then in docker-compose.yml:
    #     image: your-custom/mixpost-with-git
    #     build:
    #       context: .
    #       dockerfile: Dockerfile
    cat > docker-compose.yml <<EOF
services:
    traefik:
      image: "traefik"
      restart: unless-stopped
      command:
        - "--api=true"
        - "--api.insecure=true"
        - "--providers.docker=true"
        - "--providers.docker.exposedbydefault=false"
        - "--entrypoints.web.address=:80"
        - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
        - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
        - "--entrypoints.websecure.address=:443"
        - "--certificatesresolvers.mytlschallenge.acme.tlschallenge=true"
        - "--certificatesresolvers.mytlschallenge.acme.email=\${SSL_EMAIL}"
        - "--certificatesresolvers.mytlschallenge.acme.storage=/letsencrypt/acme.json"
      ports:
        - "80:80"
        - "443:443"
      volumes:
        - traefik_data:/letsencrypt
        - /var/run/docker.sock:/var/run/docker.sock:ro
    mixpost:
        image: inovector/mixpost-pro-team:latest
        env_file:
            - .env
        # Inject Composer auth for private repo access
        environment:
          COMPOSER_AUTH: >
            {"http-basic": {"packages.inovector.com": {"username": "${LICENSE_EMAIL}", "password": "${LICENSE_KEY}"}}}
        labels:
          - traefik.enable=true
          - traefik.http.routers.mixpost.rule=Host(`\${APP_DOMAIN}`)
          - traefik.http.routers.mixpost.tls=true
          - traefik.http.routers.mixpost.entrypoints=web,websecure
          - traefik.http.routers.mixpost.tls.certresolver=mytlschallenge
          - traefik.http.middlewares.mixpost.headers.SSLRedirect=true
          - traefik.http.middlewares.mixpost.headers.STSSeconds=315360000
          - traefik.http.middlewares.mixpost.headers.browserXSSFilter=true
          - traefik.http.middlewares.mixpost.headers.contentTypeNosniff=true
          - traefik.http.middlewares.mixpost.headers.forceSTSHeader=true
          - traefik.http.middlewares.mixpost.headers.SSLHost=`\${APP_DOMAIN}`
          - traefik.http.middlewares.mixpost.headers.STSIncludeSubdomains=true
          - traefik.http.middlewares.mixpost.headers.STSPreload=true
          - traefik.http.routers.mixpost.middlewares=mixpost@docker
        volumes:
            - storage:/var/www/html/storage/app
        depends_on:
            - mysql
            - redis 
        restart: unless-stopped
    mysql:
        image: 'mysql/mysql-server:8.0'
        environment:
            MYSQL_DATABASE: \${DB_DATABASE}
            MYSQL_USER: \${DB_USERNAME}
            MYSQL_PASSWORD: \${DB_PASSWORD}
            MYSQL_ROOT_PASSWORD: \${DB_PASSWORD}
        volumes:
            - 'mysql:/var/lib/mysql'
        healthcheck:
            test: ["CMD", "mysqladmin", "ping", "-p \${DB_PASSWORD}"]
            retries: 3
            timeout: 5s
        restart: unless-stopped
    redis:
        image: 'redis:latest'
        command: redis-server --appendonly yes --replica-read-only no --requirepass \${REDIS_PASSWORD}
        volumes:
            - 'redis:/data'
        healthcheck:
            test: ["CMD", "redis-cli", "-a", "\${REDIS_PASSWORD}", "ping"]
            retries: 3
            timeout: 5s
        restart: unless-stopped  

volumes:
    traefik_data:
      driver: local
    mysql:
        driver: local
    redis:
        driver: local
    storage:
        driver: local
EOF
else
    echo -e "${GREEN}📄 Creating Docker Compose file without SSL...${NC}"
    # NOTE: For stability, you can pin the Mixpost image version, e.g. image: inovector/mixpost-pro-team:1.3.0
    # NOTE: If you need git inside the container for Composer, build a custom image:
    #   Dockerfile:
    #     FROM inovector/mixpost-pro-team:latest
    #     RUN apt update && apt install -y git
    #   Then in docker-compose.yml:
    #     image: your-custom/mixpost-with-git
    #     build:
    #       context: .
    #       dockerfile: Dockerfile
    cat > docker-compose.yml <<EOF
services:
    mixpost:
        image: inovector/mixpost-pro-team:latest
        env_file:
            - .env
        # Inject Composer auth for private repo access
        environment:
          COMPOSER_AUTH: >
            {"http-basic": {"packages.inovector.com": {"username": "${LICENSE_EMAIL}", "password": "${LICENSE_KEY}"}}}
        ports:
            - 9000:80
            - 8080:8080
        volumes:
            - storage:/var/www/html/storage/app
        depends_on:
            - mysql
            - redis 
        restart: unless-stopped
    mysql:
        image: 'mysql/mysql-server:8.0'
        environment:
            MYSQL_DATABASE: \${DB_DATABASE}
            MYSQL_USER: \${DB_USERNAME}
            MYSQL_PASSWORD: \${DB_PASSWORD}
            MYSQL_ROOT_PASSWORD: \${DB_PASSWORD}
        volumes:
            - 'mysql:/var/lib/mysql'
        healthcheck:
            test: ["CMD", "mysqladmin", "ping", "-p \${DB_PASSWORD}"]
            retries: 3
            timeout: 5s
        restart: unless-stopped
    redis:
        image: 'redis:latest'
        command: redis-server --appendonly yes --replica-read-only no --requirepass \${REDIS_PASSWORD}
        volumes:
            - 'redis:/data'
        healthcheck:
            test: ["CMD", "redis-cli", "-a", "\${REDIS_PASSWORD}", "ping"]
            retries: 3
            timeout: 5s
        restart: unless-stopped  

volumes:
    mysql:
        driver: local
    redis:
        driver: local
    storage:
        driver: local
EOF
fi

# Deploy Mixpost Pro
echo -e "${GREEN}🚀 Deploying Mixpost Pro...${NC}"

# Final check that Docker is working before deployment
echo -e "${GREEN}🔄 Final Docker verification...${NC}"
if [[ "$USE_SUDO" == true ]]; then
    if ! sudo docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker daemon not accessible with sudo. Attempting to restart...${NC}"
        sudo systemctl restart docker
        sleep 10
        if ! sudo docker info >/dev/null 2>&1; then
            echo -e "${RED}❌ Docker still not working. Please check Docker installation.${NC}"
            exit 1
        fi
    fi
else
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker daemon not accessible. Attempting to restart...${NC}"
        sudo systemctl restart docker
        sleep 10
        if ! docker info >/dev/null 2>&1; then
            echo -e "${RED}❌ Docker still not working. Please check Docker installation.${NC}"
            exit 1
        fi
    fi
fi

# Determine docker compose command
if [[ "$USE_SUDO" == true ]]; then
    # Check which version of docker-compose is available
    if sudo docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="sudo docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="sudo docker-compose"
    else
        echo -e "${RED}Neither 'docker compose' nor 'docker-compose' found. Please install Docker Compose.${NC}"
        exit 1
    fi
else
    # Check which version of docker-compose is available
    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        echo -e "${RED}Neither 'docker compose' nor 'docker-compose' found. Please install Docker Compose.${NC}"
        exit 1
    fi
fi

# Clean up any existing containers and networks to prevent conflicts
echo -e "${YELLOW}🧹 Cleaning up existing containers and networks...${NC}"
$DOCKER_COMPOSE_CMD down --remove-orphans 2>/dev/null || echo "No existing containers to remove"

# Remove any dangling images and containers that might cause conflicts
if [[ "$USE_SUDO" == true ]]; then
    sudo docker system prune -f 2>/dev/null || echo "Docker system prune failed"
    sudo docker volume ls -q | grep mixpost | xargs -r sudo docker volume rm 2>/dev/null || echo "No mixpost volumes to remove"
    # If --force is set, remove all volumes/data
    if [[ "$FORCE_CLEAN" == true ]]; then
        echo -e "${YELLOW}⚠️ --force flag detected: Removing ALL Docker volumes and data for a clean install...${NC}"
        sudo docker volume prune -f
        sudo docker system prune -a -f --volumes
    fi
else
    docker system prune -f 2>/dev/null || echo "Docker system prune failed"
    docker volume ls -q | grep mixpost | xargs -r docker volume rm 2>/dev/null || echo "No mixpost volumes to remove"
    if [[ "$FORCE_CLEAN" == true ]]; then
        echo -e "${YELLOW}⚠️ --force flag detected: Removing ALL Docker volumes and data for a clean install...${NC}"
        docker volume prune -f
        docker system prune -a -f --volumes
    fi
fi

# Pull images and start services
echo -e "${GREEN}📥 Pulling Docker images...${NC}"
if ! $DOCKER_COMPOSE_CMD pull; then
    echo -e "${RED}❌ Failed to pull Docker images. Retrying...${NC}"
    sleep 5
    if ! $DOCKER_COMPOSE_CMD pull; then
        echo -e "${RED}❌ Failed to pull images after retry. Check your internet connection.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}🚀 Starting services...${NC}"
if ! $DOCKER_COMPOSE_CMD up -d; then
    echo -e "${RED}❌ Failed to start services. Attempting cleanup and retry...${NC}"
    
    # Additional cleanup
    $DOCKER_COMPOSE_CMD down --volumes --remove-orphans 2>/dev/null || true
    
    # Wait a moment
    sleep 5
    
    # Try with newer Docker Compose syntax if available
    if [[ "$USE_SUDO" == true ]]; then
        if sudo docker compose version >/dev/null 2>&1; then
            echo -e "${YELLOW}Trying with 'docker compose' instead of 'docker-compose'...${NC}"
            if ! sudo docker compose up -d; then
                echo -e "${RED}❌ Failed to start services with both commands. Check logs above.${NC}"
                exit 1
            fi
        else
            echo -e "${RED}❌ Failed to start services. Please check the error messages above.${NC}"
            exit 1
        fi
    else
        if docker compose version >/dev/null 2>&1; then
            echo -e "${YELLOW}Trying with 'docker compose' instead of 'docker-compose'...${NC}"
            if ! docker compose up -d; then
                echo -e "${RED}❌ Failed to start services with both commands. Check logs above.${NC}"
                exit 1
            fi
        else
            echo -e "${RED}❌ Failed to start services. Please check the error messages above.${NC}"
            exit 1
        fi
    fi
fi

echo -e "${GREEN}✅ Services started successfully!${NC}"

# Wait for services to be ready
echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
sleep 30

# Initialize the application
echo -e "${GREEN}🔧 Initializing Mixpost Pro application...${NC}"

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
for i in {1..30}; do
    if $DOCKER_COMPOSE_CMD exec -T mysql mysqladmin ping -p"$DB_PASSWORD" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Database is ready${NC}"
        break
    fi
    echo -n "."
    sleep 2
    if [[ $i -eq 30 ]]; then
        echo -e "\n${RED}❌ Database failed to become ready${NC}"
        echo -e "${YELLOW}Checking database logs...${NC}"
        $DOCKER_COMPOSE_CMD logs mysql
        exit 1
    fi
done

# Wait for Redis to be ready
echo -e "${YELLOW}Waiting for Redis to be ready...${NC}"
for i in {1..15}; do
    if $DOCKER_COMPOSE_CMD exec -T redis redis-cli ping >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis is ready${NC}"
        break
    fi
    echo -n "."
    sleep 2
    if [[ $i -eq 15 ]]; then
        echo -e "\n${RED}❌ Redis failed to become ready${NC}"
        echo -e "${YELLOW}Checking Redis logs...${NC}"
        $DOCKER_COMPOSE_CMD logs redis
        exit 1
    fi
done

# Check Mixpost container logs first
echo -e "${YELLOW}Checking Mixpost container startup logs...${NC}"
$DOCKER_COMPOSE_CMD logs mixpost | tail -20

# Test database connection from Mixpost
echo -e "${YELLOW}Testing database connection from Mixpost...${NC}"
DB_TEST=$($DOCKER_COMPOSE_CMD exec -T mixpost php -r "
try {
    \$pdo = new PDO('mysql:host=mysql;port=3306;dbname=$DB_DATABASE', '$DB_USERNAME', '$DB_PASSWORD');
    echo 'Database connection: SUCCESS';
} catch (Exception \$e) {
    echo 'Database connection: FAILED - ' . \$e->getMessage();
}
" 2>/dev/null || echo "FAILED to test database connection")
echo -e "Database test result: $DB_TEST"

# Test Redis connection from Mixpost
echo -e "${YELLOW}Testing Redis connection from Mixpost...${NC}"
REDIS_TEST=$($DOCKER_COMPOSE_CMD exec -T mixpost php -r "
try {
    \$redis = new Redis();
    \$redis->connect('redis', 6379);
    if ('$REDIS_PASSWORD') {
        \$redis->auth('$REDIS_PASSWORD');
    }
    \$redis->ping();
    echo 'Redis connection: SUCCESS';
} catch (Exception \$e) {
    echo 'Redis connection: FAILED - ' . \$e->getMessage();
}
" 2>/dev/null || echo "FAILED to test Redis connection")
echo -e "Redis test result: $REDIS_TEST"

# Check if license key is valid
echo -e "${YELLOW}Validating license key...${NC}"
LICENSE_CHECK=$($DOCKER_COMPOSE_CMD exec -T mixpost php artisan about 2>/dev/null | grep -i "license\|mixpost" || echo "License check failed")
echo -e "License check: $LICENSE_CHECK"

# Check environment variables
echo -e "${YELLOW}Checking critical environment variables...${NC}"
ENV_CHECK=$($DOCKER_COMPOSE_CMD exec -T mixpost php -r "
echo 'APP_KEY: ' . (getenv('APP_KEY') ? 'SET' : 'NOT SET') . PHP_EOL;
echo 'LICENSE_KEY: ' . (getenv('LICENSE_KEY') ? 'SET' : 'NOT SET') . PHP_EOL;
echo 'DB_HOST: ' . getenv('DB_HOST') . PHP_EOL;
echo 'REDIS_HOST: ' . getenv('REDIS_HOST') . PHP_EOL;
echo 'QUEUE_CONNECTION: ' . getenv('QUEUE_CONNECTION') . PHP_EOL;
" 2>/dev/null || echo "Environment check failed")
echo -e "$ENV_CHECK"

# Clear caches and optimize
echo -e "${YELLOW}Clearing application caches...${NC}"
$DOCKER_COMPOSE_CMD exec -T mixpost php artisan config:clear 2>/dev/null || echo "Config clear failed"
$DOCKER_COMPOSE_CMD exec -T mixpost php artisan cache:clear 2>/dev/null || echo "Cache clear failed"
$DOCKER_COMPOSE_CMD exec -T mixpost php artisan view:clear 2>/dev/null || echo "View clear failed"

# Run database migrations
echo -e "${YELLOW}Running database migrations...${NC}"
MIGRATION_OUTPUT=$($DOCKER_COMPOSE_CMD exec -T mixpost php artisan migrate --force 2>&1 || echo "Migration failed")
echo -e "Migration result: $MIGRATION_OUTPUT"

# Try to check specific Laravel commands that Horizon/Reverb need
echo -e "${YELLOW}Testing Laravel queue system...${NC}"
QUEUE_TEST=$($DOCKER_COMPOSE_CMD exec -T mixpost php artisan queue:work --once --timeout=10 2>&1 || echo "Queue test failed")
echo -e "Queue test result: $QUEUE_TEST"

# Check Horizon configuration
echo -e "${YELLOW}Checking Horizon configuration...${NC}"
HORIZON_CONFIG=$($DOCKER_COMPOSE_CMD exec -T mixpost php artisan horizon:publish 2>&1 || echo "Horizon config failed")
echo -e "Horizon config: $HORIZON_CONFIG"

# Optimize application
echo -e "${YELLOW}Optimizing application...${NC}"
$DOCKER_COMPOSE_CMD exec -T mixpost php artisan config:cache 2>/dev/null || echo "Config cache failed"

# Get detailed error logs before restarting services
echo -e "${YELLOW}Getting detailed supervisor logs...${NC}"
$DOCKER_COMPOSE_CMD exec -T mixpost supervisorctl status 2>/dev/null || echo "Supervisor status failed"

# Check individual service logs
echo -e "${YELLOW}Checking Horizon error logs...${NC}"
$DOCKER_COMPOSE_CMD exec -T mixpost tail -20 /var/log/supervisor/horizon_00-stderr.log 2>/dev/null || echo "No Horizon error logs found"

echo -e "${YELLOW}Checking Reverb error logs...${NC}"
$DOCKER_COMPOSE_CMD exec -T mixpost tail -20 /var/log/supervisor/reverb_00-stderr.log 2>/dev/null || echo "No Reverb error logs found"

# Try to start services manually to see detailed errors
echo -e "${YELLOW}Testing Horizon manually...${NC}"
HORIZON_MANUAL=$($DOCKER_COMPOSE_CMD exec -T mixpost timeout 10 php artisan horizon 2>&1 || echo "Horizon manual test failed")
echo -e "Horizon manual test: $HORIZON_MANUAL"

# Restart supervisord services to ensure they pick up the new configuration
echo -e "${YELLOW}Restarting background services...${NC}"
$DOCKER_COMPOSE_CMD exec -T mixpost supervisorctl restart all 2>/dev/null || echo "Supervisor restart failed"

# Check if services are running
if $DOCKER_COMPOSE_CMD ps | grep -q "running"; then
    echo -e "${GREEN}✅ Services are running successfully!${NC}"
else
    echo -e "${RED}❌ Some services may not be running properly. Checking logs...${NC}"
    $DOCKER_COMPOSE_CMD logs --tail=20
fi

# Validate Mixpost container health
echo -e "${GREEN}🔍 Validating Mixpost container health...${NC}"
sleep 10

# Check if Horizon and Reverb are running properly
echo -e "${YELLOW}Checking background services...${NC}"
HORIZON_STATUS=$($DOCKER_COMPOSE_CMD exec -T mixpost supervisorctl status horizon_00 2>/dev/null || echo "FAILED")
REVERB_STATUS=$($DOCKER_COMPOSE_CMD exec -T mixpost supervisorctl status reverb_00 2>/dev/null || echo "FAILED")

if [[ "$HORIZON_STATUS" == *"RUNNING"* ]]; then
    echo -e "${GREEN}✅ Horizon (background jobs) is running${NC}"
else
    echo -e "${RED}❌ Horizon (background jobs) is not running properly${NC}"
    echo -e "${YELLOW}Checking Horizon logs...${NC}"
    $DOCKER_COMPOSE_CMD exec -T mixpost supervisorctl tail horizon_00 2>/dev/null || echo "Could not fetch Horizon logs"
fi

if [[ "$REVERB_STATUS" == *"RUNNING"* ]]; then
    echo -e "${GREEN}✅ Reverb (WebSocket server) is running${NC}"
else
    echo -e "${RED}❌ Reverb (WebSocket server) is not running properly${NC}"
    echo -e "${YELLOW}Checking Reverb logs...${NC}"
    $DOCKER_COMPOSE_CMD exec -T mixpost supervisorctl tail reverb_00 2>/dev/null || echo "Could not fetch Reverb logs"
fi

# Validate database connection
echo -e "${YELLOW}Checking database connection...${NC}"
DB_CHECK=$($DOCKER_COMPOSE_CMD exec -T mixpost php artisan migrate:status 2>/dev/null || echo "FAILED")
if [[ "$DB_CHECK" == *"Migration table not found"* ]] || [[ "$DB_CHECK" == "FAILED" ]]; then
    echo -e "${YELLOW}⚠️ Database migrations may not be complete. Running migrations...${NC}"
    $DOCKER_COMPOSE_CMD exec -T mixpost php artisan migrate --force 2>/dev/null || echo "Migration failed"
else
    echo -e "${GREEN}✅ Database connection is working${NC}"
fi

# Check application key
echo -e "${YELLOW}Validating application configuration...${NC}"
APP_KEY_CHECK=$($DOCKER_COMPOSE_CMD exec -T mixpost php artisan key:check 2>/dev/null || echo "FAILED")
if [[ "$APP_KEY_CHECK" == "FAILED" ]]; then
    echo -e "${YELLOW}⚠️ Application key may need regeneration...${NC}"
    $DOCKER_COMPOSE_CMD exec -T mixpost php artisan key:generate --force 2>/dev/null || echo "Key generation failed"
fi

# If services are failing, provide troubleshooting steps
if [[ "$HORIZON_STATUS" != *"RUNNING"* ]] || [[ "$REVERB_STATUS" != *"RUNNING"* ]]; then
    echo -e "\n${YELLOW}🔧 Troubleshooting Steps:${NC}"
    echo -e "1. Check detailed logs: cd $WORKDIR && $DOCKER_COMPOSE_CMD logs mixpost"
    echo -e "2. Restart failed services: $DOCKER_COMPOSE_CMD exec mixpost supervisorctl restart horizon_00 reverb_00"
    echo -e "3. Check environment: $DOCKER_COMPOSE_CMD exec mixpost php artisan config:show"
    echo -e "4. Validate license: $DOCKER_COMPOSE_CMD exec mixpost php artisan about"
    echo -e "\n${YELLOW}If issues persist, the license key may be invalid or there may be configuration errors.${NC}"
fi

# Display completion info
echo -e "\n${GREEN}🎉 Mixpost Pro deployment completed!${NC}"
echo -e "\n${GREEN}📋 Access Information:${NC}"
echo -e "  🌐 URL: $APP_URL"
echo -e "  📧 Admin setup: Visit the URL above to create your first admin user"

if [[ "$ENABLE_SSL" == false ]]; then
    echo -e "  🔌 Main app port: 9000 (HTTP)"
    echo -e "  🔌 Additional port: 8080 (WebSocket/API)"
fi

if [[ "$ASK_S3" == true ]]; then
    echo -e "  ☁️ S3 Storage: Configured for bucket '$AWS_BUCKET'"
fi

echo -e "\n${GREEN}🛠️ Management Commands:${NC}"
echo -e "  📍 Project directory: $WORKDIR"
echo -e "  🔄 Restart services: cd $WORKDIR && $DOCKER_COMPOSE_CMD restart"
echo -e "  🛑 Stop services: cd $WORKDIR && $DOCKER_COMPOSE_CMD down"
echo -e "  📋 View logs: cd $WORKDIR && $DOCKER_COMPOSE_CMD logs -f"
echo -e "  📊 Check status: cd $WORKDIR && $DOCKER_COMPOSE_CMD ps"

echo -e "\n${GREEN}🔧 Database Information:${NC}"
echo -e "  🗄️ Database: $DB_DATABASE"
echo -e "  👤 Username: $DB_USERNAME"
echo -e "  🔑 Password: [Generated securely]"

if [[ "$ENABLE_SSL" == true ]]; then
    echo -e "\n${GREEN}🔒 SSL Information:${NC}"
    echo -e "  📧 Certificate email: $SSL_EMAIL"
    echo -e "  🔄 Certificates are managed automatically by Traefik"
fi

echo -e "\n${BLUE}🎯 Next Steps:${NC}"
echo -e "1. Visit $APP_URL to complete the setup"
echo -e "2. Create your first admin user"
echo -e "3. Configure your social media accounts"
echo -e "4. Start scheduling your content!"

echo -e "\n${GREEN}📖 Documentation: https://docs.mixpost.app/pro/${NC}"
echo -e "${GREEN}💬 Support: https://mixpost.app/support${NC}" 
