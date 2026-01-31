# Awid API v2 - Backend

Backend API pour l'application de gestion de livraison et commandes B2B.

## ðŸš€ DÃ©marrage Rapide

```bash
# Installation
npm install

# DÃ©marrage en dÃ©veloppement
npm run dev

# DÃ©marrage en production
npm start
```

## ðŸ“ Structure

```
api-v2/
â”œâ”€â”€ config/           # Configuration (DB, CORS, Security, etc.)
â”œâ”€â”€ middleware/       # Middlewares (Auth, Rate Limit, Cache)
â”œâ”€â”€ routes/           # Routes API
â”‚   â”œâ”€â”€ financial.routes.js      # Routes legacy
â”‚   â””â”€â”€ financial.routes.v2.js   # Routes refactorisÃ©es v2
â”œâ”€â”€ services/         # Services mÃ©tier
â”‚   â””â”€â”€ financial.service.js     # Service financier refactorisÃ©
â”œâ”€â”€ migrations/       # Migrations SQL
â”œâ”€â”€ queues/           # BullMQ queues
â”œâ”€â”€ workers/          # Background workers
â””â”€â”€ index.js          # Point d'entrÃ©e
```

## ðŸ”Œ API Endpoints

### Authentification
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `GET /api/auth/me`

### Commandes
- `GET /api/orders`
- `POST /api/orders`
- `PUT /api/orders/:id/status`

### Livraisons
- `GET /api/deliveries`
- `GET /api/deliveries/route`
- `PUT /api/deliveries/:id/status`

### Finances (Legacy)
- `GET /api/financial/overview`
- `GET /api/financial/debts`
- `POST /api/financial/payments`

### Finances v2 (RecommandÃ©)
- `GET /api/financial/v2/overview` - Stats optimisÃ©es
- `GET /api/financial/v2/debts` - Dettes avec pagination
- `GET /api/financial/v2/debts/:customerId` - DÃ©tail client
- `POST /api/financial/v2/payments` - Paiements avec transactions
- `GET /api/financial/v2/credit/alerts` - Alertes crÃ©dit

### Autres
- `GET /api/health` - Health check
- `GET /api-docs` - Documentation Swagger

## ðŸ—„ï¸ Base de DonnÃ©es

### Migrations Ã  exÃ©cuter
```bash
# SchÃ©ma financier v2
psql -f migrations/004_create_financial_schema.sql

# Migration des donnÃ©es (optionnel)
psql -f migrations/005_migrate_payment_data.sql
```

### Tables principales
- `orders` - Commandes
- `deliveries` - Livraisons
- `payments` - Paiements (nouveau)
- `payment_orders` - Liaison paiement-commande
- `users` - Utilisateurs
- `products` - Produits

## ðŸ”§ Variables d'Environnement

```env
DATABASE_URL=postgresql://user:pass@host:5432/db
JWT_SECRET=your-secret
SENTRY_DSN=your-sentry-dsn
REDIS_URL=redis://localhost:6379
PORT=3000
```

## ðŸ§ª Tests

```bash
# Tests unitaires
npm test

# Tests API
../test/financial_api_test.sh http://localhost:3000/api YOUR_TOKEN
```

## ðŸ“š Documentation

Voir les fichiers de documentation Ã  la racine:
- `REFACTORING_COMPLETE.md` - RÃ©capitulatif
- `MIGRATION_GUIDE.md` - Guide de migration
- `AUDIT_FINANCE_STATS_COMPLETE.md` - Audit initial

## ðŸ—ï¸ Architecture

### Ancien vs Nouveau

**Avant (legacy):**
- Logique mÃ©tier dans les routes
- RequÃªtes SQL dupliquÃ©es
- Pas de table payments dÃ©diÃ©e

**AprÃ¨s (v2):**
- `FinancialService` centralisÃ©
- RequÃªtes optimisÃ©es avec CTE
- Table `payments` avec transactions
- Routes `/api/financial/v2/*`

## ðŸ‘¥ Auteurs

- Mehdi Hakkoum

## ðŸ“„ Licence

MIT
