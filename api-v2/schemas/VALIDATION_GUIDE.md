# 🛡️ Guide de Validation - AWID API v2

**Date:** 2026-02-05  
**Version:** 1.0.0

---

## 📋 Vue d'ensemble

Ce document décrit le système de validation et de sanitization mis en place pour sécuriser l'API.

### Objectifs

- ✅ Valider toutes les entrées utilisateur
- ✅ Prévenir les injections XSS
- ✅ Limiter les abus (quantités, montants)
- ✅ Normaliser les données (trim, lowercase)
- ✅ Messages d'erreur clairs

---

## 🔧 Helpers de Sanitization

### `sanitizedString(min, max)`

Nettoie et valide les chaînes de caractères :

- Trim (supprime espaces début/fin)
- Escape HTML (`<`, `>`, `&`, `"`, `'`, `/`)
- Validation longueur min/max

**Exemple :**

```javascript
name: sanitizedString(1, 100); // Nom entre 1 et 100 caractères
```

### `sanitizedEmail()`

Valide et normalise les emails :

- Validation format email
- Trim
- Lowercase
- Max 255 caractères

**Exemple :**

```javascript
email: sanitizedEmail(); // "User@Example.COM" → "user@example.com"
```

### `sanitizedPhone()`

Valide les numéros de téléphone :

- Regex : `^[0-9+\-\s()]*$`
- Max 20 caractères
- Optionnel

**Exemple :**

```javascript
phone: sanitizedPhone(); // "0555 12-34-56" → valide
```

---

## 📦 Schémas de Validation

### Auth

#### `login`

```javascript
{
  email: sanitizedEmail(),
  password: string (1-128 chars)
}
```

#### `refreshToken`

```javascript
{
  refreshToken: string(required);
}
```

---

### Users

#### `createUser`

```javascript
{
  email: sanitizedEmail(),
  password: string (6-128 chars),
  name: sanitizedString(1, 100),
  phone: sanitizedPhone(),
  role: enum ["customer", "deliverer", "kitchen"]
}
```

#### `updateUser`

```javascript
{
  name: sanitizedString(1, 100) [optional],
  phone: sanitizedPhone(),
  email: sanitizedEmail() [optional],
  active: boolean [optional],
  creditLimit: number (0-100M) [optional]
}
```

---

### Products

#### `createProduct` / `updateProduct`

```javascript
{
  name: sanitizedString(1, 100),
  price: number (positive, max 1M),
  imageUrl: url [optional],
  category: sanitizedString(0, 50) [optional],
  isNew: boolean [optional],
  isPromo: boolean [optional],
  promoPrice: number (positive, max 1M) [optional]
}
```

**Limites :**

- Prix max : 1,000,000 DA
- Nom : 1-100 caractères

---

### Orders

#### `createOrder` / `updateOrder`

```javascript
{
  items: [
    {
      productId: uuid,
      quantity: number (1-1000)
    }
  ] (min 1, max 100 items)
}
```

**Limites :**

- Max 100 articles par commande
- Quantité max par article : 1000

---

### Financial / Payments

#### `recordPayment`

```javascript
{
  customerId: uuid,
  amount: number (positive, max 10M),
  mode: enum ["cash", "check", "transfer", "card", "other"],
  notes: sanitizedString(0, 500) [optional],
  targetOrders: [uuid] [optional]
}
```

**Limites :**

- Montant max : 10,000,000 DA
- Notes : max 500 caractères

#### `updateCreditLimit`

```javascript
{
  limit: number (0-100M)
}
```

**Limites :**

- Limite max : 100,000,000 DA

---

### Recurring Orders

#### `createRecurringOrder`

```javascript
{
  name: sanitizedString(1, 100),
  frequency: enum ["daily", "weekly", "monthly"],
  dayOfWeek: number (0-6) [optional],
  dayOfMonth: number (1-31) [optional],
  time: string (HH:MM format),
  items: [
    {
      productId: uuid,
      quantity: number (1-1000)
    }
  ] (min 1, max 100)
}
```

**Validation :**

- `time` : format `HH:MM` (ex: "08:30")
- `dayOfWeek` : 0=Dimanche, 6=Samedi
- `dayOfMonth` : 1-31

#### `updateRecurringOrder`

Tous les champs optionnels, mêmes validations que `create`.

---

### Favorites

#### `createFavorite` / `updateFavorite`

```javascript
{
  name: sanitizedString(1, 100),
  items: [
    {
      productId: uuid,
      quantity: number (1-1000)
    }
  ] (min 1, max 100)
}
```

**Limites :**

- Max 100 articles par favori
- Quantité max : 1000

---

### Deliveries

#### `updateDeliveryStatus`

```javascript
{
  status: enum ["in_progress", "delivered", "failed", "postponed"],
  paymentStatus: enum ["unpaid", "partial", "paid"] [optional],
  amountCollected: number (0-10M) [optional],
  comment: sanitizedString(0, 500) [optional],
  failureReason: sanitizedString(0, 100) [optional],
  postponedTo: datetime [optional]
}
```

---

### Location

#### `updateLocation`

```javascript
{
  latitude: number (-90 to 90),
  longitude: number (-180 to 180),
  accuracy: number (positive) [optional]
}
```

---

### Packaging

#### `recordPackaging`

```javascript
{
  deliveryId: uuid,
  packagingTypeId: uuid,
  quantityGiven: number (0-1000),
  quantityReturned: number (0-1000)
}
```

#### `createPackagingType` / `updatePackagingType`

```javascript
{
  name: sanitizedString(1, 100),
  value: number (positive, max 100K),
  description: sanitizedString(0, 255) [optional]
}
```

---

### Notifications

#### `sendNotification`

```javascript
{
  userId: uuid [optional],
  role: enum ["customer", "deliverer", "kitchen", "admin"] [optional],
  title: sanitizedString(1, 100),
  message: sanitizedString(1, 500),
  type: enum ["info", "warning", "error", "success"]
}
```

---

## 🚀 Utilisation

### Dans les routes

```javascript
const { validate, validateUUID } = require("../middleware/validate");

// Valider le body
router.post(
  "/payments",
  authenticate,
  validate("recordPayment"), // ← Validation
  async (req, res) => {
    // req.body est validé et sanitized
  },
);

// Valider les params UUID
router.put(
  "/users/:id",
  authenticate,
  validateUUID("id"), // ← Validation UUID
  validate("updateUser"),
  async (req, res) => {
    // req.params.id est un UUID valide
  },
);
```

---

## 🔒 Sécurité

### Protection XSS

Tous les strings sont échappés :

```javascript
Input: "<script>alert('XSS')</script>";
Output: "&lt;script&gt;alert(&#x27;XSS&#x27;)&lt;&#x2F;script&gt;";
```

### Limites Anti-Abus

- Montants : max 10M DA
- Quantités : max 1000 par article
- Arrays : max 100 items
- Strings : max 500 caractères (notes)

### Validation UUID

Regex strict : `^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`

---

## ✅ Endpoints Validés

### Auth ✅

- `POST /api/auth/login` → `login`
- `POST /api/auth/refresh` → `refreshToken`

### Users ✅

- `POST /api/users` → `createUser`
- `PUT /api/users/:id` → `updateUser`

### Products ✅

- `POST /api/products` → `createProduct`
- `PUT /api/products/:id` → `updateProduct`
- `PUT /api/products/:id/reorder` → `reorderProduct`

### Orders ✅

- `POST /api/orders` → `createOrder`
- `PUT /api/orders/:id` → `updateOrder`
- `PUT /api/orders/:id/assign` → `assignDeliverer`

### Financial ✅

- `POST /api/financial/payments` → `recordPayment`
- `PUT /api/financial/credit/:customerId/limit` → `updateCreditLimit`

### Recurring Orders ✅

- `POST /api/recurring-orders` → `createRecurringOrder`
- `PUT /api/recurring-orders/:id` → `updateRecurringOrder`

### Favorites ✅

- `POST /api/favorites/create` → `createFavorite`
- `PUT /api/favorites/:id` → `updateFavorite`

### Deliveries ✅

- `PUT /api/deliveries/:id/status` → `updateDeliveryStatus`
- `POST /api/deliveries/location` → `updateLocation`

### Organization ✅

- `PUT /api/organization/settings` → `updateOrgSettings`

### Kitchen ✅

- `PUT /api/orders/:id/kitchen-status` → `kitchenStatus`

### Super Admin ✅

- `POST /api/super-admin/organizations` → `createOrganization`
- `PATCH /api/super-admin/organizations/:id/status` → `toggleOrgStatus`

---

## 📊 Statistiques

- **Schémas créés :** 25+
- **Endpoints validés :** 20+
- **Helpers de sanitization :** 3
- **Protection XSS :** ✅
- **Limites anti-abus :** ✅

---

## 🔄 Prochaines Étapes

### À ajouter

- [ ] Validation sur routes packaging
- [ ] Validation sur routes notifications
- [ ] Tests unitaires des schémas
- [ ] Documentation Swagger mise à jour

### Améliorations futures

- [ ] Rate limiting par endpoint
- [ ] Validation des query params
- [ ] Validation des headers
- [ ] Logs des tentatives de validation échouées

---

## 📝 Exemples d'Erreurs

### Validation échouée

```json
{
  "error": "Email invalide, Mot de passe: minimum 6 caractères"
}
```

### UUID invalide

```json
{
  "error": "id invalide (UUID requis)"
}
```

### Montant trop élevé

```json
{
  "error": "Montant trop élevé"
}
```

---

**Fin du guide de validation**
