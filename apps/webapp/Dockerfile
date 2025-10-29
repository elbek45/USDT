# ==========================================
# USDX/Wexel Frontend WebApp - Dockerfile
# ==========================================
# Multi-stage build for optimal Next.js deployment
# Node.js 20 + Next.js 15 + React 18

# Stage 1: Dependencies
FROM node:20-alpine AS deps

# Install pnpm
RUN corepack enable && corepack prepare pnpm@9.5.0 --activate

# Install libc6-compat for Next.js compatibility and python for native deps
RUN apk add --no-cache libc6-compat python3 make g++ linux-headers

WORKDIR /app

# Copy workspace configuration
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY tsconfig.base.json ./

# Copy webapp package files
COPY apps/webapp/package.json ./apps/webapp/

# Install dependencies (frozen lockfile for reproducibility)
RUN pnpm install --frozen-lockfile --filter webapp...

# Stage 2: Builder
FROM node:20-alpine AS builder

# Install pnpm
RUN corepack enable && corepack prepare pnpm@9.5.0 --activate

RUN apk add --no-cache libc6-compat

WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/webapp/node_modules ./apps/webapp/node_modules

# Copy workspace configuration
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY tsconfig.base.json ./

# Copy webapp source code
COPY apps/webapp ./apps/webapp

WORKDIR /app/apps/webapp

# Set environment variables for build
# Note: NEXT_PUBLIC_* vars must be set at build time
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_SOLANA_RPC_URL
ARG NEXT_PUBLIC_SOLANA_NETWORK
ARG NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID

ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_SOLANA_RPC_URL=$NEXT_PUBLIC_SOLANA_RPC_URL
ENV NEXT_PUBLIC_SOLANA_NETWORK=$NEXT_PUBLIC_SOLANA_NETWORK
ENV NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=$NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID
ENV NEXT_TELEMETRY_DISABLED=1

# Build the application
RUN pnpm build

# Stage 3: Runner
FROM node:20-alpine AS runner

RUN apk add --no-cache dumb-init

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Copy necessary files from builder
COPY --from=builder /app/apps/webapp/public ./public

# Copy Next.js build output
# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /app/apps/webapp/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/webapp/.next/static ./apps/webapp/.next/static

# Switch to non-root user
USER nextjs

# Expose Next.js port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)}).on('error', () => process.exit(1))"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start Next.js server
CMD ["node", "apps/webapp/server.js"]
