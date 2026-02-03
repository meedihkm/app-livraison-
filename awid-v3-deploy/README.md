# AWID v3.0 - Infrastructure de Déploiement

Ce dossier contient toute l'infrastructure nécessaire pour déployer AWID v3.0 sur Coolify.

---

## 📁 Structure

```
awid-v3-deploy/
├── docker/
│   ├── docker-compose.coolify.yml    # Configuration production Coolify
│   └── nginx/                        # Configurations Nginx (si besoin)
├── scripts/
│   ├── setup.sh                      # Installation automatique
│   ├── migrate.sh                    # Migrations DB manuelles
│   └── backup.sh                     # Backup manuel
├── .github/workflows/
│   └── deploy-coolify.yml            # CI/CD GitHub Actions
├── .env.example                      # Template variables d'environnement
├── coolify.json                      # Configuration Coolify (optionnel)
├── README.md                         # Ce fichier
└── README-DEPLOIEMENT.md             # Guide de déploiement complet

backend/                              # Code source backend (à copier)
admin/                                # Code source admin (à copier)
mobile/                               # Code source mobile (à copier)
```

---

## 🚀 Démarrage rapide

### 1. Copier les fichiers dans ton repo

Copie ces fichiers à la racine de ton repo GitHub :
- `docker/` → `docker/`
- `scripts/` → `scripts/`
- `.github/` → `.github/`
- `.env.example` → `.env.example`
- `coolify.json` → `coolify.json`
- `README-DEPLOIEMENT.md` → `README-DEPLOIEMENT.md`

### 2. Créer les Dockerfiles

Crée ces Dockerfiles dans ton repo :

**`backend/Dockerfile`** :
```dockerfile
FROM node:18-alpine

WORKDIR /app

# Installation des dépendances
COPY package*.json ./
RUN npm ci --only=production

# Copie du code
COPY . .

# Build (si TypeScript)
RUN npm run build || true

# Exposition du port
EXPOSE 3000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1

# Démarrage
CMD ["node", "dist/index.js"]
```

**`admin/Dockerfile`** :
```dockerfile
# Étape de build
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Étape de production (Nginx)
FROM nginx:alpine

# Copie du build
COPY --from=builder /app/dist /usr/share/nginx/html

# Configuration Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

**`admin/nginx.conf`** :
```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    # API proxy
    location /api {
        proxy_pass http://backend:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Static files
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache";
    }

    # Assets with caching
    location /assets {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### 3. Configurer les secrets GitHub (pour CI/CD)

Dans ton repo GitHub :
- **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Ajoute ces secrets :

| Secret | Description |
|--------|-------------|
| `SSH_PRIVATE_KEY` | Clé SSH privée pour accéder au VPS |
| `COOLIFY_HOST` | IP ou domaine de ton VPS |
| `COOLIFY_USER` | Utilisateur SSH (généralement `root`) |
| `COOLIFY_SERVICE_ID` | ID du service dans Coolify (optionnel) |

### 4. Déployer sur Coolify

Suivre le guide complet : **[README-DEPLOIEMENT.md](README-DEPLOIEMENT.md)**

Résumé rapide :
```bash
# 1. Sur ton VPS
ssh root@TON_IP
cd /data/coolify/services
git clone https://github.com/TON_COMPTE/awid-v3.git
cd awid-v3

# 2. Configurer
chmod +x scripts/setup.sh
./scripts/setup.sh

# 3. Configurer les domaines dans l'interface Coolify
# 4. Tester les URLs
```

---

## 🔄 Workflow de développement

```mermaid
git commit & push
       ↓
GitHub Actions
       ↓
  Tests + Build
       ↓
  Déploiement auto
       ↓
Coolify (VPS)
```

---

## 📊 Services inclus

| Service | Description | Port interne |
|---------|-------------|--------------|
| Backend | API Node.js/TypeScript | 3000 |
| Admin | Interface React | 80 |
| PostgreSQL | Base de données | 5432 |
| Redis | Cache/Sessions | 6379 |
| PGAdmin | Admin PostgreSQL | 80 |
| MinIO | Stockage S3 | 9000 / 9001 |
| Backup | Sauvegardes auto | - |

---

## 🔐 Sécurité

- ✅ HTTPS automatique (Let's Encrypt)
- ✅ Redis avec persistance AOF
- ✅ PostgreSQL sécurisé
- ✅ JWT avec secrets forts
- ✅ MinIO avec authentification
- ✅ Backups chiffrés sur MinIO

---

## 📞 Support

En cas de problème :
1. Consulter [README-DEPLOIEMENT.md](README-DEPLOIEMENT.md) section Troubleshooting
2. Vérifier les logs : `docker logs awid-backend`
3. Vérifier l'état : `docker ps`

---

## 📝 Licence

Propriétaire - AWID v3.0
