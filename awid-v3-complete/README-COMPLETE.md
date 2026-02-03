# 🚚 AWID v3.0 - Guide d'Implémentation Complet

## Vue d'ensemble

AWID est une solution complète de gestion de livraison B2B pour l'Algérie, comprenant:
- **Backend API** (Node.js/TypeScript/PostgreSQL)
- **App Livreur** (Flutter)
- **App Client** (Flutter)
- **Admin Web** (React/TypeScript)

---

## 📂 Structure du Projet

```
awid-v3-complete/
├── backend/                    # API REST Node.js
│   ├── src/
│   │   ├── config/            # Configuration
│   │   ├── controllers/       # Contrôleurs API
│   │   ├── services/          # Logique métier
│   │   ├── database/          # Schéma Drizzle ORM
│   │   ├── middlewares/       # Auth, validation, erreurs
│   │   ├── routes/            # Définition des routes
│   │   ├── cache/             # Redis cache
│   │   ├── worker/            # Jobs BullMQ
│   │   ├── utils/             # Utilitaires
│   │   └── validators/        # Schémas Zod
│   ├── package.json
│   ├── tsconfig.json
│   └── Dockerfile
├── mobile/
│   ├── livreur/               # App Flutter Livreur
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── router/
│   │   │   ├── theme/
│   │   │   ├── screens/
│   │   │   │   ├── auth/
│   │   │   │   ├── route/
│   │   │   │   ├── delivery/
│   │   │   │   └── cash/
│   │   │   └── models/
│   │   └── pubspec.yaml
│   ├── client/                # App Flutter Client
│   │   └── lib/
│   └── shared/                # Code partagé
│       └── lib/
│           ├── api/           # Client API Dio
│           ├── models/        # Modèles Freezed
│           ├── providers/     # Riverpod providers
│           ├── config/        # Configuration
│           └── widgets/       # Composants réutilisables
├── admin/                     # Dashboard React (à développer)
│   └── src/
├── database/
│   └── schema.sql             # Schéma PostgreSQL
├── docker-compose.yml
├── Caddyfile
└── .env.example
```

---

## 🔧 Installation et Démarrage

### Prérequis
- Node.js >= 20
- PostgreSQL >= 15
- Redis >= 7
- Flutter >= 3.16
- Docker (optionnel)

### Backend

```bash
cd backend

# Installer les dépendances
npm install

# Configurer l'environnement
cp ../.env.example .env
# Éditer .env avec vos valeurs

# Appliquer le schéma de base de données
npm run db:migrate

# Seed des données de test (optionnel)
npm run db:seed

# Démarrer en développement
npm run dev

# Ou démarrer en production
npm run build
npm start
```

### Mobile (Flutter)

```bash
cd mobile/livreur

# Installer les dépendances
flutter pub get

# Générer le code (Freezed, etc.)
flutter pub run build_runner build --delete-conflicting-outputs

# Lancer sur un émulateur/device
flutter run
```

### Docker (Stack complète)

```bash
# Démarrer tous les services
docker-compose up -d

# Voir les logs
docker-compose logs -f api
```

---

## 📡 API Endpoints

### Authentification
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/api/auth/login` | Login admin/livreur |
| POST | `/api/auth/customer/request-otp` | Demander OTP client |
| POST | `/api/auth/customer/verify-otp` | Vérifier OTP |
| POST | `/api/auth/refresh` | Rafraîchir le token |
| POST | `/api/auth/logout` | Déconnexion |

### Clients
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/customers` | Liste des clients |
| POST | `/api/customers` | Créer un client |
| GET | `/api/customers/:id` | Détail client |
| PUT | `/api/customers/:id` | Modifier client |
| GET | `/api/customers/:id/statement` | Relevé de compte |

### Produits
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/products` | Liste des produits |
| POST | `/api/products` | Créer un produit |
| PUT | `/api/products/:id/stock` | Modifier le stock |
| PUT | `/api/products/:id/price` | Modifier le prix |

### Commandes
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/orders` | Liste des commandes |
| POST | `/api/orders` | Créer une commande |
| PUT | `/api/orders/:id/status` | Changer le statut |
| POST | `/api/orders/:id/duplicate` | Dupliquer |

### Livraisons
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/deliveries/my-route` | Ma tournée (livreur) |
| POST | `/api/deliveries/assign` | Assigner livraisons |
| PUT | `/api/deliveries/:id/complete` | Compléter livraison |
| PUT | `/api/deliveries/:id/fail` | Marquer échouée |

### Caisse
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/daily-cash/my` | Ma caisse du jour |
| POST | `/api/daily-cash/open` | Ouvrir la caisse |
| POST | `/api/daily-cash/close` | Clôturer la caisse |
| POST | `/api/daily-cash/remit` | Remettre la caisse |

### Synchronisation (Offline)
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/sync/initial` | Téléchargement initial |
| POST | `/api/sync/push` | Envoyer transactions offline |
| GET | `/api/sync/pull` | Récupérer mises à jour |

### Dashboard
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/dashboard/overview` | Vue d'ensemble |
| GET | `/api/dashboard/daily` | Stats journalières |
| GET | `/api/dashboard/aging-report` | Rapport aging |

---

## 📱 Architecture Mobile

### State Management: Riverpod
```dart
// Provider d'authentification
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>

// Provider de la tournée
final routeProvider = StateNotifierProvider<RouteNotifier, RouteState>

// Provider de synchronisation
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>
```

### Navigation: GoRouter
```dart
// Configuration des routes avec redirection automatique
// basée sur l'état d'authentification
final appRouterProvider = Provider<GoRouter>
```

### Mode Offline
1. Les données sont stockées localement (Drift/SQLite)
2. Les transactions sont mises en queue
3. Synchronisation automatique quand connexion rétablie
4. Résolution des conflits côté serveur

---

## 🗄️ Base de Données

### Tables Principales
- `organizations` - Multi-tenant
- `users` - Admin, Manager, Livreur, Cuisine
- `customers` - Clients B2B
- `customer_accounts` - Comptes app client
- `products` / `categories`
- `orders` / `order_items`
- `deliveries`
- `payments` / `payment_allocations`
- `daily_cash` / `cash_remittances`
- `expenses`
- `audit_logs`

### Fonctions PostgreSQL
- `calculate_customer_debt()` - Calcul FIFO de la dette
- `update_order_totals()` - Trigger mise à jour totaux
- `cleanup_old_tokens()` - Nettoyage automatique

---

## 🔐 Sécurité

### Authentification
- JWT avec refresh tokens
- OTP par SMS pour clients
- Blacklist de tokens (Redis)

### Autorisation
- RBAC (Role-Based Access Control)
- Middleware de vérification des rôles
- Isolation multi-tenant automatique

### Protection
- Rate limiting
- Validation des entrées (Zod)
- Helmet (headers sécurité)
- CORS configuré

---

## 📊 Fonctionnalités Métier

### Gestion des Dettes (FIFO)
```typescript
// Les paiements sont appliqués aux factures les plus anciennes d'abord
// 1. Appliquer à la commande en cours
// 2. Si reste, appliquer aux dettes par date croissante
// 3. Si reste encore, créer un avoir
```

### Tournée Optimisée
- Assignation par zone géographique
- Optimisation de l'ordre (TSP)
- Suivi GPS en temps réel

### Caisse Journalière
- Ouverture avec fond de caisse
- Suivi des encaissements par mode
- Enregistrement des dépenses
- Clôture avec écart
- Remise au manager

---

## 🧪 Tests

```bash
# Backend
cd backend
npm test              # Tests unitaires
npm run test:e2e      # Tests d'intégration

# Mobile
cd mobile/livreur
flutter test
```

---

## 📝 TODO / Améliorations

- [ ] Implémentation complète du dashboard React
- [ ] Génération PDF (factures, reçus, relevés)
- [ ] Intégration SMS (Twilio/local)
- [ ] Intégration paiement électronique
- [ ] Notifications push (FCM)
- [ ] Mode cuisine (écran préparation)
- [ ] Rapports avancés et exports
- [ ] Tests E2E complets

---

## 📄 Licence

MIT License - Libre d'utilisation commerciale

---

## 🤝 Support

Pour toute question ou assistance:
- Email: support@awid.dz
- Documentation: https://docs.awid.dz
