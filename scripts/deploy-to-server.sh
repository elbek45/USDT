#!/bin/bash

# ==========================================
# USDX/Wexel - Complete Server Deployment Script
# ==========================================
# Server: 146.190.157.194
# User: root
# Directory: /var/www/USDX
# ==========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root: sudo bash $0"
    exit 1
fi

log "===================================="
log "USDX/Wexel Server Deployment"
log "Directory: $PROJECT_DIR"
log "===================================="
echo ""

# ==========================================
# Step 1: System Update
# ==========================================
log "Step 1/8: Updating system..."
apt-get update -y > /dev/null 2>&1

# ==========================================
# Step 2: Install Docker
# ==========================================
log "Step 2/8: Installing Docker..."

if ! command -v docker &> /dev/null; then
    log_info "Installing Docker..."

    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Install prerequisites
    apt-get install -y ca-certificates curl gnupg lsb-release > /dev/null 2>&1

    # Add Docker GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null

    # Add repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update -y > /dev/null 2>&1
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1

    systemctl start docker
    systemctl enable docker > /dev/null 2>&1

    log "✓ Docker installed: $(docker --version)"
else
    log "✓ Docker already installed: $(docker --version)"
fi

# ==========================================
# Step 3: Install Utilities
# ==========================================
log "Step 3/8: Installing utilities..."
apt-get install -y git curl wget jq htop vim nano net-tools > /dev/null 2>&1
log "✓ Utilities installed"

# ==========================================
# Step 4: Configure Firewall
# ==========================================
log "Step 4/8: Configuring firewall..."

if command -v ufw &> /dev/null; then
    ufw --force reset > /dev/null 2>&1 || true
    ufw default deny incoming > /dev/null 2>&1
    ufw default allow outgoing > /dev/null 2>&1
    ufw allow 22/tcp > /dev/null 2>&1
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    ufw allow 3000/tcp > /dev/null 2>&1
    ufw allow 3001/tcp > /dev/null 2>&1
    ufw --force enable > /dev/null 2>&1
    log "✓ Firewall configured"
else
    log_warning "UFW not available, skipping firewall setup"
fi

# ==========================================
# Step 5: Setup Project Directory
# ==========================================
log "Step 5/8: Setting up project directory..."

# Create directory if not exists
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

log "✓ Project directory: $PROJECT_DIR"

# ==========================================
# Step 6: Configure Environment
# ==========================================
log "Step 6/8: Configuring environment..."

# Generate secrets
JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
ADMIN_JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')

# Create .env.production
cat > "$PROJECT_DIR/.env.production" <<EOF
# ========================================
# USDX/Wexel Production Environment
# Generated on $(date)
# ========================================

# GENERAL
NODE_ENV=production
LOG_LEVEL=info
API_PORT=3001

# DATABASE
POSTGRES_DB=usdx_production
POSTGRES_USER=usdx_user
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
DATABASE_URL=postgresql://usdx_user:${POSTGRES_PASSWORD}@postgres:5432/usdx_production?schema=public

# REDIS
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379

# JWT & AUTH
JWT_SECRET=${JWT_SECRET}
ADMIN_JWT_SECRET=${ADMIN_JWT_SECRET}
JWT_EXPIRATION=1h
REFRESH_TOKEN_EXPIRATION=7d

# CORS
CORS_ALLOWED_ORIGINS=http://146.190.157.194:3000,http://localhost:3000

# SOLANA
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
SOLANA_NETWORK=mainnet
SOLANA_COMMITMENT=confirmed

# IMPORTANT: Update these with your deployed contract addresses
SOLANA_WEXEL_PROGRAM_ID=REPLACE_WITH_YOUR_PROGRAM_ID
SOLANA_LIQUIDITY_POOL_PROGRAM_ID=REPLACE_WITH_YOUR_PROGRAM_ID
SOLANA_COLLATERAL_PROGRAM_ID=REPLACE_WITH_YOUR_PROGRAM_ID
SOLANA_ORACLE_PROGRAM_ID=REPLACE_WITH_YOUR_PROGRAM_ID
SOLANA_MARKETPLACE_PROGRAM_ID=REPLACE_WITH_YOUR_PROGRAM_ID
SOLANA_BOOST_MINT_ADDRESS=REPLACE_WITH_YOUR_MINT_ADDRESS

# TRON
TRON_GRID_API_KEY=YOUR_TRONGRID_API_KEY
TRON_NETWORK=mainnet
TRON_USDT_ADDRESS=TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t
TRON_INDEXER_AUTO_START=true

# FRONTEND
NEXT_PUBLIC_API_URL=http://146.190.157.194:3001
NEXT_PUBLIC_SOLANA_NETWORK=mainnet
NEXT_PUBLIC_TRON_NETWORK=mainnet
NEXT_PUBLIC_ENVIRONMENT=production

# ADMIN
ADMIN_DEFAULT_EMAIL=admin@usdx-wexel.com
ADMIN_DEFAULT_PASSWORD=CHANGE_ME_ON_FIRST_LOGIN

# MONITORING
METRICS_ENABLED=true
METRICS_PORT=9090

# RATE LIMITING
RATE_LIMIT_TTL=60000
RATE_LIMIT_MAX=100
RATE_LIMIT_PUBLIC_MAX=50
RATE_LIMIT_AUTHENTICATED_MAX=200

# FEATURES
FEATURE_MARKETPLACE_ENABLED=true
FEATURE_COLLATERAL_LOANS_ENABLED=true
FEATURE_TRON_DEPOSITS_ENABLED=true
FEATURE_ADMIN_PANEL_ENABLED=true

# SECURITY
HELMET_ENABLED=true
RATE_LIMITING_ENABLED=true
REQUEST_SIZE_LIMIT=10mb
EOF

chmod 600 "$PROJECT_DIR/.env.production"

log "✓ Environment configured"
log_warning "⚠️  IMPORTANT: Update SOLANA program IDs in .env.production"

# ==========================================
# Step 7: Create Helper Scripts
# ==========================================
log "Step 7/8: Creating helper scripts..."

# Status check script
cat > "$PROJECT_DIR/check-status.sh" <<'EOFSCRIPT'
#!/bin/bash
echo "📊 USDX/Wexel Status"
echo "===================="
echo ""
echo "🐳 Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "🔍 Service Health:"
echo -n "Backend: "
curl -f -s http://localhost:3001/health > /dev/null 2>&1 && echo "✅ Healthy" || echo "❌ Down"
echo -n "Frontend: "
curl -f -s http://localhost:3000/ > /dev/null 2>&1 && echo "✅ Healthy" || echo "❌ Down"
echo ""
EOFSCRIPT

# Logs viewer script
cat > "$PROJECT_DIR/view-logs.sh" <<'EOFSCRIPT'
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
EOFSCRIPT

chmod +x "$PROJECT_DIR/check-status.sh"
chmod +x "$PROJECT_DIR/view-logs.sh"

log "✓ Helper scripts created"

# ==========================================
# Step 8: Summary
# ==========================================
log "Step 8/8: Deployment preparation complete!"

echo ""
log "===================================="
log "✅ Server Setup Complete!"
log "===================================="
echo ""
log "Project directory: $PROJECT_DIR"
log ""
log "Next steps:"
log "1. Update .env.production with your Solana contract addresses:"
log "   nano $PROJECT_DIR/.env.production"
log ""
log "2. Deploy Solana contracts (if not done):"
log "   cd $PROJECT_DIR/contracts/solana/solana-contracts"
log "   anchor build && anchor deploy --provider.cluster mainnet"
log ""
log "3. Run the deployment:"
log "   cd $PROJECT_DIR && ./deploy.sh --env production --skip-tests"
log ""
log "Helper commands:"
log "  ./check-status.sh      - Check service status"
log "  ./view-logs.sh indexer - View backend logs"
log "  ./view-logs.sh webapp  - View frontend logs"
log ""
log "Services will be available at:"
log "  Frontend: http://146.190.157.194:3000"
log "  Backend:  http://146.190.157.194:3001"
log ""
log_warning "⚠️  Don't forget to update Solana contract addresses in .env.production!"
echo ""
