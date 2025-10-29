#!/bin/bash

# ==========================================
# One-Line Deployment Script for Server
# ==========================================
# Run this directly on the server 146.190.157.194
# wget -qO- https://raw.githubusercontent.com/your-repo/main/scripts/one-line-deploy.sh | bash
# Or copy this entire file and run: bash one-line-deploy.sh
# ==========================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}===================================="
echo "USDX/Wexel Quick Deployment"
echo "====================================${NC}"
echo ""

# Configuration
PROJECT_DIR="/opt/usdx-wexel"
REPO_URL="${REPO_URL:-}"  # Set your repo URL here or pass as environment variable

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo bash $0${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1/5: System Update${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install -y curl wget git jq > /dev/null 2>&1

echo -e "${YELLOW}Step 2/5: Installing Docker${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
fi
systemctl start docker
systemctl enable docker

echo -e "${YELLOW}Step 3/5: Setting up project directory${NC}"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo -e "${YELLOW}Step 4/5: Downloading project files${NC}"
if [ -n "$REPO_URL" ]; then
    if [ -d ".git" ]; then
        git pull origin main
    else
        git clone "$REPO_URL" .
    fi
else
    echo -e "${RED}No repository URL provided!${NC}"
    echo "Please either:"
    echo "1. Set REPO_URL environment variable"
    echo "2. Manually upload code to $PROJECT_DIR"
    echo "3. Clone repository manually"
    exit 1
fi

echo -e "${YELLOW}Step 5/5: Initial configuration${NC}"

# Create .env.production if not exists
if [ ! -f ".env.production" ]; then
    if [ -f ".env.staging" ]; then
        cp .env.staging .env.production
    elif [ -f ".env.production.example" ]; then
        cp .env.production.example .env.production
    fi

    # Generate secrets
    JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
    ADMIN_JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')

    # Update .env.production
    sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" .env.production
    sed -i "s|ADMIN_JWT_SECRET=.*|ADMIN_JWT_SECRET=$ADMIN_JWT_SECRET|" .env.production
    sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env.production
    sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|" .env.production

    chmod 600 .env.production
fi

# Basic firewall
if command -v ufw &> /dev/null; then
    ufw allow 22/tcp > /dev/null 2>&1 || true
    ufw allow 80/tcp > /dev/null 2>&1 || true
    ufw allow 443/tcp > /dev/null 2>&1 || true
    ufw allow 3000/tcp > /dev/null 2>&1 || true
    ufw allow 3001/tcp > /dev/null 2>&1 || true
    ufw --force enable > /dev/null 2>&1 || true
fi

echo ""
echo -e "${GREEN}✅ Initial setup completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Edit configuration: nano $PROJECT_DIR/.env.production"
echo "2. Update Solana and Tron contract addresses"
echo "3. Run deployment: cd $PROJECT_DIR && ./deploy.sh --env production"
echo ""
echo "Project directory: $PROJECT_DIR"
echo ""
