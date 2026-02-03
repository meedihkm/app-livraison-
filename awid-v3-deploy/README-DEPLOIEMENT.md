# 🚀 AWID v3.0 - Guide de Déploiement Coolify

Ce guide explique comment déployer AWID v3.0 sur Coolify avec une installation entièrement automatique.

---

## 📋 Table des matières

1. [Architecture](#architecture)
2. [Prérequis](#prérequis)
3. [Installation automatique](#installation-automatique)
4. [Configuration Coolify](#configuration-coolify)
5. [Vérification](#vérification)
6. [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         COOLIFY VPS                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Backend   │  │    Admin    │  │      PGAdmin        │ │
│  │   :3000     │  │     :80     │  │       :5050         │ │
│  │  Node.js    │  │   React     │  │    PostgreSQL UI    │ │
│  └──────┬──────┘  └─────────────┘  └─────────────────────┘ │
│         │                                                   │
│  ┌──────┴─────────────────────────────────────────────────┐│
│  │              Réseau Docker (awid-network)               ││
│  └──────┬─────────────────────────────────────────────────┘│
│         │                                                   │
│  ┌──────┴──────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  PostgreSQL │  │    Redis    │  │       MinIO         │ │
│  │    :5432    │  │    :6379    │  │   :9000 / :9001     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│         │                                                   │
│  ┌──────┴─────────────────────────────────────────────────┐│
│  │  Volumes persistants (postgres_data, redis_data...)     ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Prérequis

### Sur ton VPS (déjà fait ✅)
- [x] VPS avec IP publique
- [x] Coolify installé
- [x] Accès SSH root

### Dans Coolify
- [x] Accès à l'interface web Coolify
- [x] GitHub/GitLab connecté (pour CI/CD optionnel)

---

## 🚀 Installation Automatique

### Étape 1 : Cloner le repo sur ton VPS

```bash
# Connecte-toi en SSH à ton VPS
ssh root@TON_IP

# Va dans le répertoire de Coolify
cd /data/coolify/services

# Clone le repo
git clone https://github.com/TON_COMPTE/awid-v3.git
cd awid-v3
```

### Étape 2 : Configurer les variables d'environnement

```bash
# Copie le fichier example
cp .env.example .env

# Édite le fichier avec tes valeurs
nano .env
```

**Variables obligatoires à modifier :**

```env
# Base de données (forte recommandation)
POSTGRES_PASSWORD=ton_mot_de_passe_super_fort_123

# PGAdmin
PGADMIN_EMAIL=tonemail@domaine.com
PGADMIN_PASSWORD=ton_mot_de_passe_pgadmin

# JWT (génère des clés longues !)
JWT_SECRET=$(openssl rand -base64 64)
JWT_REFRESH_SECRET=$(openssl rand -base64 64)

# MinIO
MINIO_ROOT_PASSWORD=ton_mot_de_passe_minio_super_fort
```

### Étape 3 : Lancer l'installation automatique

```bash
# Rendre le script exécutable
chmod +x scripts/setup.sh

# Lancer l'installation
./scripts/setup.sh
```

Ce script va automatiquement :
1. ✅ Vérifier Docker et Docker Compose
2. ✅ Créer les répertoires nécessaires
3. ✅ Lancer tous les services (PostgreSQL, Redis, MinIO, PGAdmin)
4. ✅ Attendre que tout soit prêt (healthchecks)
5. ✅ Créer le bucket MinIO
6. ✅ Exécuter les migrations de base de données

**Durée : ~3-5 minutes**

---

## ⚙️ Configuration Coolify

### Étape 4 : Créer les Services dans Coolify

Va dans l'interface Coolify : `http://TON_IP:8000`

#### 4.1 Créer le Service Backend

1. **Services** → **Add New Service** → **Docker Compose**
2. **Name** : `awid-backend`
3. **Docker Compose Path** : `docker/docker-compose.coolify.yml`
4. **Service** : Sélectionne `backend`
5. **Domain** : Laisse Coolify générer (ex: `api-xxxx.coolify.io`)
6. **Environment Variables** : Copie-colle tout ton fichier `.env`
7. **Deploy**

#### 4.2 Créer le Service Admin

1. **Services** → **Add New Service** → **Docker Compose**
2. **Name** : `awid-admin`
3. **Docker Compose Path** : `docker/docker-compose.coolify.yml`
4. **Service** : Sélectionne `admin`
5. **Domain** : Laisse Coolify générer (ex: `xxxx.coolify.io`)
6. **Deploy**

#### 4.3 Créer le Service PGAdmin

1. **Services** → **Add New Service** → **Docker Compose**
2. **Name** : `awid-pgadmin`
3. **Docker Compose Path** : `docker/docker-compose.coolify.yml`
4. **Service** : Sélectionne `pgadmin`
5. **Domain** : Coolify génère (ex: `db-xxxx.coolify.io`)
6. **Deploy**

#### 4.4 Créer le Service MinIO (Console)

1. **Services** → **Add New Service** → **Docker Compose**
2. **Name** : `awid-minio-console`
3. **Docker Compose Path** : `docker/docker-compose.coolify.yml`
4. **Service** : Sélectionne `minio`
5. **Port** : `9001` (console web)
6. **Domain** : Coolify génère (ex: `console-s3-xxxx.coolify.io`)
7. **Deploy**

### Étape 5 : Configurer les Domaines (Option C)

Dans Coolify, configure comme ça :

| Service | Domaine Coolify | Rôle |
|---------|-----------------|------|
| backend | `api-xxxx.coolify.io` | API Backend |
| admin | `xxxx.coolify.io` | Interface Admin |
| pgadmin | `db-xxxx.coolify.io` | Gestion BDD |
| minio | `console-s3-xxxx.coolify.io` | Console S3 |

**HTTPS** : Coolify génère automatiquement les certificats Let's Encrypt ! ✅

---

## ✅ Vérification

### Vérifier que tout fonctionne

```bash
# Sur ton VPS, vérifie les containers
docker ps

# Tu devrais voir :
# - awid-backend
# - awid-admin
# - awid-postgres
# - awid-redis
# - awid-pgadmin
# - awid-minio
# - awid-backup
```

### Tests manuels

1. **Backend** : Ouvre `https://api-xxxx.coolify.io/health`
   - Devrait retourner `{"status":"ok"}`

2. **Admin** : Ouvre `https://xxxx.coolify.io`
   - Devrait afficher le login admin

3. **PGAdmin** : Ouvre `https://db-xxxx.coolify.io`
   - Login avec `PGADMIN_EMAIL` / `PGADMIN_PASSWORD`
   - Ajoute un serveur PostgreSQL :
     - Host : `postgres`
     - Port : `5432`
     - Database : `awid_v3`
     - User : `awid_admin`
     - Password : (ton `POSTGRES_PASSWORD`)

4. **MinIO** : Ouvre `https://console-s3-xxxx.coolify.io`
   - Login avec `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`

---

## 🔧 Configuration Post-Installation

### 1. Créer le compte Admin

```bash
# Sur le VPS
cd /data/coolify/services/awid-v3

# Exécute le script de création d'admin
docker-compose -f docker/docker-compose.coolify.yml exec backend node scripts/create-admin.js

# Ou utilise l'API directement
curl -X POST https://api-xxxx.coolify.io/auth/setup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@awid.dz",
    "password": "SuperPassword123!",
    "name": "Super Admin"
  }'
```

### 2. Configurer les webhooks (Optionnel)

Si tu veux des notifications Discord/Slack :

```bash
# Édite le fichier .env et ajoute :
DISCORD_WEBHOOK=https://discord.com/api/webhooks/...
```

### 3. Vérifier les backups

```bash
# Voir les backups existants
docker exec awid-minio mc ls local/awid-uploads/backups/

# Les backups sont automatiques tous les jours à 2h du matin
```

---

## 🐛 Troubleshooting

### Problème : PostgreSQL ne démarre pas

```bash
# Voir les logs
docker logs awid-postgres

# Réinitialiser (⚠️ perd les données)
docker-compose -f docker/docker-compose.coolify.yml down -v
docker-compose -f docker/docker-compose.coolify.yml up -d
```

### Problème : Backend ne se connecte pas à la DB

```bash
# Vérifier la DATABASE_URL dans .env
cat .env | grep DATABASE_URL

# Devrait être :
# postgresql://awid_admin:PASSWORD@postgres:5432/awid_v3?schema=public

# Redémarrer le backend
docker restart awid-backend
```

### Problème : Certificat HTTPS non généré

Dans Coolify :
1. Va dans les **Settings** du service
2. Vérifie que **HTTPS** est activé
3. Clique sur **Regenerate SSL Certificate**
4. Attends 2-3 minutes

### Problème : Migrations échouent

```bash
# Exécuter manuellement
docker-compose -f docker/docker-compose.coolify.yml exec backend npm run migrate
```

---

## 📚 Commandes utiles

```bash
# Voir les logs en temps réel
docker logs -f awid-backend
docker logs -f awid-admin
docker logs -f awid-postgres

# Redémarrer un service
docker restart awid-backend

# Entrer dans un container
docker exec -it awid-backend sh
docker exec -it awid-postgres psql -U awid_admin -d awid_v3

# Backup manuel
docker exec awid-postgres pg_dump -U awid_admin awid_v3 > backup-$(date +%Y%m%d).sql

# Restore
cat backup-20240101.sql | docker exec -i awid-postgres psql -U awid_admin -d awid_v3
```

---

## 🔄 Mise à jour (Déploiement continu)

Avec la CI/CD configurée :

```bash
# Sur ton ordinateur
git add .
git commit -m "Nouvelle fonctionnalité"
git push origin main

# Coolify déploie automatiquement !
```

Ou manuellement sur le VPS :

```bash
cd /data/coolify/services/awid-v3
git pull origin main
docker-compose -f docker/docker-compose.coolify.yml up -d --build
docker-compose -f docker/docker-compose.coolify.yml exec backend npm run migrate
```

---

## 📞 Support

Si tu as des problèmes :

1. Vérifie les logs : `docker logs awid-backend`
2. Vérifie l'état : `docker ps`
3. Redémarre les services : `docker-compose restart`

---

## ✅ Checklist finale

- [ ] Cloner le repo sur le VPS
- [ ] Créer le fichier `.env` avec les bonnes valeurs
- [ ] Lancer `./scripts/setup.sh`
- [ ] Créer les 4 services dans Coolify
- [ ] Vérifier que les domaines sont accessibles
- [ ] Configurer PGAdmin avec la connexion PostgreSQL
- [ ] Créer le compte admin
- [ ] Tester le login sur l'interface admin
- [ ] Vérifier que MinIO fonctionne
- [ ] Configurer les secrets GitHub (pour CI/CD)

**🎉 Une fois tout ça fait, ton application est en ligne !**
