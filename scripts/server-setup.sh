#!/bin/bash

# ==========================================
# USDX/Wexel Server Setup Script
# ==========================================
# This script sets up a fresh server for deployment
# Tested on: Ubuntu 20.04/22.04
# ==========================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP="${SERVER_IP:-146.190.157.194}"
DEPLOY_USER="${DEPLOY_USER:-root}"
PROJECT_DIR="${PROJECT_DIR:-/opt/usdx-wexel}"
ENVIRONMENT="${ENVIRONMENT:-production}"

# ==========================================
# Logging Functions
# ==========================================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# ==========================================
# System Update
# ==========================================

update_system() {
    log "Updating system packages..."
    apt-get update -y
    apt-get upgrade -y
    log "✓ System updated"
}

# ==========================================
# Install Dependencies
# ==========================================

install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker already installed"
        docker --version
        return 0
    fi

    log "Installing Docker..."

    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Install prerequisites
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    # Add user to docker group
    usermod -aG docker $DEPLOY_USER || true

    log "✓ Docker installed successfully"
    docker --version
}

install_docker_compose() {
    if docker compose version &> /dev/null; then
        log_info "Docker Compose already installed"
        docker compose version
        return 0
    fi

    log "Docker Compose plugin installed with Docker"
    docker compose version
}

install_utilities() {
    log "Installing system utilities..."

    apt-get install -y \
        git \
        curl \
        wget \
        jq \
        htop \
        vim \
        nano \
        net-tools \
        ufw \
        fail2ban \
        certbot \
        python3-certbot-nginx

    log "✓ Utilities installed"
}

install_nodejs() {
    if command -v node &> /dev/null; then
        log_info "Node.js already installed: $(node --version)"
        return 0
    fi

    log "Installing Node.js..."

    # Install Node.js 20.x
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs

    # Install pnpm
    npm install -g pnpm

    log "✓ Node.js installed"
    node --version
    npm --version
    pnpm --version
}

# ==========================================
# Security Configuration
# ==========================================

configure_firewall() {
    log "Configuring firewall..."

    # Reset UFW to default
    ufw --force reset

    # Default policies
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH
    ufw allow 22/tcp

    # Allow HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp

    # Allow application ports
    ufw allow 3000/tcp  # WebApp
    ufw allow 3001/tcp  # API

    # Enable UFW
    ufw --force enable

    log "✓ Firewall configured"
    ufw status
}

configure_fail2ban() {
    log "Configuring Fail2Ban..."

    # Create jail.local
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
EOF

    # Restart Fail2Ban
    systemctl restart fail2ban
    systemctl enable fail2ban

    log "✓ Fail2Ban configured"
}

# ==========================================
# Project Setup
# ==========================================

setup_project_directory() {
    log "Setting up project directory..."

    # Create project directory
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"

    # Set permissions
    chown -R $DEPLOY_USER:$DEPLOY_USER "$PROJECT_DIR"

    log "✓ Project directory created: $PROJECT_DIR"
}

clone_repository() {
    log "Cloning repository..."

    cd "$PROJECT_DIR"

    # If git repo already exists, pull latest
    if [ -d ".git" ]; then
        log_info "Repository already exists, pulling latest changes..."
        git fetch --all
        git pull origin main || git pull origin master
    else
        log_warning "Please manually clone your repository to $PROJECT_DIR"
        log_info "Example: git clone https://github.com/your-org/usdx-wexel.git $PROJECT_DIR"
    fi
}

setup_environment() {
    log "Setting up environment configuration..."

    cd "$PROJECT_DIR"

    # Create .env.production from example if not exists
    if [ ! -f ".env.production" ]; then
        if [ -f ".env.production.example" ]; then
            cp .env.production.example .env.production
            log_warning "Created .env.production from example - PLEASE UPDATE THE VALUES!"
        elif [ -f ".env.staging" ]; then
            cp .env.staging .env.production
            log_warning "Created .env.production from .env.staging - PLEASE UPDATE THE VALUES!"
        else
            log_error ".env.production.example not found!"
        fi
    else
        log_info ".env.production already exists"
    fi

    # Generate JWT secrets if needed
    if grep -q "CHANGE_ME" .env.production 2>/dev/null; then
        log_warning "Found CHANGE_ME placeholders in .env.production"
        log_info "Generating JWT secrets..."

        JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
        ADMIN_JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
        POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
        REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')

        # Replace placeholders
        sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" .env.production
        sed -i "s|ADMIN_JWT_SECRET=.*|ADMIN_JWT_SECRET=$ADMIN_JWT_SECRET|" .env.production
        sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env.production
        sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|" .env.production

        # Update DATABASE_URL with new password
        sed -i "s|postgresql://usdx_user:.*@|postgresql://usdx_user:$POSTGRES_PASSWORD@|" .env.production
        sed -i "s|redis://:.*@|redis://:$REDIS_PASSWORD@|" .env.production

        log "✓ Generated secure secrets"
    fi

    # Set proper permissions
    chmod 600 .env.production

    log "✓ Environment configured"
}

# ==========================================
# Nginx Setup (Optional)
# ==========================================

setup_nginx() {
    log "Setting up Nginx reverse proxy..."

    if ! command -v nginx &> /dev/null; then
        apt-get install -y nginx
    fi

    # Create Nginx configuration
    cat > /etc/nginx/sites-available/usdx-wexel <<'EOF'
# WebApp (Frontend)
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    # Redirect to HTTPS (uncomment after SSL setup)
    # return 301 https://$server_name$request_uri;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# API (Backend)
server {
    listen 80;
    server_name api.your-domain.com;

    # Redirect to HTTPS (uncomment after SSL setup)
    # return 301 https://$server_name$request_uri;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # CORS headers
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;
    }

    location /health {
        proxy_pass http://localhost:3001/health;
        access_log off;
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/usdx-wexel /etc/nginx/sites-enabled/

    # Remove default site
    rm -f /etc/nginx/sites-enabled/default

    # Test and reload Nginx
    nginx -t
    systemctl restart nginx
    systemctl enable nginx

    log "✓ Nginx configured"
    log_warning "Remember to update server_name in /etc/nginx/sites-available/usdx-wexel"
}

# ==========================================
# System Optimization
# ==========================================

optimize_system() {
    log "Optimizing system parameters..."

    # Increase file descriptors
    cat >> /etc/security/limits.conf <<EOF

# USDX/Wexel optimizations
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF

    # Kernel parameters
    cat >> /etc/sysctl.conf <<EOF

# USDX/Wexel optimizations
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 10000 65535
fs.file-max = 2097152
vm.swappiness = 10
EOF

    sysctl -p

    log "✓ System optimized"
}

# ==========================================
# Create Deployment Helper Scripts
# ==========================================

create_helper_scripts() {
    log "Creating helper scripts..."

    cd "$PROJECT_DIR"

    # Create quick deploy script
    cat > quick-deploy.sh <<'EOF'
#!/bin/bash
set -e

echo "🚀 Starting deployment..."

# Pull latest changes
git pull

# Run deployment script
./deploy.sh --env production --skip-tests

echo "✅ Deployment completed!"
EOF

    chmod +x quick-deploy.sh

    # Create status check script
    cat > check-status.sh <<'EOF'
#!/bin/bash

echo "📊 USDX/Wexel Status Check"
echo "============================="
echo ""

echo "🐳 Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "💾 Disk Usage:"
df -h /
echo ""

echo "🔍 Service Health:"
echo -n "Backend (API): "
curl -f -s http://localhost:3001/health > /dev/null && echo "✅ Healthy" || echo "❌ Unhealthy"

echo -n "Frontend (WebApp): "
curl -f -s http://localhost:3000/ > /dev/null && echo "✅ Healthy" || echo "❌ Unhealthy"
echo ""

echo "📊 Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
EOF

    chmod +x check-status.sh

    # Create logs viewer script
    cat > view-logs.sh <<'EOF'
#!/bin/bash

SERVICE=${1:-indexer}

case $SERVICE in
    indexer|api|backend)
        docker logs -f --tail 100 usdx-wexel-indexer
        ;;
    webapp|frontend|web)
        docker logs -f --tail 100 usdx-wexel-webapp
        ;;
    db|database|postgres)
        docker logs -f --tail 100 usdx-wexel-postgres
        ;;
    redis)
        docker logs -f --tail 100 usdx-wexel-redis
        ;;
    *)
        echo "Usage: $0 [indexer|webapp|db|redis]"
        exit 1
        ;;
esac
EOF

    chmod +x view-logs.sh

    log "✓ Helper scripts created"
}

# ==========================================
# Print Summary
# ==========================================

print_summary() {
    log ""
    log "===================================="
    log "✅ Server setup completed!"
    log "===================================="
    log ""
    log "📁 Project directory: $PROJECT_DIR"
    log ""
    log "Next steps:"
    log "1. Clone your repository to $PROJECT_DIR (if not done)"
    log "2. Update .env.production with your configuration"
    log "3. Run: cd $PROJECT_DIR && ./deploy.sh --env production"
    log ""
    log "Helper scripts:"
    log "- ./quick-deploy.sh      - Quick deployment"
    log "- ./check-status.sh      - Check service status"
    log "- ./view-logs.sh [name]  - View service logs"
    log ""
    log "Services will be available at:"
    log "- Frontend: http://$SERVER_IP:3000"
    log "- Backend:  http://$SERVER_IP:3001"
    log ""
    log_warning "⚠️  Remember to:"
    log "- Update .env.production with correct values"
    log "- Configure domain names in Nginx (optional)"
    log "- Set up SSL certificates with certbot (for production)"
    log "- Review firewall rules"
    log ""
}

# ==========================================
# Main Installation Flow
# ==========================================

main() {
    log "===================================="
    log "USDX/Wexel Server Setup"
    log "Server: $SERVER_IP"
    log "User: $DEPLOY_USER"
    log "Environment: $ENVIRONMENT"
    log "===================================="
    log ""

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root or with sudo"
        exit 1
    fi

    # System setup
    update_system
    install_utilities
    install_docker
    install_docker_compose
    install_nodejs

    # Security
    configure_firewall
    configure_fail2ban

    # Optimization
    optimize_system

    # Project setup
    setup_project_directory
    # clone_repository  # Uncomment if you have repo URL
    setup_environment
    create_helper_scripts

    # Optional: Nginx (comment out if not needed)
    # setup_nginx

    # Summary
    print_summary

    log "✅ Setup completed successfully!"
}

# Run main installation
main "$@"
