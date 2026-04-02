# ─── Stage 1: Build ───────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Install deps first (layer cache)
COPY backend/package*.json ./backend/
RUN cd backend && npm ci

# Copy source and build
COPY backend/ ./backend/
RUN cd backend && npm run build && npx prisma generate

# ─── Stage 2: Production ──────────────────────────────────────────────────────
FROM node:20-alpine AS runner

RUN apk add --no-cache dumb-init

WORKDIR /app

# Production deps only
COPY backend/package*.json ./backend/
RUN cd backend && npm ci --omit=dev

# Copy compiled output + prisma schema
COPY --from=builder /app/backend/dist ./backend/dist
COPY --from=builder /app/backend/node_modules/.prisma ./backend/node_modules/.prisma
COPY backend/prisma ./backend/prisma

# Upload directories
RUN mkdir -p backend/uploads/images \
             backend/uploads/videos \
             backend/uploads/audio \
             backend/uploads/files \
             backend/uploads/avatars \
             backend/uploads/groups \
             backend/uploads/channels

WORKDIR /app/backend

EXPOSE 3000
ENV NODE_ENV=production

ENTRYPOINT ["dumb-init", "--"]
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/index.js"]
