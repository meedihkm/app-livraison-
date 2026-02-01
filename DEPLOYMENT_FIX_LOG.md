# 🚨 Log de Correction du Déploiement Backend-v4

**Date**: 27 Janvier 2026  
**Problème**: Page not found sur `/api/health` et `/api/v1/health`  
**Status**: 🔍 Diagnostic en cours

---

## 🔍 Diagnostic - Mise à jour

### État des Services ✅
- **Backend** : Running (healthy) ✅
- **URL** : http://mgkgcgkkssk0k0sw880ksgso0.62.171.130.92.sslip.io
- **Status Coolify** : Point vert = service actif

### Tests à Effectuer

**URLs à tester** :
1. `http://mgkgcgkkssk0k0sw880ksgso0.62.171.130.92.sslip.io/` (racine)
2. `http://mgkgcgkkssk0k0sw880ksgso0.62.171.130.92.sslip.io/health` (health simple)
3. `http://mgkgcgkkssk0k0sw880ksgso0.62.171.130.92.sslip.io/api/health` (health détaillé)
4. `http://mgkgcgkkssk0k0sw880ksgso0.62.171.130.92.sslip.io/api/v1/health` (API v1)

### Hypothèses
1. **Reverse Proxy** - Coolify redirige mal les requêtes
2. **Port interne** - Le backend écoute sur un autre port
3. **Path prefix** - L'application est montée sur un sous-chemin
4. **Logs d'erreur** - Erreurs silencieuses dans les logs

### Configuration Actuelle
- **Déploiement**: Coolify (VPS)
- **Services**: PostgreSQL + Redis + Backend
- **Point d'entrée**: `dist/main.js` (compilé depuis `src/main.ts`)
- **Port**: 3000 (par défaut)

---

## ❌ ERREUR DE DÉPLOIEMENT : Port Déjà Utilisé

### Erreur
```
Error response from daemon: driver failed programming external connectivity on endpoint backend-h8w0ks80og8c80o8go48cco4-002317750021: Bind for 0.0.0.0:3000 failed: port is already allocated
```

### Diagnostic
**Le port 3000 est déjà utilisé** par un autre container ou service sur le VPS.

### Cause Probable
Il y a probablement encore l'ancien container backend qui tourne et utilise le port 3000.

## 🔧 SOLUTIONS

### Solution 1 : Arrêter Tous les Services (Recommandée)
Dans Coolify :
1. **Cliquez sur "Stop"** pour arrêter complètement le service
2. **Attendez que tout soit arrêté**
3. **Cliquez sur "Start"** pour redémarrer proprement

### Solution 2 : Nettoyer les Containers
Dans Coolify > Terminal :
```bash
# Voir tous les containers
docker ps -a

# Arrêter tous les containers awid
docker stop $(docker ps -q --filter "name=awid")

# Supprimer les containers arrêtés
docker container prune -f
```

### Solution 3 : Changer le Port (Alternative)
Si le problème persiste, changer le port dans docker-compose.yml :
```yaml
ports:
  - "3001:3000"  # Port externe 3001 au lieu de 3000
```

## 📋 Action Immédiate
**Essayez la Solution 1** : Stop → Start dans Coolify

---

## 🔧 Plan de Correction

### Étape 1: Vérifier les Variables d'Environnement
```bash
# Dans Coolify, s'assurer que ces variables sont définies:
JWT_SECRET=<32+ caractères>
JWT_REFRESH_SECRET=<32+ caractères>
DB_HOST=postgres
DB_NAME=awid_v4
DB_USER=postgres
DB_PASSWORD=<mot de passe>
REDIS_HOST=redis
```

### Étape 2: Corriger le Dockerfile/Build
Le problème est probablement que le build TypeScript n'est pas fait correctement.

### Étape 3: Vérifier les Logs
Regarder les logs Coolify pour voir les erreurs de démarrage.

---

## 📋 Checklist de Vérification

- [ ] Variables d'environnement configurées
- [ ] Build TypeScript réussi
- [ ] PostgreSQL accessible
- [ ] Redis accessible
- [ ] Migrations exécutées
- [ ] Serveur démarré sur port 3000
- [ ] Endpoints accessibles

---

## 🚀 Prochaines Actions

1. Créer un Dockerfile optimisé
2. Vérifier les variables d'environnement
3. Tester le build local
4. Redéployer sur Coolify
