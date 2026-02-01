# 🚀 Guide de déploiement rapide - AWID v4

## 📱 Étape 1: Récupérer l'APK mobile (en cours)

Le workflow GitHub Actions est en train de builder l'APK. Une fois terminé:

1. Va sur https://github.com/meedihkm/awidv3/actions
2. Clique sur le dernier workflow "CI/CD"
3. Télécharge l'artifact `android-debug-apk`
4. Installe l'APK sur ton téléphone pour tester

## 🖥️ Étape 2: Déployer le backend sur Coolify

### A. Préparer les secrets

Génère des secrets forts (exécute ces commandes sur ton VPS):

```bash
# Générer les secrets
echo "DB_PASSWORD=$(openssl rand -base64 32)"
echo "REDIS_PASSWORD=$(openssl rand -base64 32)"
echo "JWT_SECRET=$(openssl rand -base64 32)"
echo "JWT_REFRESH_SECRET=$(openssl rand -base64 32)"
```

**Sauvegarde ces valeurs quelque part en sécurité!**

### B. Configurer Coolify

1. **Connecte-toi à Coolify** sur ton VPS
   - URL: `http://IP_DE_TON_VPS:8000` (ou ton domaine Coolify)

2. **Créer un nouveau projet**
   - Nom: `AWID Backend v4`
   - Type: `Docker Compose`

3. **Configurer le repository**
   - Repository: `https://github.com/meedihkm/awidv3`
   - Branch: `main`
   - Docker Compose Path: `backend-v4/docker-compose.yml`

4. **Ajouter les variables d'environnement**
   
   Dans Coolify, va dans "Environment Variables" et ajoute:

   ```env
   NODE_ENV=production
   PORT=3000
   
   # Database
   DB_NAME=awid_db
   DB_USER=awid_user
   DB_PASSWORD=<COLLER_LE_SECRET_GENERE>
   
   # Redis
   REDIS_PASSWORD=<COLLER_LE_SECRET_GENERE>
   
   # JWT
   JWT_SECRET=<COLLER_LE_SECRET_GENERE>
   JWT_REFRESH_SECRET=<COLLER_LE_SECRET_GENERE>
   JWT_EXPIRES_IN=15m
   JWT_REFRESH_EXPIRES_IN=7d
   
   # CORS (remplace par ton domaine)
   CORS_ORIGIN=*
   ```

5. **Configurer le domaine (optionnel)**
   - Si tu as un domaine: `api.ton-domaine.com`
   - Active le SSL automatique (Let's Encrypt)
   - Sinon, utilise l'IP du VPS

6. **Déployer**
   - Clique sur "Deploy"
   - Attends que le déploiement se termine (5-10 minutes)

### C. Vérifier le déploiement

```bash
# Se connecter au VPS
ssh user@ton-vps

# Vérifier que les services sont up
docker ps | grep awid

# Tester l'API
curl http://localhost:3000/health
# Devrait retourner: {"status":"ok",...}
```

## 🔗 Étape 3: Connecter l'app mobile au backend

### Option 1: Avec un domaine

Si tu as configuré un domaine (ex: `api.ton-domaine.com`):

```dart
// mobile-v4/lib/core/config/api_config.dart
const String API_BASE_URL = 'https://api.ton-domaine.com';
```

### Option 2: Avec l'IP du VPS

```dart
// mobile-v4/lib/core/config/api_config.dart
const String API_BASE_URL = 'http://IP_DE_TON_VPS:3000';
```

Ensuite:
1. Rebuild l'APK avec la nouvelle URL
2. Ou modifie directement dans l'app si tu as un système de configuration

## 📊 Étape 4: Initialiser la base de données

### A. Créer un utilisateur admin

```bash
# Se connecter au container backend
docker exec -it awid-backend sh

# Créer un utilisateur admin (à implémenter dans le backend)
# Ou utiliser les seeds
npm run seed
```

### B. Vérifier les données

```bash
# Se connecter à PostgreSQL
docker exec -it awid-postgres psql -U awid_user -d awid_db

# Lister les tables
\dt

# Vérifier les utilisateurs
SELECT id, email, role FROM users;

# Quitter
\q
```

## ✅ Checklist de déploiement

- [ ] APK mobile téléchargé et testé
- [ ] Secrets générés et sauvegardés
- [ ] Projet Coolify créé
- [ ] Variables d'environnement configurées
- [ ] Domaine configuré (optionnel)
- [ ] Backend déployé avec succès
- [ ] Health check passe (`/health` retourne OK)
- [ ] Base de données initialisée
- [ ] Utilisateur admin créé
- [ ] App mobile connectée au backend
- [ ] Test de bout en bout réussi

## 🆘 Dépannage rapide

### Le backend ne démarre pas

```bash
# Voir les logs
docker logs awid-backend

# Redémarrer
docker restart awid-backend
```

### Erreur de connexion à la base de données

```bash
# Vérifier PostgreSQL
docker logs awid-postgres

# Vérifier les variables d'environnement
docker exec awid-backend env | grep DB_
```

### L'app mobile ne se connecte pas

1. Vérifie que l'URL dans l'app est correcte
2. Vérifie que le backend est accessible: `curl http://IP:3000/health`
3. Vérifie les logs du backend: `docker logs awid-backend`
4. Vérifie CORS si tu utilises un domaine différent

## 📱 Prochaines étapes

1. **Tester l'application complète**
   - Créer un compte
   - Créer une commande
   - Tester les fonctionnalités

2. **Configurer le monitoring**
   - Coolify fournit des métriques de base
   - Optionnel: Configurer Sentry pour les erreurs

3. **Sauvegardes**
   - Coolify sauvegarde automatiquement les volumes
   - Optionnel: Configurer des sauvegardes externes

4. **Optimisations**
   - Configurer un CDN pour les images
   - Optimiser les performances
   - Mettre en place un système de cache

## 📚 Documentation complète

Pour plus de détails, consulte:
- `backend-v4/DEPLOYMENT.md` - Guide complet de déploiement
- `mobile-v4/README.md` - Documentation de l'app mobile
- `backend-v4/README.md` - Documentation du backend

## 🎯 Support

Si tu rencontres des problèmes:
1. Vérifie les logs: `docker logs awid-backend`
2. Vérifie la documentation: `backend-v4/DEPLOYMENT.md`
3. Vérifie que tous les services sont up: `docker ps`
