# 🚀 Déploiement GitHub - API v2

Ce guide explique comment pousser l'API v2 sur GitHub.

## 📋 Prérequis

- Git installé
- Accès au repository: https://github.com/meedihkm/app-livraison-
- Token GitHub (si authentification requise)

## 🚀 Méthode 1: Script PowerShell (Recommandé)

```powershell
# Ouvrir PowerShell dans le dossier du projet
# Exécuter le script
.\deploy-to-github.ps1
```

Le script va:
1. Cloner le repo existant
2. Supprimer tout le contenu
3. Copier api-v2 à la racine
4. Pousser sur GitHub

## 🚀 Méthode 2: Script Batch (Windows)

```cmd
# Ouvrir CMD dans le dossier du projet
# Exécuter le script
deploy-to-github.bat
```

## 🚀 Méthode 3: Manuel (Git)

```bash
# 1. Se positionner dans api-v2
cd api-v2

# 2. Initialiser un nouveau repo git
rm -rf .git  # Si existe déjà
git init

# 3. Ajouter le remote
git remote add origin https://github.com/meedihkm/app-livraison-.git

# 4. Copier package.json
cp ../package.json .

# 5. Créer .gitignore
cat > .gitignore << 'EOF'
node_modules/
.env
.env.local
logs/
*.log
uploads/*
!uploads/.gitkeep
.vscode/
.idea/
.DS_Store
Thumbs.db
EOF

# 6. Commit
git add -A
git commit -m "🚀 API v2 - Refactorisation complète Finance/Stats"

# 7. Push (force pour remplacer)
git push -f origin main
```

## 🔧 Configuration GitHub

### Token d'accès personnel (si 2FA activée)

1. Aller sur GitHub → Settings → Developer settings → Personal access tokens
2. Générer un nouveau token avec les droits `repo`
3. Utiliser l'URL avec token:
   ```
   https://TOKEN@github.com/meedihkm/app-livraison-.git
   ```

### Authentification par clé SSH

```bash
# Générer une clé SSH
ssh-keygen -t ed25519 -C "mehdihakkoum@gmail.com"

# Copier la clé publique
cat ~/.ssh/id_ed25519.pub

# Ajouter sur GitHub → Settings → SSH and GPG keys

# Utiliser l'URL SSH
git remote set-url origin git@github.com:meedihkm/app-livraison-.git
```

## ✅ Vérification

Après le push, vérifier sur GitHub:

1. Aller sur https://github.com/meedihkm/app-livraison-
2. Vérifier que les fichiers sont présents:
   - `index.js`
   - `package.json`
   - `routes/`
   - `services/`
   - `migrations/`
3. Vérifier le commit: "🚀 API v2 - Refactorisation complète Finance/Stats"

## 🌐 Déploiement sur Vercel/Railway/Render

### Vercel

1. Connecter le repo GitHub sur Vercel
2. Configuration:
   - Framework Preset: Other
   - Root Directory: . (racine)
   - Build Command: (vide)
   - Output Directory: (vide)
   - Install Command: `npm install`
3. Variables d'environnement:
   - `DATABASE_URL`
   - `JWT_SECRET`
   - `SENTRY_DSN`
   - `REDIS_URL`

### Railway

1. New Project → Deploy from GitHub repo
2. Sélectionner `meedihkm/app-livraison-`
3. Ajouter les variables d'environnement
4. Deploy

### Render

1. New Web Service → Build and deploy from Git repository
2. Connecter GitHub
3. Configuration:
   - Runtime: Node
   - Build Command: `npm install`
   - Start Command: `npm start`
4. Ajouter les variables d'environnement

## 🗄️ Migration Base de Données

Après déploiement, exécuter:

```bash
# Connexion à la DB de production
psql $DATABASE_URL -f migrations/004_create_financial_schema.sql
```

## 📞 Support

En cas de problème:
1. Vérifier les logs de déploiement
2. Vérifier que les variables d'environnement sont configurées
3. Tester l'API: `curl https://votre-api/api/health`
