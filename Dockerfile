# Build stage
FROM node:22-bookworm AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Copy scripts needed for prepare hook
COPY scripts ./scripts

# Install ALL dependencies (including devDependencies)
RUN npm ci

# Copy source files and configuration
COPY src ./src
COPY tests ./tests
COPY tsconfig.json ./
COPY rollup.config.mjs ./
COPY puppeteer.config.cjs ./

# Build the project
RUN npm run build

# Production stage
FROM node:22-bookworm

# Install Chromium and dependencies
RUN apt-get update && apt-get install -y \
    chromium \
    chromium-sandbox \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Set Chrome executable path for Puppeteer
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

WORKDIR /app

# Copy package files
COPY package*.json ./

# Copy scripts needed for prepare hook
COPY scripts ./scripts

# Install all dependencies (including devDependencies for runtime)
# Note: Some packages in devDependencies (yargs, debug, @modelcontextprotocol/sdk, puppeteer)
# are actually used at runtime via src/third_party/index.ts
RUN npm ci

# Copy built files from builder stage
COPY --from=builder /app/build ./build

# Create non-root user for security
RUN groupadd -r chrome && useradd -r -g chrome -G audio,video chrome \
    && mkdir -p /home/chrome/Downloads \
    && chown -R chrome:chrome /home/chrome \
    && chown -R chrome:chrome /app

# Set Puppeteer args for containerized environment
ENV PUPPETEER_ARGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu"

# Switch to non-root user
USER chrome

# Expose port for MCP communication (if needed)
EXPOSE 8080

# Set entrypoint to the built MCP server
ENTRYPOINT ["node", "build/src/index.js"]

# Default arguments (can be overridden)
CMD ["--headless"]
