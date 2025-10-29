#!/bin/bash

# ==========================================
# Remote Server Deployment Script
# ==========================================
# This script can be run from your LOCAL machine to deploy to remote server
# Usage: ./scripts/remote-deploy.sh
# ==========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SERVER_IP="${SERVER_IP:-146.190.157.194}"
SERVER_USER="${SERVER_USER:-root}"
SERVER_PASSWORD="${SERVER_PASSWORD:-eLBEK451326a}"
PROJECT_DIR="/opt/usdx-wexel"
ENVIRONMENT="${ENVIRONMENT:-production}"

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

# ==========================================
# Check if sshpass is available
# ==========================================

check_sshpass() {
    if ! command -v sshpass &> /dev/null; then
        log_warning "sshpass not found. Installing..."

        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install hudochenkov/sshpass/sshpass
            else
                log_error "Please install Homebrew first: https://brew.sh/"
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y sshpass
            elif command -v yum &> /dev/null; then
                sudo yum install -y sshpass
            else
                log_error "Please install sshpass manually"
                exit 1
            fi
        else
            log_error "Unsupported OS. Please install sshpass manually"
            exit 1
        fi
    fi
}

# ==========================================
# SSH Command Helper
# ==========================================

ssh_exec() {
    local command="$1"
    sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no \
        "${SERVER_USER}@${SERVER_IP}" "$command"
}

ssh_exec_interactive() {
    local command="$1"
    sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no -t \
        "${SERVER_USER}@${SERVER_IP}" "$command"
}

scp_upload() {
    local source="$1"
    local dest="$2"
    sshpass -p "$SERVER_PASSWORD" scp -o StrictHostKeyChecking=no -r \
        "$source" "${SERVER_USER}@${SERVER_IP}:${dest}"
}

# ==========================================
# Deployment Steps
# ==========================================

check_server_connection() {
    log "Checking connection to server..."

    if ssh_exec "echo 'Connected successfully'"; then
        log "✓ Server connection OK"
    else
        log_error "Failed to connect to server"
        exit 1
    fi
}

setup_server() {
    log "Setting up server environment..."

    # Create project directory
    ssh_exec "mkdir -p ${PROJECT_DIR}"

    log "✓ Server directory created"
}

upload_code() {
    log "Uploading code to server..."

    # Create temporary archive
    local tmp_archive="/tmp/usdx-wexel-$(date +%s).tar.gz"

    log_info "Creating archive..."
    tar -czf "$tmp_archive" \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='.next' \
        --exclude='dist' \
        --exclude='build' \
        --exclude='*.log' \
        .

    log_info "Uploading archive..."
    scp_upload "$tmp_archive" "/tmp/"

    log_info "Extracting on server..."
    ssh_exec "cd ${PROJECT_DIR} && tar -xzf /tmp/$(basename $tmp_archive) && rm /tmp/$(basename $tmp_archive)"

    # Cleanup local archive
    rm "$tmp_archive"

    log "✓ Code uploaded"
}

run_server_setup() {
    log "Running server setup script..."

    ssh_exec_interactive "cd ${PROJECT_DIR} && bash scripts/server-setup.sh"

    log "✓ Server setup completed"
}

configure_environment() {
    log "Configuring environment..."

    # Check if .env.production exists on server
    if ssh_exec "test -f ${PROJECT_DIR}/.env.production"; then
        log_info ".env.production already exists on server"

        read -p "Do you want to update it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Upload local .env.production if it exists
            if [ -f ".env.production" ]; then
                log_info "Uploading .env.production from local..."
                scp_upload ".env.production" "${PROJECT_DIR}/.env.production"
            else
                log_warning "No local .env.production found. Please configure it manually on server."
            fi
        fi
    else
        log_info "Creating .env.production on server..."

        if [ -f ".env.production" ]; then
            scp_upload ".env.production" "${PROJECT_DIR}/.env.production"
        elif [ -f ".env.staging" ]; then
            scp_upload ".env.staging" "${PROJECT_DIR}/.env.production"
            log_warning "Uploaded .env.staging as .env.production - please update values!"
        else
            log_warning "No .env file found locally. Server will create from example."
        fi
    fi

    log "✓ Environment configured"
}

deploy_application() {
    log "Deploying application..."

    ssh_exec_interactive "cd ${PROJECT_DIR} && ./deploy.sh --env ${ENVIRONMENT} --skip-tests"

    log "✓ Application deployed"
}

check_deployment() {
    log "Checking deployment status..."

    # Wait a bit for services to start
    sleep 5

    # Check docker containers
    log_info "Docker containers:"
    ssh_exec "docker ps --format 'table {{.Names}}\t{{.Status}}'"

    # Check health
    log_info "Checking service health..."

    if ssh_exec "curl -f -s http://localhost:3001/health > /dev/null 2>&1"; then
        log "✓ Backend (API) is healthy"
    else
        log_warning "Backend health check failed"
    fi

    if ssh_exec "curl -f -s http://localhost:3000/ > /dev/null 2>&1"; then
        log "✓ Frontend is healthy"
    else
        log_warning "Frontend health check failed"
    fi
}

show_summary() {
    log ""
    log "===================================="
    log "✅ Deployment completed!"
    log "===================================="
    log ""
    log "Server: ${SERVER_IP}"
    log ""
    log "Services:"
    log "- Frontend: http://${SERVER_IP}:3000"
    log "- Backend:  http://${SERVER_IP}:3001"
    log ""
    log "Useful commands:"
    log "  ssh root@${SERVER_IP}"
    log "  cd ${PROJECT_DIR}"
    log "  ./check-status.sh"
    log "  ./view-logs.sh indexer"
    log ""
}

# ==========================================
# Main Deployment Flow
# ==========================================

main() {
    log "===================================="
    log "USDX/Wexel Remote Deployment"
    log "Server: ${SERVER_IP}"
    log "User: ${SERVER_USER}"
    log "Environment: ${ENVIRONMENT}"
    log "===================================="
    log ""

    # Check prerequisites
    check_sshpass

    # Deployment steps
    check_server_connection
    setup_server
    upload_code

    # Ask if user wants to run full setup
    read -p "Run full server setup? (installs Docker, etc.) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_server_setup
    else
        log_info "Skipping server setup"
    fi

    configure_environment

    # Ask to deploy
    read -p "Deploy application now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_application
        check_deployment
    else
        log_info "Skipping deployment. You can deploy later with:"
        log_info "  ssh ${SERVER_USER}@${SERVER_IP}"
        log_info "  cd ${PROJECT_DIR} && ./deploy.sh --env ${ENVIRONMENT}"
    fi

    show_summary
}

# ==========================================
# Entry Point
# ==========================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            SERVER_IP="$2"
            shift 2
            ;;
        --user)
            SERVER_USER="$2"
            shift 2
            ;;
        --password)
            SERVER_PASSWORD="$2"
            shift 2
            ;;
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --server IP       Server IP address (default: 146.190.157.194)"
            echo "  --user USER       SSH user (default: root)"
            echo "  --password PASS   SSH password"
            echo "  --env ENV         Environment (default: production)"
            echo "  --help            Show this help"
            echo ""
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main deployment
main
