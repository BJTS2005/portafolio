# ============================================
# STAGE 1: Build
# ============================================
FROM node:22-alpine AS builder

# Crear usuario no privilegiado
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Asegurar permisos correctos
RUN chown nodejs:nodejs /app

# Copiar solo package files
COPY --chown=nodejs:nodejs package*.json ./

USER nodejs

# Instalar dependencias
RUN npm ci --only=production

# Copiar solo archivos necesarios
COPY --chown=nodejs:nodejs astro.config.mjs tsconfig.json ./
COPY --chown=nodejs:nodejs public ./public
COPY --chown=nodejs:nodejs src ./src

# Build
RUN npm run build

# ============================================
# STAGE 2: Production
# ============================================
FROM nginx:alpine

# Instalar dumb-init
RUN apk add --no-cache dumb-init

# Crear usuario no privilegiado
RUN addgroup -g 1001 -S nginx-app && \
    adduser -S nginx-app -u 1001

# Crear TODOS los directorios que nginx necesita con permisos correctos
RUN mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp \
             /var/log/nginx && \
    chown -R nginx-app:nginx-app /var/cache/nginx \
                                  /var/log/nginx && \
    chmod -R 755 /var/cache/nginx

# Copiar archivos
COPY --from=builder --chown=nginx-app:nginx-app /app/dist /usr/share/nginx/html
COPY --chown=nginx-app:nginx-app nginx.conf /etc/nginx/nginx.conf

USER nginx-app

# Puerto 8080 (no privilegiado)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["nginx", "-g", "daemon off;"]