# 📋 PLAN DE RESTRUCTURATION ET NETTOYAGE - Application AWID

## 🎯 OBJECTIF

Éliminer tout code mort, routes inutilisées, endpoints sans réponse, et assurer une cohérence parfaite entre:

- **Backend API** (Node.js/Express)
- **Mobile App** (Flutter/Dart)
- **Contrat API** (Documentation)

---

## 📊 ÉTAT DES LIEUX - AUDIT COMPLET

### ✅ ROUTES BACKEND MONTÉES (api-v2/index.js)

```
/api/auth                    → auth.routes.js
/api/products                → products.routes.js
/api/users                   → users.routes.js
/api/orders                  → orders.routes.js
/api/deliveries              → deliveries.routes.js
/api/deliverers              → deliveries.routes.js (alias)
/api/organization            → organization.routes.js
/api/financial               → financial.routes.js
/api/packaging               → packaging.routes.js
/api/recurring-orders        → recurring-orders.routes.js
/api/favorites               → favorites.routes.js
/api/notifications           → notifications.routes.js
/api/audit-logs              → organization.routes.js
/api/super-admin             → superAdmin.routes.js
/api/health                  → health.routes.js
```

### ❌ ROUTES NON MONTÉES (Code Mort Potentiel)

```
api-v2/routes/realtime.routes.js  → JAMAIS MONTÉ dans index.js
```

### 📱 ENDPOINTS UTILISÉS PAR LE MOBILE

#### Auth (✅ Utilisé)

- `POST /api/auth/login`
- `POST /api/auth/logout`
- `POST /api/auth/logout-all`
- `POST /api/auth/refresh`
- `GET /api/auth/me`

#### Products (✅ Utilisé)

- `GET /api/products`
- `GET /api/products/categories`
- `POST /api/products`
- `PUT /api/products/:id`
- `PUT /api/products/:id/toggle`
- `PUT /api/products/:id/reorder`
- `DELETE /api/products/:id`

#### Users (✅ Utilisé)

- `GET /api/users`
- `GET /api/users/deliverers`
- `POST /api/users`
- `PUT /api/users/:id/toggle`
- `PUT /api/users/:id/address`
- `PUT /api/users/:id/credit-limit`
- `DELETE /api/users/:id`

#### Orders (✅ Utilisé)

- `GET /api/orders`
- `GET /api/orders/my-orders`
- `GET /api/orders/kitchen`
- `POST /api/orders`
- `PUT /api/orders/:id`
- `PUT /api/orders/:id/lock`
- `PUT /api/orders/:id/kitchen-status`
- `POST /api/orders/:id/assign`

#### Deliveries (✅ Utilisé)

- `GET /api/deliveries`
- `GET /api/deliveries/:id`
- `GET /api/deliveries/route`
- `GET /api/deliveries/history`
- `PUT /api/deliveries/:id/status`

#### Financial (✅ Utilisé)

- `GET /api/financial/overview`
- `GET /api/financial/debts` (ou /api/debts)
- `GET /api/debts/customers/:id`
- `GET /api/debts/stats`
- `POST /api/payments`
- `GET /api/payments/history`
- `GET /api/payments/my-collections`
- `GET /api/payments/stats`

#### Packaging (✅ Utilisé)

- `GET /api/packaging/types`
- `POST /api/packaging/types`
- `PUT /api/packaging/types/:id`
- `GET /api/packaging/customers/:id/balance`
- `GET /api/packaging/customers/:id/history`
- `POST /api/packaging/deposits`
- `GET /api/packaging/summary`

#### Recurring Orders (✅ Utilisé)

- `GET /api/recurring-orders`
- `GET /api/recurring-orders/:id`
- `POST /api/recurring-orders`
- `PUT /api/recurring-orders/:id`
- `DELETE /api/recurring-orders/:id`
- `POST /api/recurring-orders/:id/toggle`
- `GET /api/recurring-orders/admin/all`

#### Organization (✅ Utilisé)

- `GET /api/organization/settings`
- `PUT /api/organization/settings`

#### Audit (✅ Utilisé)

- `GET /api/audit-logs`

#### Favorites (❓ Non vérifié)

- Routes définies mais utilisation mobile non confirmée

#### Notifications (❓ Non vérifié)

- Routes définies mais utilisation mobile non confirmée

### 🔴 PROBLÈMES IDENTIFIÉS

#### 1. Routes Backend Non Montées

- **realtime.routes.js** : Contient 7 endpoints GPS/localisation jamais exposés
  - `POST /api/realtime/location`
  - `GET /api/realtime/deliverers`
  - `GET /api/realtime/deliveries-map`
  - `GET /api/realtime/deliverer/:id/route`
  - `GET /api/realtime/deliverer/:id/history`
  - `GET /api/realtime/deliverer/:id/stats`
  - `POST /api/realtime/cleanup-history`

#### 2. Méthodes API Service Non Utilisées (Mobile)

```dart
// Dans api_service.dart mais jamais appelées:
- updateDelivererLocation()
- getDeliverersLocations()
- getClientsLocations()
- getDelivererHistory()
```

#### 3. Incohérences de Nommage

- Backend: `/api/debts` vs Mobile: `getDebts()`
- Backend: `/api/payments` vs Mobile: `recordPayment()`
- Alias confus: `/api/deliverers` → `/api/deliveries`

#### 4. Méthodes Dépréciées Non Supprimées

```dart
@Deprecated recordDebtPayment()
@Deprecated getClientDebtDetails()
@Deprecated getMyPayments()
@Deprecated recordPaymentLegacy()
```

#### 5. API_CONTRACT.md Vide

- Aucune documentation du contrat API
- Impossible de valider la cohérence

#### 6. Erreurs de Typage (Flutter)

- 27 erreurs de type dans api_service.dart
- Conversions `dynamic` non sécurisées

---

## 🎯 PLAN D'ACTION - 5 PHASES

### PHASE 1: AUDIT ET DOCUMENTATION (1-2h)

**Objectif**: Créer une source de vérité

#### 1.1 Créer API_CONTRACT.md Complet

- Lister TOUS les endpoints backend existants
- Documenter paramètres, réponses, codes d'erreur
- Marquer les endpoints utilisés vs non utilisés
- Ajouter exemples de requêtes/réponses

#### 1.2 Créer Matrice de Mapping

```
| Endpoint Backend | Méthode Mobile | Page/Feature Utilisateur | Statut |
|------------------|----------------|--------------------------|--------|
| GET /api/orders  | getOrders()    | OrdersPage, AdminDash    | ✅ OK  |
```

#### 1.3 Identifier Code Mort

- Routes backend non montées
- Méthodes API service jamais appelées
- Composants UI orphelins

---

### PHASE 2: NETTOYAGE BACKEND (2-3h)

**Objectif**: Supprimer code mort, fixer incohérences

#### 2.1 Décision sur realtime.routes.js

**Option A**: Monter la route si fonctionnalité GPS nécessaire

```javascript
// Dans api-v2/index.js
const realtimeRoutes = require("./routes/realtime.routes");
app.use("/api/realtime", realtimeRoutes);
```

**Option B**: Supprimer si non utilisé

```bash
rm api-v2/routes/realtime.routes.js
```

**Recommandation**: Option A si tracking GPS prévu, sinon Option B

#### 2.2 Standardiser Routes Financial

Actuellement dispersé entre:

- `/api/financial/*`
- `/api/debts/*`
- `/api/payments/*`

**Action**: Unifier sous `/api/financial/`

```javascript
// financial.routes.js
router.get('/debts', ...)           // /api/financial/debts
router.get('/debts/:id', ...)       // /api/financial/debts/:id
router.post('/payments', ...)       // /api/financial/payments
router.get('/payments/history', ...)
```

#### 2.3 Supprimer Alias Confus

```javascript
// AVANT
app.use("/api/deliverers", deliveriesRoutes); // Alias

// APRÈS
// Supprimer l'alias, utiliser uniquement /api/deliveries
```

#### 2.4 Valider Toutes les Routes

- Tester chaque endpoint avec Postman/Thunder Client
- Vérifier codes de réponse (200, 400, 401, 404, 500)
- S'assurer que les erreurs retournent `{ error: "message" }`

---

### PHASE 3: NETTOYAGE MOBILE (2-3h)

**Objectif**: Supprimer code mort, fixer types

#### 3.1 Supprimer Méthodes Dépréciées

```dart
// Supprimer de api_service.dart:
@Deprecated recordDebtPayment()
@Deprecated getClientDebtDetails()
@Deprecated getMyPayments()
@Deprecated recordPaymentLegacy()
```

#### 3.2 Supprimer Méthodes Non Utilisées

Si realtime.routes.js supprimé:

```dart
// Supprimer:
updateDelivererLocation()
getDeliverersLocations()
getClientsLocations()
getDelivererHistory()
```

#### 3.3 Fixer Erreurs de Typage

```dart
// AVANT
final data = json.decode(response.body);
return data; // ❌ dynamic

// APRÈS
final data = json.decode(response.body) as Map<String, dynamic>;
return data; // ✅ Map<String, dynamic>
```

Appliquer à toutes les 27 erreurs identifiées.

#### 3.4 Standardiser Noms de Méthodes

Aligner avec les routes backend:

```dart
// AVANT
getDebts() → GET /api/debts

// APRÈS
getFinancialDebts() → GET /api/financial/debts
```

#### 3.5 Ajouter Gestion d'Erreurs Robuste

```dart
Future<Map<String, dynamic>> getOrders() async {
  try {
    final result = await _request('GET', ApiConstants.orders);
    return result;
  } on ApiException catch (e) {
    // Log to Sentry
    return {'success': false, 'error': e.message};
  } catch (e) {
    return {'success': false, 'error': 'Erreur réseau'};
  }
}
```

---

### PHASE 4: SYNCHRONISATION (1-2h)

**Objectif**: Assurer cohérence parfaite

#### 4.1 Mettre à Jour ApiConstants

```dart
// mobile/lib/core/constants/api_constants.dart
class ApiConstants {
  static const String baseUrl = 'https://api.awid.com';

  // Auth
  static const String login = '$baseUrl/auth/login';
  static const String logout = '$baseUrl/auth/logout';

  // Financial (Unifié)
  static const String financialDebts = '$baseUrl/financial/debts';
  static const String financialPayments = '$baseUrl/financial/payments';

  // ... etc
}
```

#### 4.2 Créer Tests d'Intégration

```dart
// test/integration/api_contract_test.dart
void main() {
  test('GET /api/products returns valid structure', () async {
    final response = await ApiService().getProducts();
    expect(response['success'], true);
    expect(response['data'], isList);
  });
}
```

#### 4.3 Valider Chaque Flux Utilisateur

- Login → Dashboard
- Créer commande → Assigner livreur → Livrer
- Enregistrer paiement → Vérifier dette
- Gérer consignes

---

### PHASE 5: DOCUMENTATION ET MAINTENANCE (1h)

**Objectif**: Prévenir régression future

#### 5.1 Compléter API_CONTRACT.md

Exemple de structure:

````markdown
## POST /api/orders

**Description**: Créer une nouvelle commande

**Auth**: Bearer Token (customer, admin)

**Body**:

```json
{
  "customerId": "uuid",
  "items": [{ "productId": "uuid", "quantity": 2 }],
  "deliveryDate": "2026-01-26"
}
```
````

**Response 201**:

```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "status": "pending",
    ...
  }
}
```

**Errors**:

- 400: Validation error
- 401: Unauthorized
- 404: Customer not found

````

#### 5.2 Créer Scripts de Validation
```bash
# scripts/validate_api.sh
#!/bin/bash
# Vérifie que toutes les routes backend sont documentées
# Vérifie que toutes les méthodes mobile ont un endpoint correspondant
````

#### 5.3 Ajouter Hook Pre-Commit

```json
// .husky/pre-commit
npm run validate:api
flutter analyze
```

---

## 📋 CHECKLIST DE VALIDATION

### Backend

- [ ] Toutes les routes dans index.js sont documentées
- [ ] Aucune route orpheline (fichier non monté)
- [ ] Tous les endpoints retournent `{ success, data/error }`
- [ ] Codes HTTP cohérents (200, 201, 400, 401, 404, 500)
- [ ] Middleware d'authentification sur routes protégées
- [ ] Validation Joi/Zod sur tous les POST/PUT

### Mobile

- [ ] Aucune méthode @Deprecated
- [ ] Aucune méthode API service non utilisée
- [ ] Tous les appels API ont gestion d'erreur
- [ ] Types explicites (pas de `dynamic`)
- [ ] Cache invalidé après mutations
- [ ] Offline-first pour données critiques

### Documentation

- [ ] API_CONTRACT.md complet et à jour
- [ ] Exemples de requêtes/réponses
- [ ] Matrice de mapping Backend ↔ Mobile
- [ ] README avec architecture

### Tests

- [ ] Tests unitaires pour services critiques
- [ ] Tests d'intégration pour flux principaux
- [ ] Validation du contrat API automatisée

---

## 🚀 ORDRE D'EXÉCUTION RECOMMANDÉ

1. **PHASE 1** (Audit) - OBLIGATOIRE EN PREMIER
2. **PHASE 2** (Backend) - Avant mobile pour stabiliser API
3. **PHASE 3** (Mobile) - Adapter aux changements backend
4. **PHASE 4** (Sync) - Valider cohérence
5. **PHASE 5** (Doc) - Finaliser et sécuriser

**Durée totale estimée**: 7-11 heures

---

## ⚠️ RISQUES ET MITIGATION

### Risque 1: Casser fonctionnalités existantes

**Mitigation**:

- Créer branche `refactor/cleanup`
- Tester chaque changement individuellement
- Garder backup de l'ancien code

### Risque 2: Supprimer code "dormant" mais nécessaire

**Mitigation**:

- Analyser git history avant suppression
- Commenter au lieu de supprimer si doute
- Valider avec équipe métier

### Risque 3: Incohérences après refactor

**Mitigation**:

- Tests d'intégration automatisés
- Validation manuelle de tous les flux
- Monitoring Sentry après déploiement

---

## 📊 MÉTRIQUES DE SUCCÈS

- ✅ 0 route backend non montée
- ✅ 0 méthode API service non utilisée
- ✅ 0 erreur de typage Flutter
- ✅ 100% des endpoints documentés
- ✅ Temps de réponse API < 200ms (p95)
- ✅ 0 erreur 500 en production (7 jours)

---

## 🔄 MAINTENANCE CONTINUE

### Règles à Suivre

1. **Nouvelle route backend** → Ajouter dans API_CONTRACT.md
2. **Nouvelle méthode mobile** → Vérifier endpoint existe
3. **Dépréciation** → Marquer @Deprecated + date de suppression
4. **Suppression** → Vérifier aucune référence (grep)

### Revue Mensuelle

- Audit des routes non utilisées (logs)
- Nettoyage des @Deprecated > 3 mois
- Mise à jour documentation

---

## 📞 QUESTIONS À RÉSOUDRE AVANT DE COMMENCER

1. **realtime.routes.js**: Garder ou supprimer ?
   - Si garder: Implémenter côté mobile
   - Si supprimer: Confirmer pas de besoin GPS

2. **Favorites & Notifications**: Utilisés ?
   - Vérifier dans l'app mobile
   - Supprimer si non implémenté

3. **Structure Financial**: Unifier maintenant ou plus tard ?
   - Impact sur mobile important
   - Coordination avec équipe nécessaire

4. **Tests**: Niveau de couverture cible ?
   - Minimum: Flux critiques (auth, orders, payments)
   - Idéal: 80% couverture

---

**Prêt à commencer ? Quelle phase veux-tu attaquer en premier ?**
