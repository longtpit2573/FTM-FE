# Stage 1: Build Stage
# ============================================
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including devDependencies for build)
RUN npm ci

# Copy source code
COPY . .

# Build the application
# Environment variables sẽ được inject lúc runtime
RUN npm run build

# ============================================
# Stage 2: Production Stage with Nginx
# ============================================
FROM nginx:alpine

# Copy built files from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy custom nginx main configuration
COPY nginx-main.conf /etc/nginx/nginx.conf

# Copy nginx site configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create nginx cache directories with proper permissions
RUN mkdir -p /var/cache/nginx/client_temp && \
    mkdir -p /var/cache/nginx/proxy_temp && \
    mkdir -p /var/cache/nginx/fastcgi_temp && \
    mkdir -p /tmp/client_temp && \
    mkdir -p /tmp/proxy_temp && \
    mkdir -p /tmp/fastcgi_temp && \
    mkdir -p /tmp/uwsgi_temp && \
    mkdir -p /tmp/scgi_temp && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /tmp && \
    chmod -R 755 /usr/share/nginx/html && \
    chmod -R 777 /tmp

# Run as non-root user
USER nginx

# Expose port 8080 (non-privileged)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1
CMD ["nginx", "-g", "daemon off;"]