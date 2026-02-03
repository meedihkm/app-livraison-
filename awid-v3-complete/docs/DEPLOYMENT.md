# ═══════════════════════════════════════════════════════════════════════════════
# AWID v3.0 - GUIDE DE DÉPLOIEMENT
# Documentation complète pour le déploiement en production
# ═══════════════════════════════════════════════════════════════════════════════

## 📋 Prérequis

### Serveur
- Ubuntu 22.04 LTS ou Debian 12
- Minimum 4 Go RAM, 2 vCPUs
- 50 Go stockage SSD
- Accès SSH root ou sudo
- Nom de domaine configuré

### Logiciels
- Docker 24+ et Docker Compose v2
- Git
- Caddy ou Nginx (reverse proxy)

## 🚀 Déploiement Rapide (Docker)

### 1. Cloner le projet

```bash
git clone https://github.com/votre-org/awid-v3.git /opt/awid
cd /opt/awid
```

### 2. Configurer l'environnement

```bash
cp .env.example .env
nano .env
```

Variables à configurer :
```env
# Base de données
DATABASE_URL=postgresql://awid:votre_mot_de_passe@postgres:5432/awid
DB_PASSWORD=votre_mot_de_passe_securise

# Redis
REDIS_URL=redis://redis:6379

# Sécurité
JWT_SECRET=cle_secrete_tres_longue_minimum_64_caracteres
JWT_REFRESH_SECRET=autre_cle_secrete_tres_longue

# API
API_URL=https://api.votre-domaine.dz
ADMIN_URL=https://admin.votre-domaine.dz

# Firebase (optionnel - pour push notifications)
FIREBASE_PROJECT_ID=votre-projet
FIREBASE_SERVICE_ACCOUNT_PATH=/app/firebase-service-account.json
```

### 3. Lancer les services

```bash
docker compose up -d
```

### 4. Initialiser la base de données

```bash
# Appliquer les migrations
docker compose exec backend npm run db:migrate

# (Optionnel) Charger les données de démo
docker compose exec backend npm run db:seed
```

### 5. Configurer le reverse proxy (Caddy)

Le fichier `Caddyfile` est déjà configuré. Modifier les domaines :

```caddy
api.votre-domaine.dz {
    reverse_proxy backend:3000
}

admin.votre-domaine.dz {
    root * /srv/admin
    try_files {path} /index.html
    file_server
}
```

## 📱 Applications Mobiles

### Build Android

```bash
cd mobile/livreur
flutter build apk --release

# L'APK sera dans build/app/outputs/flutter-apk/app-release.apk
```

### Build iOS

```bash
cd mobile/livreur
flutter build ios --release

# Ouvrir dans Xcode pour archiver et publier
open ios/Runner.xcworkspace
```

### Distribution

1. **Livreurs** : Distribuer via Firebase App Distribution ou MDM
2. **Clients** : Publier sur Google Play / App Store
3. **Admin Mobile** : Distribution interne

## 🔒 Sécurité

### SSL/TLS
Caddy gère automatiquement les certificats Let's Encrypt.

### Firewall

```bash
# UFW
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (redirect)
ufw allow 443/tcp   # HTTPS
ufw enable
```

### Mises à jour de sécurité

```bash
# Activer les mises à jour automatiques
apt install unattended-upgrades
dpkg-reconfigure unattended-upgrades
```

### Rotation des secrets

Changer régulièrement :
- `JWT_SECRET` et `JWT_REFRESH_SECRET`
- Mot de passe PostgreSQL
- Clés d'API externes

## 📊 Monitoring

### Logs

```bash
# Voir les logs en temps réel
docker compose logs -f

# Logs d'un service spécifique
docker compose logs -f backend
```

### Métriques

Prometheus et Grafana sont pré-configurés (optionnel) :

```bash
# Activer le monitoring
docker compose --profile monitoring up -d
```

Accéder à Grafana : `https://monitoring.votre-domaine.dz`

### Alertes

Configurer les alertes dans Grafana pour :
- CPU > 80%
- Mémoire > 80%
- Erreurs 5xx
- Temps de réponse > 2s

## 💾 Sauvegardes

### Automatiques (cron)

```bash
# Ajouter au crontab
crontab -e

# Sauvegarde quotidienne à 2h du matin
0 2 * * * /opt/awid/scripts/db.sh backup >> /var/log/awid-backup.log 2>&1
```

### Manuelles

```bash
cd /opt/awid
./scripts/db.sh backup
```

### Restauration

```bash
./scripts/db.sh restore backups/awid_backup_20240115_020000.sql.gz
```

## 🔄 Mise à jour

### Via Docker

```bash
cd /opt/awid

# Sauvegarder avant
./scripts/db.sh backup

# Mettre à jour
git pull
docker compose pull
docker compose up -d

# Migrations si nécessaire
docker compose exec backend npm run db:migrate
```

### Rolling Update (zero downtime)

```bash
# Démarrer une nouvelle instance
docker compose up -d --no-deps --scale backend=2

# Attendre que la nouvelle instance soit prête
sleep 30

# Arrêter l'ancienne
docker compose up -d --no-deps --scale backend=1
```

## 🐛 Dépannage

### Le backend ne démarre pas

```bash
# Vérifier les logs
docker compose logs backend

# Vérifier la connexion à la BDD
docker compose exec backend npm run db:check

# Vérifier Redis
docker compose exec redis redis-cli ping
```

### Erreurs de connexion mobile

1. Vérifier que l'URL API est correcte dans l'app
2. Vérifier les certificats SSL
3. Tester avec `curl https://api.votre-domaine.dz/health`

### Performance lente

```bash
# Vérifier les ressources
docker stats

# Optimiser PostgreSQL
docker compose exec postgres psql -U awid -c "VACUUM ANALYZE;"

# Vider le cache Redis si nécessaire
docker compose exec redis redis-cli FLUSHDB
```

### Problèmes de synchronisation offline

1. Vérifier la connectivité réseau du livreur
2. Consulter les logs de synchronisation dans l'app
3. Forcer une synchronisation manuelle

## 📞 Support

### Logs utiles à fournir

1. Logs backend : `docker compose logs backend --tail=100`
2. Version : `git rev-parse HEAD`
3. Configuration (sans secrets) : `cat .env | grep -v SECRET | grep -v PASSWORD`

### Contacts

- Support technique : support@awid.dz
- Urgences : +213 XXX XXX XXX

## 📝 Checklist de déploiement

- [ ] Serveur provisionné et sécurisé
- [ ] DNS configuré
- [ ] Variables d'environnement définies
- [ ] Certificats SSL actifs
- [ ] Base de données migrée
- [ ] Tests de santé passent
- [ ] Sauvegardes automatiques configurées
- [ ] Monitoring en place
- [ ] Applications mobiles buildées et testées
- [ ] Documentation utilisateur fournie
- [ ] Formation des utilisateurs effectuée
