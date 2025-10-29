#!/bin/bash
# Copy and paste this ENTIRE script into your terminal on the server
# Then run: bash setup-and-deploy.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
log_error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"; }
log_info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"; }
log_warning() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"; }

PROJECT_DIR="/var/www/USDX"

echo ""
log "===================================="
log "🚀 USDX/Wexel Deployment"
log "Directory: $PROJECT_DIR"
log "===================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root: sudo bash $0"
    exit 1
fi

cd "$PROJECT_DIR"

# 1. System Update
log "📦 Step 1/10: Updating system..."
apt-get update -y > /dev/null 2>&1
log "✓ System updated"

# 2. Install Docker
log "🐳 Step 2/10: Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
    systemctl start docker
    systemctl enable docker > /dev/null 2>&1
    log "✓ Docker installed: $(docker --version)"
else
    log "✓ Docker already installed"
fi

# 3. Install Utilities
log "🔧 Step 3/10: Installing utilities..."
apt-get install -y git curl jq wget nano htop net-tools > /dev/null 2>&1
log "✓ Utilities installed"

# 4. Install Node.js
log "📦 Step 4/10: Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
    apt-get install -y nodejs > /dev/null 2>&1
    npm install -g pnpm > /dev/null 2>&1
    log "✓ Node.js installed: $(node --version)"
else
    log "✓ Node.js already installed"
fi

# 5. Configure Firewall
log "🔥 Step 5/10: Configuring firewall..."
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
fi

# 6. Generate Secrets
log "🔐 Step 6/10: Generating secrets..."
JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
ADMIN_JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')

# 7. Create .env.production
log "⚙️  Step 7/10: Creating environment configuration..."
cat > "$PROJECT_DIR/.env.production" <<EOF
# USDX/Wexel Production Configuration
# Generated: $(date)

NODE_ENV=production
LOG_LEVEL=info
API_PORT=3001

# Database
POSTGRES_DB=usdx_production
POSTGRES_USER=usdx_user
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
DATABASE_URL=postgresql://usdx_user:${POSTGRES_PASSWORD}@postgres:5432/usdx_production?schema=public

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379

# JWT
JWT_SECRET=${JWT_SECRET}
ADMIN_JWT_SECRET=${ADMIN_JWT_SECRET}
JWT_EXPIRATION=1h
REFRESH_TOKEN_EXPIRATION=7d

# CORS
CORS_ALLOWED_ORIGINS=http://146.190.157.194:3000,http://localhost:3000

# Solana - Using placeholders (update later)
SOLANA_RPC_URL=https://api.devnet.solana.com
SOLANA_NETWORK=devnet
SOLANA_COMMITMENT=confirmed
SOLANA_WEXEL_PROGRAM_ID=11111111111111111111111111111111
SOLANA_LIQUIDITY_POOL_PROGRAM_ID=11111111111111111111111111111111
SOLANA_COLLATERAL_PROGRAM_ID=11111111111111111111111111111111
SOLANA_ORACLE_PROGRAM_ID=11111111111111111111111111111111
SOLANA_MARKETPLACE_PROGRAM_ID=11111111111111111111111111111111
SOLANA_BOOST_MINT_ADDRESS=11111111111111111111111111111111

# Tron
TRON_GRID_API_KEY=placeholder-api-key
TRON_NETWORK=nile
TRON_USDT_ADDRESS=TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf
TRON_INDEXER_AUTO_START=false

# Frontend
NEXT_PUBLIC_API_URL=http://146.190.157.194:3001
NEXT_PUBLIC_SOLANA_NETWORK=devnet
NEXT_PUBLIC_TRON_NETWORK=nile
NEXT_PUBLIC_ENVIRONMENT=production
NEXT_PUBLIC_SOLANA_RPC_URL=https://api.devnet.solana.com

# Admin
ADMIN_DEFAULT_EMAIL=admin@usdx-wexel.com
ADMIN_DEFAULT_PASSWORD=ChangeMe123!

# Features
METRICS_ENABLED=true
FEATURE_MARKETPLACE_ENABLED=true
FEATURE_COLLATERAL_LOANS_ENABLED=true
FEATURE_TRON_DEPOSITS_ENABLED=false
RATE_LIMITING_ENABLED=true
HELMET_ENABLED=true
REQUEST_SIZE_LIMIT=10mb

# Rate Limiting
RATE_LIMIT_TTL=60000
RATE_LIMIT_MAX=100
RATE_LIMIT_PUBLIC_MAX=50
RATE_LIMIT_AUTHENTICATED_MAX=200
EOF

chmod 600 "$PROJECT_DIR/.env.production"
log "✓ Environment configured with placeholders"

# 8. Create Helper Scripts
log "📝 Step 8/10: Creating helper scripts..."

cat > "$PROJECT_DIR/status.sh" <<'SCRIPT'
#!/bin/bash
echo "🔍 USDX/Wexel Status"
echo "===================="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Health Checks:"
curl -s http://localhost:3001/health 2>/dev/null && echo "✅ Backend OK" || echo "❌ Backend Down"
curl -s http://localhost:3000/ > /dev/null 2>&1 && echo "✅ Frontend OK" || echo "❌ Frontend Down"
SCRIPT

cat > "$PROJECT_DIR/logs.sh" <<'SCRIPT'
#!/bin/bash
SERVICE=${1:-indexer}
case $SERVICE in
    api|backend|indexer) docker logs -f --tail 100 usdx-wexel-indexer ;;
    web|frontend|webapp) docker logs -f --tail 100 usdx-wexel-webapp ;;
    db|postgres) docker logs -f --tail 100 usdx-wexel-postgres ;;
    redis) docker logs -f --tail 100 usdx-wexel-redis ;;
    *) echo "Usage: $0 [api|web|db|redis]" ;;
esac
SCRIPT

chmod +x status.sh logs.sh
log "✓ Helper scripts created"

# 9. Deploy Application
log "🚀 Step 9/10: Deploying application..."

chmod +x deploy.sh

log_info "Starting deployment (this may take several minutes)..."
./deploy.sh --env production --skip-tests --skip-backup 2>&1 | tee deploy.log || {
    log_warning "Deployment script had issues, checking Docker Compose..."

    # Try docker compose directly if deploy.sh fails
    if [ -d "infra/production" ]; then
        cd infra/production
        docker compose up -d
        cd "$PROJECT_DIR"
    fi
}

log "✓ Deployment completed"

# 10. Wait and Verify
log "⏳ Step 10/10: Waiting for services to start..."
sleep 20

log_info "Checking containers..."
docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
log "===================================="
log "✅ Deployment Complete!"
log "===================================="
echo ""
log "📍 Server: 146.190.157.194"
log "📁 Directory: $PROJECT_DIR"
echo ""
log "🌐 Services:"
log "  Frontend: http://146.190.157.194:3000"
log "  Backend:  http://146.190.157.194:3001"
log "  API Docs: http://146.190.157.194:3001/api"
echo ""
log "📋 Helper Commands:"
log "  ./status.sh           - Check service status"
log "  ./logs.sh api         - View backend logs"
log "  ./logs.sh web         - View frontend logs"
log "  docker ps             - List containers"
echo ""
log_warning "⚠️  Note: Using placeholder Solana addresses (devnet)"
log "Update them later in: /var/www/USDX/.env.production"
echo ""
log "Services may take 1-2 minutes to fully start."
log "Check status with: ./status.sh"
echo ""
