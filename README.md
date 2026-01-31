# AWID API v2

API backend pour l'application de livraison AWID - Refactorisée avec architecture financière unifiée.

## 🚀 Déploiement Coolify

### Configuration requise

1. **Source** : Git Repository
   - Repository : `https://github.com/meedihkm/app-livraison-`
   - Branch : `main`

2. **Build Pack** : `Dockerfile`

3. **Ports** :
   - Exposed : `3000`
   - Mapping : `3000:3000`

### Variables d'Environnement

```env
# Base de données
DATABASE_URL=postgresql://user:password@host:5432/dbname

# JWT
JWT_SECRET=votre_secret_jwt
JWT_EXPIRES_IN=7d

# Redis (optionnel)
REDIS_URL=redis://host:6379

# Sentry (optionnel)
SENTRY_DSN=https://xxx@sentry.io/xxx

# Environnement
NODE_ENV=production
PORT=3000
```

### Endpoints API

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Health check |
| `GET /api/financial/v2/overview` | Statistiques financières |
| `GET /api/financial/v2/debts` | Liste des dettes clients |
| `POST /api/financial/v2/payments` | Enregistrer un paiement |

### Architecture

```
api-v2/
├── config/          # Configuration DB, Redis, etc.
├── middleware/      # Auth, validation, rate limiting
├── routes/          # Routes API
│   ├── financial.routes.js      # Legacy
│   └── financial.routes.v2.js   # Nouveau (unifié)
├── services/        # Logique métier
│   └── financial.service.js     # Service financier unifié
├── migrations/      # Migrations SQL
└── index.js         # Point d'entrée
```

### Migrations à exécuter

```bash
# Après déploiement, exécuter :
psql $DATABASE_URL -f migrations/004_create_financial_schema.sql
psql $DATABASE_URL -f migrations/005_migrate_payment_data.sql
```

---

Déployé avec ❤️ via Coolify