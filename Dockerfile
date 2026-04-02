# ─── Stage 1: Build ───────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

# Force dev deps even if Railway sets NODE_ENV=production
ENV NODE_ENV=development

WORKDIR /app

# Install ALL deps (including devDependencies: tsc, @types/*, etc.)
COPY backend/package*.json ./backend/
RUN cd backend && npm ci --include=dev

# Copy source
COPY backend/ ./backend/

# Generate Prisma client FIRST so TypeScript can find the types
RUN cd backend && npx prisma generate

# Compile TypeScript → dist/
RUN cd backend && ./node_modules/.bin/tsc

# ─── Stage 2: Production ──────────────────────────────────────────────────────
FROM node:20-alpine AS runner

RUN apk add --no-cache dumb-init

WORKDIR /app/backend

ENV NODE_ENV=production

# Production deps only
COPY backend/package*.json ./
RUN npm ci --omit=dev

# Copy compiled output
COPY --from=builder /app/backend/dist ./dist

# Copy generated Prisma client
COPY --from=builder /app/backend/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/backend/node_modules/@prisma ./node_modules/@prisma

# Copy Prisma schema (needed for migrate deploy at runtime)
COPY backend/prisma ./prisma

# Upload directories
RUN mkdir -p uploads/images \
             uploads/videos \
             uploads/audio \
             uploads/files \
             uploads/avatars \
             uploads/groups \
             uploads/channels

EXPOSE 3000

ENTRYPOINT ["dumb-init", "--"]
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/index.js"]
