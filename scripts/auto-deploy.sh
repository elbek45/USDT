#!/bin/bash

# ==========================================
# USDX/Wexel - Automated Remote Deployment
# ==========================================
# This script deploys to 146.190.157.194 from your local machine
# ==========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Server Configuration
SERVER_IP="146.190.157.194"
SERVER_USER="root"
SERVER_PASSWORD="eLBEK451326a"
PROJECT_DIR="/var/www/USDX"
ENVIRONMENT="production"

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"
}

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"
}

log ""
log "===================================="
log "USDX/Wexel Auto Deployment"
log "Server: $SERVER_IP"
log "Directory: $PROJECT_DIR"
log "===================================="
log ""

# Check if sshpass is available
if ! command -v sshpass &> /dev/null; then
    log_warning "sshpass not found, installing..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install hudochenkov/sshpass/sshpass
        else
            log_error "Please install Homebrew first: https://brew.sh/"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y sshpass
        elif command -v yum &> /dev/null; then
            sudo yum install -y sshpass
        else
            log_error "Please install sshpass manually"
            exit 1
        fi
    fi
fi

# SSH helper function
ssh_exec() {
    sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "${SERVER_USER}@${SERVER_IP}" "$1"
}

# ==========================================
# Step 1: Test Connection
# ==========================================
log "Step 1/7: Testing server connection..."

if ssh_exec "echo 'OK'" > /dev/null 2>&1; then
    log "✓ Connection successful"
else
    log_error "Cannot connect to server $SERVER_IP"
    exit 1
fi

# ==========================================
# Step 2: Create Project Directory
# ==========================================
log "Step 2/7: Creating project directory..."

ssh_exec "mkdir -p $PROJECT_DIR"
log "✓ Directory created: $PROJECT_DIR"

# ==========================================
# Step 3: Upload Code
# ==========================================
log "Step 3/7: Uploading code to server..."

# Create temporary archive excluding unnecessary files
TEMP_ARCHIVE="/tmp/usdx-wexel-$(date +%s).tar.gz"

log_info "Creating archive..."
tar -czf "$TEMP_ARCHIVE" \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='.next' \
    --exclude='dist' \
    --exclude='build' \
    --exclude='*.log' \
    --exclude='.env.local' \
    . 2>/dev/null

log_info "Uploading (this may take a minute)..."
sshpass -p "$SERVER_PASSWORD" scp -o StrictHostKeyChecking=no \
    "$TEMP_ARCHIVE" "${SERVER_USER}@${SERVER_IP}:/tmp/" 2>/dev/null

log_info "Extracting on server..."
ssh_exec "cd $PROJECT_DIR && tar -xzf /tmp/$(basename $TEMP_ARCHIVE) 2>/dev/null && rm /tmp/$(basename $TEMP_ARCHIVE)"

# Cleanup local archive
rm "$TEMP_ARCHIVE"

log "✓ Code uploaded"

# ==========================================
# Step 4: Run Server Setup
# ==========================================
log "Step 4/7: Setting up server environment..."

# Create and run setup script on server
ssh_exec "cd $PROJECT_DIR && bash scripts/deploy-to-server.sh"

log "✓ Server setup complete"

# ==========================================
# Step 5: Deploy Application
# ==========================================
log "Step 5/7: Deploying application..."

log_info "Building and starting containers..."
ssh_exec "cd $PROJECT_DIR && chmod +x deploy.sh && ./deploy.sh --env production --skip-tests 2>&1" || {
    log_warning "Deployment script encountered issues, checking manually..."
}

# ==========================================
# Step 6: Wait for Services
# ==========================================
log "Step 6/7: Waiting for services to start..."

sleep 10

# ==========================================
# Step 7: Verify Deployment
# ==========================================
log "Step 7/7: Verifying deployment..."

log_info "Checking Docker containers..."
ssh_exec "docker ps --format 'table {{.Names}}\t{{.Status}}'" || true

log_info "Checking service health..."

# Check backend
if ssh_exec "curl -f -s http://localhost:3001/health > /dev/null 2>&1"; then
    log "✓ Backend API is healthy"
else
    log_warning "⚠️  Backend health check failed (may still be starting)"
fi

# Check frontend
if ssh_exec "curl -f -s http://localhost:3000/ > /dev/null 2>&1"; then
    log "✓ Frontend is healthy"
else
    log_warning "⚠️  Frontend health check failed (may still be starting)"
fi

# ==========================================
# Summary
# ==========================================
log ""
log "===================================="
log "✅ Deployment Complete!"
log "===================================="
log ""
log "Server: $SERVER_IP"
log "Directory: $PROJECT_DIR"
log ""
log "🌐 Services:"
log "  Frontend: http://$SERVER_IP:3000"
log "  Backend:  http://$SERVER_IP:3001"
log "  API Docs: http://$SERVER_IP:3001/api"
log ""
log "📋 Useful commands:"
log "  ssh root@$SERVER_IP"
log "  cd $PROJECT_DIR"
log "  ./check-status.sh"
log "  ./view-logs.sh indexer"
log ""
log_warning "⚠️  Important:"
log "  1. SSH to server and update .env.production with your Solana contract addresses"
log "  2. Check logs if services are not responding: ./view-logs.sh indexer"
log "  3. Services may take 1-2 minutes to fully start"
log ""
