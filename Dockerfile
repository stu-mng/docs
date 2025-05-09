# Stage 1: Base image
FROM node:22-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@9.15.4 --activate

# Stage 2: Install dependencies
FROM base AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
# Use a cache mount for the pnpm store and configure pnpm to copy packages (avoid EXDEV errors)
RUN --mount=type=cache,mode=0777,id=pnpm,target=/pnpm/store \
    pnpm config set store-dir /pnpm/store && \
    pnpm config set package-import-method copy && \
    pnpm install --frozen-lockfile

# Stage 3: Build the application
FROM base AS builder
WORKDIR /app
# Bring in installed node_modules from the deps stage
COPY --from=deps /app/node_modules ./node_modules
# Copy all source files
COPY . .
# Set production mode for the build
ENV NODE_ENV=production
# Ensure the Next.js cache directory exists and has proper permissions
RUN mkdir -p /app/.next/cache && chown -R node:node /app/.next/cache
# Use a cache mount for Next.js cache to speed up rebuilds
RUN --mount=type=cache,mode=0777,id=nextjs-cache,target=/app/.next/cache \
    pnpm run build

# Stage 4: Production server
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
# Copy only the necessary artifacts from the builder stage
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
CMD ["node", "server.js"]