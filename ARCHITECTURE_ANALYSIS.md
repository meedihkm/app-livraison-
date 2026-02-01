# 🏗️ ANALYSE ARCHITECTURE - Application AWID

## 📐 ARCHITECTURE ACTUELLE

### Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────┐
│                     MOBILE APP (Flutter)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Customer   │  │  Deliverer   │  │    Admin     │      │
│  │  Dashboard   │  │  Dashboard   │  │  Dashboard   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┼──────────────────┘              │
│                            │                                 │
│                    ┌───────▼────────┐                        │
│                    │  ApiService    │                        │
│                    │  (Singleton)   │                        │
│                    └───────┬────────┘                        │
└────────────────────────────┼──────────────────────────────────┘
                             │ HTTP/JSON
                             │
┌────────────────────────────▼──────────────────────────────────┐
│                    BACKEND API (Node.js)                      │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    api-v2/index.js                       │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐             │ │
│  │  │ Security │  │   CORS   │  │  Helmet  │             │ │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘             │ │
│  │       └─────────────┼─────────────┘                    │ │
│  │                     │                                   │ │
│  │       ┌─────────────▼─────────────┐                    │ │
│  │       │   Rate Limiting + Auth    │                    │ │
│  │       └─────────────┬─────────────┘                    │ │
│  └─────────────────────┼───────────────────────────────────┘ │
│                        │                                     │
│  ┌─────────────────────▼───────────────────────────────────┐ │
│  │                    ROUTES                                │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐             │ │
│  │  │   auth   │  │ products │  │  users   │             │ │
│  │  └──────────┘  └──────────┘  └──────────┘             │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐             │ │
│  │  │  orders  │  │deliveries│  │financial │             │ │
│  │  └──────────┘  └──────────┘  └──────────┘             │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐             │ │
│  │  │packaging │  │recurring │  │favorites │             │ │
│  │  └──────────┘  └──────────┘  └──────────┘             │ │
│  │  ┌──────────┐  ┌──────────┐                            │ │
│  │  │  notify  │  │ realtime │ ❌ NON MONTÉ               │ │
│  │  └──────────┘  └──────────┘                            │ │
│  └──────────────────────┬───────────────────────────────────┘ │
│                         │                                     │
│  ┌──────────────────────▼───────────────────────────────────┐ │
│  │                   SERVICES                                │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │ │
│  │  │  order   │  │packaging │  │recurring │              │ │
│  │  └──────────┘  └──────────┘  └──────────┘              │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │ │
│  │  │  image   │  │  cache   │  │  token   │              │ │
│  │  └──────────┘  └──────────┘  └──────────┘              │ │
│  └──────────────────────┬───────────────────────────────────┘ │
└─────────────────────────┼─────────────────────────────────────┘
                          │
┌─────────────────────────▼─────────────────────────────────────┐
│                    DATA LAYER                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  PostgreSQL  │  │    Redis     │  │   BullMQ     │       │
│  │  (Primary)   │  │   (Cache)    │  │   (Jobs)     │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└───────────────────────────────────────────────────────────────┘
```

---

## 🔍 ANALYSE PAR DOMAINE

### 1. AUTHENTIFICATION ✅ COMPLET

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
login()        →  POST /auth/login      →  users table
logout()       →  POST /auth/logout     →  refresh_tokens
getMe()        →  GET /auth/me          →  users table
refresh()      →  POST /auth/refresh    →  refresh_tokens

Status: ✅ Fonctionnel, bien structuré
Issues: Aucune
```

### 2. PRODUITS ✅ COMPLET

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
getProducts()  →  GET /products         →  products table
createProduct()→  POST /products        →  products table
updateProduct()→  PUT /products/:id     →  products table
toggleProduct()→  PUT /products/:id/toggle
deleteProduct()→  DELETE /products/:id
reorderProduct()→ PUT /products/:id/reorder

Status: ✅ Fonctionnel, CRUD complet
Issues: Aucune
```

### 3. UTILISATEURS ✅ COMPLET

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
getUsers()     →  GET /users            →  users table
getDeliverers()→  GET /users/deliverers →  users (role filter)
createUser()   →  POST /users           →  users table
updateUser()   →  PUT /users/:id        →  users table
toggleUser()   →  PUT /users/:id/toggle →  users table
deleteUser()   →  DELETE /users/:id     →  users table
updateAddress()→  PUT /users/:id/address→  users table
updateCredit() →  PUT /users/:id/credit-limit

Status: ✅ Fonctionnel, CRUD complet
Issues: Aucune
```

### 4. COMMANDES ✅ COMPLET

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
getOrders()    →  GET /orders           →  orders table
getMyOrders()  →  GET /orders/my-orders →  orders (user filter)
createOrder()  →  POST /orders          →  orders table
updateOrder()  →  PUT /orders/:id       →  orders table
lockOrder()    →  PUT /orders/:id/lock  →  orders table
assignDeliverer()→ POST /orders/:id/assign → orders table

Kitchen:
getKitchenOrders()→ GET /orders/kitchen →  orders (status filter)
updateKitchenStatus()→ PUT /orders/:id/kitchen-status

Status: ✅ Fonctionnel, workflow complet
Issues: Aucune
```

### 5. LIVRAISONS ✅ COMPLET

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
getDeliveries()→  GET /deliveries       →  deliveries table
getDelivery()  →  GET /deliveries/:id   →  deliveries table
getRoute()     →  GET /deliveries/route →  deliveries (deliverer)
getHistory()   →  GET /deliveries/history→ deliveries (past)
updateStatus() →  PUT /deliveries/:id/status

Status: ✅ Fonctionnel, workflow complet
Issues: Aucune
```

### 6. FINANCES ⚠️ DISPERSÉ

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
getDebts()     →  GET /financial/debts  →  orders (aggregated)
                  GET /debts            →  ❓ Doublon ?
getCustomerDebt()→ GET /debts/customers/:id
getDebtStats() →  GET /debts/stats

recordPayment()→  POST /payments        →  payments table
getPaymentHistory()→ GET /payments/history
getMyCollections()→ GET /payments/my-collections
getPaymentStats()→ GET /payments/stats

getDailyFinancial()→ GET /financial/daily
                     GET /organization/daily → ❓ Doublon ?

Status: ⚠️ Fonctionnel mais routes dispersées
Issues:
- Routes dans 3 fichiers différents (financial, organization, debts?)
- Incohérence de nommage
- Potentiels doublons
```

### 7. CONSIGNES (PACKAGING) ✅ COMPLET

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
getPackagingTypes()→ GET /packaging/types → packaging_types
createType()   →  POST /packaging/types  → packaging_types
updateType()   →  PUT /packaging/types/:id
getBalance()   →  GET /packaging/customers/:id/balance
getHistory()   →  GET /packaging/customers/:id/history
recordDeposit()→  POST /packaging/deposits → packaging_transactions
getSummary()   →  GET /packaging/summary

Status: ✅ Fonctionnel, feature complète
Issues: Aucune
```

### 8. COMMANDES RÉCURRENTES ✅ COMPLET

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
getRecurringOrders()→ GET /recurring-orders → recurring_orders
getById()      →  GET /recurring-orders/:id
create()       →  POST /recurring-orders → recurring_orders
update()       →  PUT /recurring-orders/:id
delete()       →  DELETE /recurring-orders/:id
toggle()       →  POST /recurring-orders/:id/toggle
getAdminAll()  →  GET /recurring-orders/admin/all

Status: ✅ Fonctionnel, CRUD complet
Issues: Aucune
```

### 9. LOCALISATION GPS ❌ NON FONCTIONNEL

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
❌ updateLocation() → ❌ POST /realtime/location (NON MONTÉ)
❌ getLocations()   → ❌ GET /realtime/deliverers (NON MONTÉ)
❌ getDelivererHistory()→ ❌ GET /realtime/deliverer/:id/history

Status: ❌ Code existe mais route non montée
Issues:
- realtime.routes.js existe mais jamais monté dans index.js
- Méthodes mobile définies mais inutilisables
- Feature GPS non fonctionnelle
```

### 10. FAVORIS ❓ NON VÉRIFIÉ

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
❓ Aucun appel     →  GET /favorites        →  favorites table?
                      POST /favorites
                      DELETE /favorites/:id

Status: ❓ Route montée mais utilisation mobile non confirmée
Issues:
- Pas d'appel trouvé dans le code mobile
- Potentiellement non implémenté côté UI
```

### 11. NOTIFICATIONS ❓ NON VÉRIFIÉ

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
❓ Aucun appel     →  GET /notifications    →  notifications table?
                      POST /notifications
                      PUT /notifications/:id/read

Status: ❓ Route montée mais utilisation mobile non confirmée
Issues:
- Pas d'appel trouvé dans le code mobile
- OneSignal configuré dans pubspec.yaml mais pas d'intégration visible
```

### 12. ORGANISATION ✅ UTILISÉ

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
getSettings()  →  GET /organization/settings → organizations
updateSettings()→ PUT /organization/settings

Status: ✅ Fonctionnel
Issues: Aucune
```

### 13. AUDIT LOGS ✅ UTILISÉ

```
Mobile                Backend                  Database
─────────────────────────────────────────────────────────
getAuditLogs() →  GET /audit-logs       →  audit_logs table

Status: ✅ Fonctionnel
Issues: Route montée via organization.routes.js (peu conventionnel)
```

---

## 🎯 MATRICE DE COHÉRENCE

### Légende

- ✅ Cohérent et fonctionnel
- ⚠️ Fonctionnel mais incohérent
- ❌ Non fonctionnel
- ❓ Statut inconnu

| Domaine       | Backend Route                    | Mobile Method               | UI Usage             | Status |
| ------------- | -------------------------------- | --------------------------- | -------------------- | ------ |
| Auth          | /auth/\*                         | login(), logout()           | LoginPage            | ✅     |
| Products      | /products                        | getProducts()               | ProductsPage         | ✅     |
| Users         | /users                           | getUsers()                  | UsersPage            | ✅     |
| Orders        | /orders                          | getOrders()                 | OrdersPage           | ✅     |
| Deliveries    | /deliveries                      | getDeliveries()             | DeliveriesPage       | ✅     |
| Financial     | /financial/\*, /debts, /payments | getDebts(), recordPayment() | FinancialPage        | ⚠️     |
| Packaging     | /packaging                       | getPackagingTypes()         | RecordPackagingModal | ✅     |
| Recurring     | /recurring-orders                | getRecurringOrders()        | RecurringOrdersPage  | ✅     |
| Realtime      | ❌ /realtime (non monté)         | ❌ updateLocation()         | ❌ Aucune            | ❌     |
| Favorites     | /favorites                       | ❓ Aucun appel              | ❓ Aucune            | ❓     |
| Notifications | /notifications                   | ❓ Aucun appel              | ❓ Aucune            | ❓     |
| Organization  | /organization                    | getSettings()               | SettingsPage         | ✅     |
| Audit         | /audit-logs                      | getAuditLogs()              | AdminDashboard       | ✅     |

---

## 📊 STATISTIQUES

### Backend

- **Routes montées**: 13/14 (93%)
- **Routes non montées**: 1 (realtime)
- **Endpoints totaux**: ~80
- **Endpoints documentés**: 0 (API_CONTRACT.md vide)

### Mobile

- **Méthodes API Service**: 67
- **Méthodes utilisées**: ~50 (75%)
- **Méthodes dépréciées**: 4
- **Méthodes orphelines**: ~13 (19%)
- **Erreurs de typage**: 27

### Cohérence

- **Domaines cohérents**: 9/13 (69%)
- **Domaines incohérents**: 1/13 (8%)
- **Domaines non fonctionnels**: 1/13 (8%)
- **Domaines non vérifiés**: 2/13 (15%)

---

## 🔴 POINTS CRITIQUES

### 1. Route Realtime Non Montée (CRITIQUE)

**Impact**: Feature GPS complètement non fonctionnelle
**Utilisateurs affectés**: Livreurs, Admins
**Effort de fix**: 5 minutes (monter la route) OU 30 minutes (supprimer tout)

### 2. Routes Financial Dispersées (MOYEN)

**Impact**: Confusion développeurs, maintenance difficile
**Utilisateurs affectés**: Aucun (fonctionnel)
**Effort de fix**: 2-3 heures (refactoring)

### 3. API_CONTRACT.md Vide (MOYEN)

**Impact**: Pas de source de vérité, onboarding difficile
**Utilisateurs affectés**: Développeurs
**Effort de fix**: 3-4 heures (documentation)

### 4. Erreurs de Typage Mobile (FAIBLE)

**Impact**: Bugs potentiels, mauvaise DX
**Utilisateurs affectés**: Développeurs
**Effort de fix**: 1-2 heures (fix types)

### 5. Favorites/Notifications Non Utilisés (FAIBLE)

**Impact**: Code mort, confusion
**Utilisateurs affectés**: Aucun
**Effort de fix**: 1 heure (supprimer ou implémenter)

---

## 🎯 RECOMMANDATIONS PRIORITAIRES

### 🔥 URGENT (Faire maintenant)

1. **Décider du sort de realtime.routes.js**
   - Si GPS nécessaire: Monter la route immédiatement
   - Sinon: Supprimer route + méthodes mobile

2. **Vérifier Favorites et Notifications**
   - Chercher dans l'UI si utilisé
   - Supprimer si non implémenté

### ⚠️ IMPORTANT (Cette semaine)

3. **Créer API_CONTRACT.md complet**
   - Documenter tous les endpoints
   - Ajouter exemples

4. **Fixer erreurs de typage mobile**
   - Convertir `dynamic` en types explicites
   - Ajouter null-safety

5. **Unifier routes Financial**
   - Tout sous `/api/financial/`
   - Mettre à jour mobile

### 📋 NORMAL (Ce mois)

6. **Supprimer méthodes dépréciées**
   - Nettoyer api_service.dart

7. **Ajouter tests d'intégration**
   - Valider contrat API

8. **Créer scripts de validation**
   - Automatiser vérification cohérence

---

## 📈 ROADMAP SUGGÉRÉE

### Semaine 1: Stabilisation

- [ ] Fixer realtime.routes.js
- [ ] Vérifier favorites/notifications
- [ ] Créer API_CONTRACT.md

### Semaine 2: Nettoyage

- [ ] Supprimer code mort
- [ ] Fixer types mobile
- [ ] Unifier routes financial

### Semaine 3: Tests

- [ ] Tests d'intégration
- [ ] Validation contrat API
- [ ] Tests E2E flux critiques

### Semaine 4: Documentation

- [ ] Compléter README
- [ ] Guides développeurs
- [ ] Scripts maintenance

---

**Prêt à commencer ? Par quel point critique veux-tu attaquer ?**
