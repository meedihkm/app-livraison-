# 🚀 Plan de Déploiement AWID v4.0

**Orchestration Complète Backend + Mobile + Infrastructure**

---

## 🎯 Objectif

Déployer l'écosystème complet AWID v4.0 en production avec:

- Backend API (Node.js/TypeScript)
- Applications Mobile (Flutter)
- Infrastructure (PostgreSQL, Redis, MinIO)
- Monitoring (Grafana, Prometheus, Sentry)
- CI/CD automatisé

---

## 📋 Architecture de Déploiement

```
┌─────────────────────────────────────────────────────────────┐
│                      CLOUDFLARE                              │
│  - CDN                                                       │
│  - DDoS Protection                                           │
│  - SSL/TLS                                                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   NGINX (Reverse Proxy)                      │
│  - Load Balancing                                            │
│  - SSL Termination                                           │
│  - Rate Limiting                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  API Server  │  │  API Server  │  │  API Server  │
│  Instance 1  │  │  Instance 2  │  │  Instance 3  │
│  (Docker)    │  │  (Docker)    │  │  (Docker)    │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       └─────────────────┼─────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  PostgreSQL  │  │    Redis     │  │    MinIO     │
│  (Primary)   │  │   (Cache)    │  │  (Storage)   │
│  + Replica   │  │  + Sentinel  │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
        │
        ▼
┌──────────────┐
│   Backups    │
│  (S3/MinIO)  │
└──────────────┘
```

---

## 🏗️ Phase 1: Préparation Infrastructure

### Étape 1.1: Serveur VPS

**Fournisseur Recommandé**: Hetzner (Allemagne)

**Configuration**:

- **CPU**: 4 vCPU
- **RAM**: 8 GB
- **Storage**: 160 GB SSD
- **Bandwidth**: 20 TB
- **Prix**: ~15€/mois

**OS**: Ubuntu 22.04 LTS

**Installation Initiale**:

```bash
# 1. Mise à jour système
apt update && apt upgrade -y

# 2. Installation Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 3. Installation Docker Compose
apt install docker-compose-plugin -y

# 4. Configuration firewall
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable

# 5. Création utilisateur deploy
adduser deploy
usermod -aG docker deploy
usermod -aG sudo deploy
```

---

### Étape 1.2: Nom de Domaine & DNS

**Domaine**: `awid.dz` (exemple)

**Configuration DNS** (Cloudflare):

```
Type    Name              Content              TTL    Proxy
A       @                 <SERVER_IP>          Auto   ✅
A       api               <SERVER_IP>          Auto   ✅
A       admin             <SERVER_IP>          Auto   ✅
A       grafana           <SERVER_IP>          Auto   ✅
CNAME   www               awid.dz              Auto   ✅
```

---

### Étape 1.3: SSL/TLS (Let's Encrypt)

```bash
# Installation Certbot
apt install certbot python3-certbot-nginx -y

# Génération certificats
certbot --nginx -d awid.dz -d www.awid.dz -d api.awid.dz -d admin.awid.dz -d grafana.awid.dz

# Auto-renouvellement
certbot renew --dry-run
```

---

## 🐳 Phase 2: Dockerisation

### Étape 2.1: Dockerfile Backend (Production)

```dockerfile
# backend-v4/Dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

# Copier package files
COPY package*.json ./
RUN npm ci --only=production

# Copier source
COPY . .

# Build TypeScript
RUN npm run build

# Production image
FROM node:20-alpine

WORKDIR /app

# Copier node_modules et build
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./

# User non-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
USER nodejs

EXPOSE 3000

CMD ["node", "dist/main.js"]
```

---

### Étape 2.2: Docker Compose Production

```yaml
# docker-compose.prod.yml
version: "3.8"

services:
  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: awid-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - api-1
      - api-2
    restart: unless-stopped
    networks:
      - awid-network

  # API Server 1
  api-1:
    build:
      context: ./backend-v4
      dockerfile: Dockerfile
    container_name: awid-api-1
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
      - INSTANCE_ID=api-1
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    networks:
      - awid-network
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1G

  # API Server 2
  api-2:
    build:
      context: ./backend-v4
      dockerfile: Dockerfile
    container_name: awid-api-2
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
      - INSTANCE_ID=api-2
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    networks:
      - awid-network
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1G

  # PostgreSQL
  postgres:
    image: postgres:16-alpine
    container_name: awid-postgres
    environment:
      - POSTGRES_DB=awid
      - POSTGRES_USER=awid
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./backups:/backups
    ports:
      - "5432:5432"
    restart: unless-stopped
    networks:
      - awid-network
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 2G

  # Redis
  redis:
    image: redis:7-alpine
    container_name: awid-redis
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis-data:/data
    ports:
      - "6379:6379"
    restart: unless-stopped
    networks:
      - awid-network

  # Workers
  worker:
    build:
      context: ./backend-v4
      dockerfile: Dockerfile
    container_name: awid-worker
    command: node dist/infrastructure/workers/index.js
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    networks:
      - awid-network

  # MinIO
  minio:
    image: minio/minio:latest
    container_name: awid-minio
    command: server /data --console-address ":9001"
    environment:
      - MINIO_ROOT_USER=${MINIO_USER}
      - MINIO_ROOT_PASSWORD=${MINIO_PASSWORD}
    volumes:
      - minio-data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    restart: unless-stopped
    networks:
      - awid-network

  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    container_name: awid-prometheus
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"
    restart: unless-stopped
    networks:
      - awid-network

  # Grafana
  grafana:
    image: grafana/grafana:latest
    container_name: awid-grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
      - GF_SERVER_ROOT_URL=https://grafana.awid.dz
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
    ports:
      - "3001:3000"
    depends_on:
      - prometheus
    restart: unless-stopped
    networks:
      - awid-network

volumes:
  postgres-data:
  redis-data:
  minio-data:
  prometheus-data:
  grafana-data:

networks:
  awid-network:
    driver: bridge
```

---

### Étape 2.3: Configuration Nginx

```nginx
# nginx/nginx.conf
upstream api_backend {
    least_conn;
    server api-1:3000 max_fails=3 fail_timeout=30s;
    server api-2:3000 max_fails=3 fail_timeout=30s;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/m;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/m;

server {
    listen 80;
    server_name api.awid.dz;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.awid.dz;

    # SSL
    ssl_certificate /etc/letsencrypt/live/api.awid.dz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.awid.dz/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Compression
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript;

    # API
    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;

        proxy_pass http://api_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Auth endpoints (stricter rate limit)
    location /api/v1/auth/ {
        limit_req zone=auth_limit burst=3 nodelay;

        proxy_pass http://api_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket
    location /socket.io/ {
        proxy_pass http://api_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # WebSocket timeouts
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
```

---

## 🔄 Phase 3: CI/CD

### Étape 3.1: GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
          cache-dependency-path: backend-v4/package-lock.json

      - name: Install dependencies
        working-directory: backend-v4
        run: npm ci

      - name: Run tests
        working-directory: backend-v4
        run: npm test

      - name: Run linter
        working-directory: backend-v4
        run: npm run lint

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./backend-v4
          push: true
          tags: awid/backend:latest,awid/backend:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to server
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /opt/awid
            docker-compose pull
            docker-compose up -d --no-deps --build api-1 api-2 worker
            docker system prune -f
```

---

## 📱 Phase 4: Déploiement Mobile

### Étape 4.1: Build Android

```bash
# Build APK
cd mobile-v4
flutter build apk --release --split-per-abi

# Build App Bundle (Google Play)
flutter build appbundle --release
```

### Étape 4.2: Build iOS

```bash
# Build iOS
flutter build ios --release

# Archive (Xcode)
# Ouvrir Xcode et créer archive pour App Store
```

### Étape 4.3: Distribution

**Android**:

- Google Play Store
- APK direct (pour tests)

**iOS**:

- Apple App Store
- TestFlight (pour tests)

---

## 📊 Phase 5: Monitoring

### Étape 5.1: Dashboards Grafana

**Dashboards à créer**:

1. **System Metrics**: CPU, RAM, Disk, Network
2. **API Metrics**: Requests/s, Latency, Errors
3. **Database Metrics**: Connections, Queries, Slow queries
4. **Business Metrics**: Orders, Deliveries, Revenue

### Étape 5.2: Alertes

**Alertes Slack/Email**:

- CPU > 80% pendant 5 min
- RAM > 90% pendant 5 min
- Disk > 85%
- API errors > 1% pendant 5 min
- Database connections > 80%
- Response time > 1s (p95)

---

## 🔒 Phase 6: Sécurité

### Checklist Sécurité

- [ ] HTTPS obligatoire (SSL/TLS)
- [ ] Firewall configuré (UFW)
- [ ] Fail2ban actif
- [ ] SSH par clé uniquement
- [ ] Secrets dans variables d'environnement
- [ ] Rate limiting configuré
- [ ] CORS restrictif
- [ ] Helmet.js activé
- [ ] SQL injection protection (parameterized queries)
- [ ] XSS protection
- [ ] CSRF protection
- [ ] Backup automatique quotidien
- [ ] Logs centralisés
- [ ] Monitoring actif
- [ ] Mises à jour sécurité automatiques

---

## 💾 Phase 7: Backup & Recovery

### Étape 7.1: Backup Automatique

```bash
#!/bin/bash
# /opt/awid/scripts/backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"

# Backup PostgreSQL
docker exec awid-postgres pg_dump -U awid awid | gzip > "$BACKUP_DIR/postgres_$DATE.sql.gz"

# Backup Redis
docker exec awid-redis redis-cli --rdb /data/dump.rdb
docker cp awid-redis:/data/dump.rdb "$BACKUP_DIR/redis_$DATE.rdb"

# Backup MinIO
docker exec awid-minio mc mirror /data "$BACKUP_DIR/minio_$DATE"

# Nettoyage (garder 30 jours)
find $BACKUP_DIR -name "*.gz" -mtime +30 -delete
find $BACKUP_DIR -name "*.rdb" -mtime +30 -delete

# Upload vers S3 (optionnel)
# aws s3 sync $BACKUP_DIR s3://awid-backups/
```

**Cron**:

```bash
# Backup quotidien à 2h du matin
0 2 * * * /opt/awid/scripts/backup.sh
```

---

## 📋 Checklist Déploiement

### Pré-déploiement

- [ ] Tests passent (backend)
- [ ] Tests passent (mobile)
- [ ] Load testing effectué
- [ ] Security audit effectué
- [ ] Documentation à jour
- [ ] Variables d'environnement configurées
- [ ] SSL/TLS configuré
- [ ] DNS configuré
- [ ] Backup configuré

### Déploiement

- [ ] Mode maintenance activé
- [ ] Backup base de données
- [ ] Migration base de données
- [ ] Déploiement code
- [ ] Vérification health checks
- [ ] Tests smoke
- [ ] Mode maintenance désactivé

### Post-déploiement

- [ ] Monitoring dashboards vérifiés
- [ ] Logs vérifiés
- [ ] Performance vérifiée
- [ ] Alertes configurées
- [ ] Documentation mise à jour
- [ ] Communication équipe
- [ ] Rollback plan prêt

---

## 🎯 Timeline

### Semaine 1: Infrastructure

- Jour 1-2: Setup serveur VPS
- Jour 3-4: Configuration Docker
- Jour 5: Tests infrastructure

### Semaine 2: Backend

- Jour 1-2: Dockerisation backend
- Jour 3-4: CI/CD
- Jour 5: Tests déploiement

### Semaine 3: Mobile

- Jour 1-3: Build & tests mobile
- Jour 4-5: Distribution stores

### Semaine 4: Monitoring & Sécurité

- Jour 1-2: Dashboards Grafana
- Jour 3-4: Alertes & backup
- Jour 5: Security audit

### Semaine 5: Production

- Jour 1-2: Déploiement staging
- Jour 3-4: Tests utilisateurs
- Jour 5: Déploiement production

---

## 💰 Coûts Estimés

### Infrastructure (Mensuel)

- **VPS Hetzner**: 15€
- **Domaine .dz**: 5€
- **Cloudflare**: 0€ (gratuit)
- **OneSignal**: 0€ (gratuit jusqu'à 10k users)
- **Sentry**: 0€ (gratuit jusqu'à 5k events/mois)
- **Backup S3**: 5€

**Total**: ~25€/mois

### Stores (One-time)

- **Google Play**: 25$ (one-time)
- **Apple App Store**: 99$/an

---

## 📞 Support

- **Email**: devops@awid.dz
- **Slack**: #awid-devops
- **On-call**: Rotation 24/7

---

**Créé**: 26 Janvier 2026  
**Version**: 4.0.0  
**Status**: 🚀 Prêt à déployer
