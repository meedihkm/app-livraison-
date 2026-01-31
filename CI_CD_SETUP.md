# Configuration CI/CD - Déploiement Automatique

## 🎯 Objectif
Chaque push sur `main` déclenche automatiquement :
1. **Déploiement API** sur Coolify
2. **Build APK** sur GitHub Actions

---

## 📋 Prérequis

### 1. GitHub Repository
- Repository public ou privé sur GitHub
- GitHub Actions activé (gratuit pour les repos publics)

### 2. Coolify Configuration
- Instance Coolify en ligne (déjà configurée)
- Accès au projet AWID

---

## 🚀 Configuration

### Étape 1: Configurer Coolify (Webhooks)

Dans Coolify, configure le déploiement automatique :

1. **Va sur Coolify** → https://62.171.130.92:8000
2. **Sélectionne le projet** AWID APPLICATION
3. **Onglet "Configuration"** → Section "Git Source"
4. **Vérifie**:
   - Repository: `https://github.com/meedihkm/app-livraison-`
   - Branch: `main`
   - Auto-deploy: ✅ Activé

#### Option A: Déploiement Auto (Recommandé)
Coolify détecte automatiquement les push GitHub. Rien à faire !

#### Option B: Webhook Manuel (Si auto ne marche pas)
Si Coolify ne détecte pas automatiquement :

```bash
# Dans Coolify, récupère le webhook URL:
# Configuration → Webhooks → Copy URL

# Puis dans GitHub:
# Settings → Webhooks → Add webhook
# Payload URL: [URL_COOLIFY_WEBHOOK]
# Content type: application/json
# Events: Just the push event
```

---

### Étape 2: Vérifier GitHub Actions

Le workflow est déjà créé dans `.github/workflows/ci-cd.yml`

**Vérifie que le token est configuré** :
- Va sur GitHub → Settings → Secrets and variables → Actions
- Vérifie que `GITHUB_TOKEN` est disponible (créé automatiquement)

---

### Étape 3: Tester le Pipeline

1. **Fais un commit** sur `main`:
```bash
git add .
git commit -m "test: CI/CD déploiement auto"
git push origin main
```

2. **Vérifie sur GitHub**:
   - Va sur https://github.com/meedihkm/app-livraison-/actions
   - Tu dois voir le workflow "CI/CD - Deploy & Build" en cours

3. **Vérifie Coolify**:
   - Va sur https://62.171.130.92:8000
   - Déploiement en cours → "Deploying..."

4. **Vérifie la Release**:
   - https://github.com/meedihkm/app-livraison-/releases
   - Nouvelle release créée avec l'APK

---

## 📊 Workflow Détaillé

### Déclencheurs
```yaml
on:
  push:
    branches: [ main, master ]   # Sur chaque push main
```

### Jobs

| Job | Description | Dépendances |
|-----|-------------|-------------|
| `deploy-api` | Déploie sur Coolify | - |
| `build-apk` | Build l'APK Android | deploy-api |
| `notify` | Notification finale | deploy-api, build-apk |

### Étapes Build APK
1. Checkout du code
2. Setup Java 21
3. Setup Flutter 3.27.0
4. `flutter pub get`
5. `flutter analyze` (optionnel)
6. `flutter build apk --release`
7. Rename avec version + date
8. Upload artifact
9. Create/update Release GitHub

---

## 🔧 Dépannage

### Le déploiement Coolify ne se fait pas

**Vérifie**:
1. Coolify est-il configuré sur la bonne branche ?
2. Le webhook GitHub est-il actif ?
3. Dans Coolify: **Deployments** → voir les logs

**Solution manuelle**:
```bash
# Dans Coolify, clique sur "Redeploy"
# ou utilise le webhook:
curl -X POST [COOLIFY_WEBHOOK_URL]
```

### Le build APK échoue

**Vérifie sur GitHub Actions**:
1. Va sur https://github.com/meedihkm/app-livraison-/actions
2. Clique sur le workflow en échec
3. Voir les logs d'erreur

**Erreurs communes**:
- `flutter pub get` failed → Vérifie pubspec.yaml
- Build failed → Vérifie les erreurs Dart
- Gradle error → Version incompatible

### Pas de Release créée

**Vérifie**:
1. Le job `build-apk` a réussi
2. Le token `GITHUB_TOKEN` a les permissions
3. Dans Settings → Actions → General → Workflow permissions → Read and write permissions

---

## 📱 Récupérer l'APK

### Méthode 1: GitHub Releases (Recommandé)
1. Va sur https://github.com/meedihkm/app-livraison-/releases
2. Télécharge la dernière version (APK)

### Méthode 2: GitHub Actions Artifact
1. Va sur https://github.com/meedihkm/app-livraison-/actions
2. Clique sur le dernier workflow réussi
3. Section "Artifacts" → Télécharge

### Méthode 3: Direct depuis le repo
```bash
# L'APK est versionné avec: awid-v1.0.0-20260131_1430.apk
git pull origin main
# APK disponible dans les Releases, pas dans le repo
```

---

## 🔄 Cycle de vie

```
Push sur main
     ↓
GitHub Actions déclenché
     ↓
┌─────────────────┐    ┌─────────────────┐
│  1. Deploy API  │───→│ Coolify redeploy│
│  (notify only)  │    │   (auto-detect) │
└─────────────────┘    └─────────────────┘
     ↓
┌─────────────────┐    ┌─────────────────┐
│  2. Build APK   │───→│ Flutter build   │
│  (~10 minutes)  │    │   --release     │
└─────────────────┘    └─────────────────┘
     ↓
┌─────────────────┐
│ 3. Create       │
│    Release      │
│    with APK     │
└─────────────────┘
     ↓
✅ Terminé !
```

---

## 🎓 Conseils

### Pour forcer un redeploy sans changer le code:
```bash
# Crée un commit vide
git commit --allow-empty -m "chore: redeploy"
git push origin main
```

### Pour ignorer le CI temporairement:
```bash
# Dans le message de commit
git commit -m "fix: correction bug [skip ci]"
```

### Pour déployer une branche spécifique:
Modifier temporairement `.github/workflows/ci-cd.yml`:
```yaml
on:
  push:
    branches: [ main, ma-branche-test ]
```

---

## 📞 Support

Si problème:
1. Vérifie les logs GitHub Actions
2. Vérifie les logs Coolify (Deployments)
3. Vérifie que le repo est bien connecté à Coolify
