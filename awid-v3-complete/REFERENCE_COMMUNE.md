# 📋 DOCUMENT DE RÉFÉRENCE COMMUNE AWID v3.0

## 🎯 Objectif
Ce document sert de **source de vérité unique** pour garantir la cohérence entre :
- Backend (Node.js/TypeScript)
- Mobile Livreur (Flutter)
- Mobile Client (Flutter)
- Admin (React/TypeScript)

**RÈGLE D'OR :** Toute modification dans un composant doit être reflétée ici et dans les autres composants.

---

## 📊 MODÈLES DE DONNÉES

### 1. ENUMS

#### OrderStatus
| Valeur | Backend | Livreur | Client | Admin |
|--------|---------|---------|--------|-------|
| `draft` | ✅ | ✅ | ✅ | ✅ |
| `pending` | ✅ | ✅ | ✅ | ✅ |
| `confirmed` | ✅ | ✅ | ✅ | ✅ |
| `preparing` | ✅ | ✅ | ✅ | ✅ |
| `ready` | ✅ | ✅ | ✅ | ✅ |
| `assigned` | ✅ | ✅ | ✅ | ✅ |
| `in_delivery` | ✅ | `inDelivery` | `inDelivery` | `in_delivery` |
| `delivered` | ✅ | ✅ | ✅ | ✅ |
| `cancelled` | ✅ | ✅ | ✅ | ✅ |

**Flutter (Livreur & Client) :**
```dart
enum OrderStatus {
  draft,
  pending,
  confirmed,
  preparing,
  ready,
  assigned,
  inDelivery,  // Notation camelCase pour Dart
  delivered,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get apiValue {
    switch (this) {
      case OrderStatus.inDelivery:
        return 'in_delivery';  // Mapping vers backend
      default:
        return name;
    }
  }
}
```

**Backend/Admin :**
```typescript
export const orderStatusEnum = pgEnum('order_status', [
  'draft', 'pending', 'confirmed', 'preparing', 'ready',
  'assigned', 'in_delivery', 'delivered', 'cancelled'
]);
```

---

#### DeliveryStatus
| Valeur | Backend | Livreur | Admin |
|--------|---------|---------|-------|
| `pending` | ✅ | ✅ | ✅ |
| `assigned` | ✅ | ✅ | ✅ |
| `picked_up` | ✅ | `pickedUp` | `picked_up` |
| `in_transit` | ✅ | `inTransit` | `in_transit` |
| `arrived` | ✅ | ✅ | ✅ |
| `delivered` | ✅ | ✅ | ✅ |
| `failed` | ✅ | ✅ | ✅ |
| `returned` | ✅ | ✅ | ✅ |

---

#### PaymentMode
| Valeur | Backend | Livreur | Client | Admin |
|--------|---------|---------|--------|-------|
| `cash` | ✅ | ✅ | ✅ | ✅ |
| `check` | ✅ | ✅ | ✅ | ✅ |
| `bank_transfer` | ✅ | `bankTransfer` | `bankTransfer` | `bank_transfer` |
| `mobile_payment` | ✅ | `mobilePayment` | `mobilePayment` | `mobile_payment` |

---

#### UserRole
| Valeur | Backend | Livreur | Admin |
|--------|---------|---------|-------|
| `admin` | ✅ | N/A | ✅ |
| `manager` | ✅ | N/A | ✅ |
| `deliverer` | ✅ | ✅ | ✅ |
| `kitchen` | ✅ | N/A | ✅ |
| `customer` | ✅ | N/A | ✅ (API only) |

---

### 2. TABLES & CHAMPS

#### users
| Champ | Type | Backend | DB | Notes |
|-------|------|---------|-----|-------|
| `id` | UUID | ✅ | ✅ | PK |
| `organizationId` | UUID | ✅ | ✅ | FK |
| `email` | string | ✅ | ✅ | Unique par org |
| `passwordHash` | string | ✅ | ✅ | bcrypt |
| `name` | string | ✅ | ✅ | |
| `phone` | string | ✅ | ✅ | |
| `role` | UserRole | ✅ | ✅ | enum |
| `vehicleType` | string | ✅ | ✅ | 'car', 'motorcycle', etc. |
| `licensePlate` | string | ✅ | ✅ | |
| `avatarUrl` | string | ✅ | ✅ | |
| `permissions` | JSON | ✅ | ✅ | Array de strings |
| `isActive` | boolean | ✅ | ✅ | |
| `lastLoginAt` | datetime | ✅ | ✅ | |
| `lastPosition` | JSON | ✅ | ✅ | `{lat, lng, updatedAt}` |
| `createdAt` | datetime | ✅ | ✅ | |
| `updatedAt` | datetime | ✅ | ✅ | |

---

#### customers
| Champ | Type | Backend | DB | Mobile | Admin | Notes |
|-------|------|---------|-----|--------|-------|-------|
| `id` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `organizationId` | UUID | ✅ | ✅ | ✅ | ✅ | FK |
| `code` | string | ✅ | ✅ | ✅ | ✅ | Code client unique |
| `name` | string | ✅ | ✅ | ✅ | ✅ | |
| `contactName` | string | ✅ | ✅ | ✅ | ✅ | |
| `phone` | string | ✅ | ✅ | ✅ | ✅ | |
| `phoneSecondary` | string | ✅ | ✅ | ❌ | ✅ | |
| `email` | string | ✅ | ✅ | ❌ | ✅ | |
| `address` | string | ✅ | ✅ | ✅ | ✅ | |
| `city` | string | ✅ | ✅ | ❌ | ✅ | |
| `wilaya` | string | ✅ | ✅ | ❌ | ✅ | |
| `zone` | string | ✅ | ✅ | ✅ | ✅ | Zone de livraison |
| `coordinates` | JSON | ✅ | ✅ | ✅ | ✅ | `{lat, lng}` |
| `creditLimit` | decimal | ✅ | ✅ | ✅ | ✅ | Plafond crédit |
| `creditLimitEnabled` | boolean | ✅ | ✅ | ✅ | ✅ | Activer/désactiver |
| `currentDebt` | decimal | ✅ | ✅ | ✅ | ✅ | Dette actuelle |
| `paymentDelayDays` | int | ✅ | ✅ | ❌ | ✅ | Délai paiement |
| `discountPercent` | decimal | ✅ | ✅ | ❌ | ✅ | % remise |
| `customPrices` | JSON | ✅ | ✅ | ✅ | ✅ | `{productId: price}` |
| `appUserId` | UUID | ✅ | ✅ | ❌ | ✅ | Lien compte app |
| `pushToken` | string | ✅ | ✅ | ❌ | ❌ | FCM token |
| `isActive` | boolean | ✅ | ✅ | ✅ | ✅ | |
| `createdAt` | datetime | ✅ | ✅ | ✅ | ✅ | |
| `updatedAt` | datetime | ✅ | ✅ | ✅ | ✅ | |

---

#### orders
| Champ | Type | Backend | DB | Mobile | Admin | Notes |
|-------|------|---------|-----|--------|-------|-------|
| `id` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `organizationId` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `customerId` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `orderNumber` | string | ✅ | ✅ | ✅ | ✅ | Auto-généré |
| `status` | OrderStatus | ✅ | ✅ | ✅ | ✅ | |
| `paymentStatus` | PaymentStatus | ✅ | ✅ | ✅ | ✅ | |
| `subtotal` | decimal | ✅ | ✅ | ✅ | ✅ | |
| `discountPercent` | decimal | ✅ | ✅ | ❌ | ✅ | |
| `discountAmount` | decimal | ✅ | ✅ | ❌ | ✅ | Calculé |
| `total` | decimal | ✅ | ✅ | ✅ | ✅ | |
| `amountPaid` | decimal | ✅ | ✅ | ✅ | ✅ | |
| `amountDue` | decimal | ✅ | ✅ | ✅ | ✅ | Calculé (total - paid) |
| `deliveryDate` | date | ✅ | ✅ | ✅ | ✅ | |
| `deliveryTimeSlot` | string | ✅ | ✅ | ✅ | ✅ | 'morning', 'afternoon' |
| `deliveryAddress` | string | ✅ | ✅ | ✅ | ✅ | |
| `deliveryNotes` | string | ✅ | ✅ | ✅ | ✅ | |
| `notes` | string | ✅ | ✅ | ❌ | ✅ | Notes internes |
| `source` | string | ✅ | ✅ | ❌ | ✅ | 'admin', 'mobile_app' |
| `confirmedAt` | datetime | ✅ | ✅ | ❌ | ✅ | |
| `deliveredAt` | datetime | ✅ | ✅ | ✅ | ✅ | |
| `cancelledAt` | datetime | ✅ | ✅ | ❌ | ✅ | |
| `cancellationReason` | string | ✅ | ✅ | ❌ | ✅ | |
| `createdAt` | datetime | ✅ | ✅ | ✅ | ✅ | |
| `updatedAt` | datetime | ✅ | ✅ | ✅ | ✅ | |

---

#### order_items
| Champ | Type | Backend | DB | Notes |
|-------|------|---------|-----|-------|
| `id` | UUID | ✅ | ✅ | |
| `orderId` | UUID | ✅ | ✅ | FK |
| `productId` | UUID | ✅ | ✅ | FK |
| `productName` | string | ✅ | ✅ | Snapshot |
| `productSku` | string | ✅ | ✅ | Snapshot |
| `quantity` | decimal | ✅ | ✅ | |
| `unitPrice` | decimal | ✅ | ✅ | Snapshot |
| `totalPrice` | decimal | ✅ | ✅ | Calculé |
| `notes` | string | ✅ | ✅ | |
| `createdAt` | datetime | ✅ | ✅ | |

---

#### deliveries
| Champ | Type | Backend | DB | Livreur | Admin | Notes |
|-------|------|---------|-----|---------|-------|-------|
| `id` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `organizationId` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `orderId` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `delivererId` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `status` | DeliveryStatus | ✅ | ✅ | ✅ | ✅ | |
| `scheduledDate` | date | ✅ | ✅ | ✅ | ✅ | |
| `scheduledTime` | time | ✅ | ✅ | ✅ | ✅ | |
| `sequenceNumber` | int | ✅ | ✅ | ✅ | ✅ | Ordre tournée |
| `priority` | int | ✅ | ✅ | ❌ | ✅ | 1-100 |
| `orderAmount` | decimal | ✅ | ✅ | ✅ | ✅ | Montant commande |
| `existingDebt` | decimal | ✅ | ✅ | ✅ | ✅ | Dette avant livraison |
| `totalToCollect` | decimal | ✅ | ✅ | ✅ | ✅ | Total à collecter |
| `amountCollected` | decimal | ✅ | ✅ | ✅ | ✅ | Encaissé |
| `collectionMode` | PaymentMode | ✅ | ✅ | ✅ | ✅ | |
| `assignedAt` | datetime | ✅ | ✅ | ✅ | ❌ | |
| `pickedUpAt` | datetime | ✅ | ✅ | ✅ | ❌ | |
| `arrivedAt` | datetime | ✅ | ✅ | ✅ | ❌ | |
| `completedAt` | datetime | ✅ | ✅ | ✅ | ✅ | |
| `proofOfDelivery` | JSON | ✅ | ✅ | ✅ | ✅ | `{signature, photos, location}` |
| `failureReason` | string | ✅ | ✅ | ✅ | ✅ | |
| `estimatedDistanceKm` | decimal | ✅ | ✅ | ❌ | ✅ | |
| `estimatedDurationMin` | int | ✅ | ✅ | ❌ | ✅ | |
| `actualDistanceKm` | decimal | ✅ | ✅ | ❌ | ✅ | |
| `actualDurationMin` | int | ✅ | ✅ | ❌ | ✅ | |
| `notes` | string | ✅ | ✅ | ✅ | ✅ | |
| `createdAt` | datetime | ✅ | ✅ | ✅ | ✅ | |
| `updatedAt` | datetime | ✅ | ✅ | ✅ | ✅ | |

---

#### payment_history
| Champ | Type | Backend | DB | Livreur | Admin | Notes |
|-------|------|---------|-----|---------|-------|-------|
| `id` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `organizationId` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `customerId` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `orderId` | UUID | ✅ | ✅ | ✅ | ✅ | Nullable |
| `deliveryId` | UUID | ✅ | ✅ | ✅ | ✅ | Nullable |
| `amount` | decimal | ✅ | ✅ | ✅ | ✅ | |
| `mode` | PaymentMode | ✅ | ✅ | ✅ | ✅ | |
| `paymentType` | PaymentType | ✅ | ✅ | ✅ | ✅ | 'order_payment', 'debt_payment' |
| `collectedBy` | UUID | ✅ | ✅ | ✅ | ✅ | FK users |
| `collectedAt` | datetime | ✅ | ✅ | ✅ | ✅ | |
| `checkNumber` | string | ✅ | ✅ | ❌ | ✅ | Si chèque |
| `checkBank` | string | ✅ | ✅ | ❌ | ✅ | Si chèque |
| `checkDate` | date | ✅ | ✅ | ❌ | ✅ | Si chèque |
| `receiptNumber` | string | ✅ | ✅ | ✅ | ✅ | Numéro reçu |
| `customerDebtBefore` | decimal | ✅ | ✅ | ❌ | ✅ | |
| `customerDebtAfter` | decimal | ✅ | ✅ | ❌ | ✅ | |
| `appliedTo` | JSON | ✅ | ✅ | ❌ | ✅ | Détails répartition |
| `notes` | string | ✅ | ✅ | ✅ | ✅ | |
| `createdAt` | datetime | ✅ | ✅ | ✅ | ✅ | |

---

#### daily_cash
| Champ | Type | Backend | DB | Livreur | Admin | Notes |
|-------|------|---------|-----|---------|-------|-------|
| `id` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `organizationId` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `delivererId` | UUID | ✅ | ✅ | ✅ | ✅ | |
| `date` | date | ✅ | ✅ | ✅ | ✅ | |
| `openingBalance` | decimal | ✅ | ✅ | ✅ | ✅ | Solde départ |
| `expectedCollection` | decimal | ✅ | ✅ | ✅ | ✅ | Attendu |
| `actualCollection` | decimal | ✅ | ✅ | ✅ | ✅ | Encaissé |
| `cashCollected` | decimal | ✅ | ✅ | ✅ | ✅ | Cash uniquement |
| `newDebtCreated` | decimal | ✅ | ✅ | ✅ | ✅ | Nouvelles dettes |
| `deliveriesCount` | int | ✅ | ✅ | ✅ | ✅ | Total livraisons |
| `deliveriesTotal` | int | ✅ | ✅ | ❌ | ✅ | Pour stats |
| `deliveriesCompleted` | int | ✅ | ✅ | ✅ | ✅ | |
| `deliveriesFailed` | int | ✅ | ✅ | ✅ | ✅ | |
| `isClosed` | boolean | ✅ | ✅ | ✅ | ✅ | |
| `closedAt` | datetime | ✅ | ✅ | ✅ | ✅ | |
| `closedBy` | UUID | ✅ | ✅ | ❌ | ✅ | Admin qui valide |
| `cashHandedOver` | decimal | ✅ | ✅ | ✅ | ✅ | Remis à l'admin |
| `expectedAmount` | decimal | ✅ | ✅ | ✅ | ✅ | Pour validation |
| `actualAmount` | decimal | ✅ | ✅ | ✅ | ✅ | Pour validation |
| `difference` | decimal | ✅ | ✅ | ✅ | ✅ | Écart |
| `discrepancy` | decimal | ✅ | ✅ | ❌ | ✅ | Ancien champ (garder compatibilité) |
| `discrepancyNotes` | text | ✅ | ✅ | ✅ | ✅ | |
| `status` | string | ✅ | ✅ | ✅ | ✅ | 'open', 'closed', 'validated' |
| `createdAt` | datetime | ✅ | ✅ | ✅ | ✅ | |
| `updatedAt` | datetime | ✅ | ✅ | ✅ | ✅ | |

---

## 🔌 API ENDPOINTS

### Auth
| Endpoint | Méthode | Backend | Livreur | Client | Admin | Description |
|----------|---------|---------|---------|--------|-------|-------------|
| `/auth/login` | POST | ✅ | ✅ | ❌ | ✅ | Email/password |
| `/auth/logout` | POST | ✅ | ✅ | ❌ | ✅ | |
| `/auth/me` | GET | ✅ | ✅ | ❌ | ✅ | Profil connecté |
| `/auth/refresh` | POST | ✅ | ✅ | ✅ | ✅ | Refresh token |
| `/auth/customer/request-otp` | POST | ✅ | ❌ | ✅ | ❌ | Demande OTP |
| `/auth/customer/verify-otp` | POST | ✅ | ❌ | ✅ | ❌ | Vérifie OTP |
| `/auth/change-password` | PUT | ✅ | ❌ | ❌ | ✅ | |

### Organizations
| Endpoint | Méthode | Backend | Admin | Description |
|----------|---------|---------|-------|-------------|
| `/organization` | GET | ✅ | ✅ | Info org |
| `/organization` | PUT | ✅ | ✅ | Modifier org |
| `/organization/settings` | PUT | ✅ | ✅ | Paramètres |
| `/organization/dashboard` | GET | ✅ | ✅ | Stats dashboard |

### Users
| Endpoint | Méthode | Backend | Admin | Description |
|----------|---------|---------|-------|-------------|
| `/users` | GET | ✅ | ✅ | Liste |
| `/users` | POST | ✅ | ✅ | Créer |
| `/users/:id` | GET | ✅ | ✅ | Détail |
| `/users/:id` | PUT | ✅ | ✅ | Modifier |
| `/users/:id` | DELETE | ✅ | ✅ | Supprimer |
| `/users/:id/performance` | GET | ✅ | ✅ | Stats livreur |
| `/users/:id/position` | PUT | ✅ | ❌ | Màj position (livreur seulement) |

### Customers
| Endpoint | Méthode | Backend | Livreur | Client | Admin | Description |
|----------|---------|---------|---------|--------|-------|-------------|
| `/customers` | GET | ✅ | ✅ | ❌ | ✅ | Liste |
| `/customers` | POST | ✅ | ❌ | ❌ | ✅ | Créer |
| `/customers/:id` | GET | ✅ | ✅ | ❌ | ✅ | Détail |
| `/customers/:id` | PUT | ✅ | ❌ | ❌ | ✅ | Modifier |
| `/customers/:id` | DELETE | ✅ | ❌ | ❌ | ✅ | Supprimer |
| `/customers/:id/orders` | GET | ✅ | ✅ | ❌ | ✅ | Commandes client |
| `/customers/:id/payments` | GET | ✅ | ❌ | ❌ | ✅ | Paiements client |
| `/customers/:id/statement` | GET | ✅ | ❌ | ❌ | ✅ | Relevé |
| `/customers/:id/credit-limit` | PUT | ✅ | ❌ | ❌ | ✅ | Modifier plafond |
| `/customers/me` | GET | ✅ | ❌ | ✅ | ❌ | Profil client (app) |
| `/customers/me/statement` | GET | ✅ | ❌ | ✅ | ❌ | Relevé client (app) |

### Products
| Endpoint | Méthode | Backend | Client | Admin | Description |
|----------|---------|---------|--------|-------|-------------|
| `/products` | GET | ✅ | ✅ | ✅ | Liste |
| `/products` | POST | ✅ | ❌ | ✅ | Créer |
| `/products/:id` | GET | ✅ | ✅ | ✅ | Détail |
| `/products/:id` | PUT | ✅ | ❌ | ✅ | Modifier |
| `/products/:id` | DELETE | ✅ | ❌ | ✅ | Supprimer |
| `/products/:id/stock` | PUT | ✅ | ❌ | ✅ | Ajuster stock |
| `/products/reorder` | PUT | ✅ | ❌ | ✅ | Réordonner |

### Categories
| Endpoint | Méthode | Backend | Client | Admin | Description |
|----------|---------|---------|--------|-------|-------------|
| `/categories` | GET | ✅ | ✅ | ✅ | Liste |
| `/categories` | POST | ✅ | ❌ | ✅ | Créer |
| `/categories/:id` | PUT | ✅ | ❌ | ✅ | Modifier |
| `/categories/:id` | DELETE | ✅ | ❌ | ✅ | Supprimer |

### Orders
| Endpoint | Méthode | Backend | Livreur | Client | Admin | Description |
|----------|---------|---------|---------|--------|-------|-------------|
| `/orders` | GET | ✅ | ✅ | ✅ | ✅ | Liste |
| `/orders` | POST | ✅ | ❌ | ❌ | ✅ | Créer (admin) |
| `/orders/customer` | POST | ✅ | ❌ | ✅ | ❌ | Créer (client) |
| `/orders/:id` | GET | ✅ | ✅ | ✅ | ✅ | Détail |
| `/orders/:id` | PUT | ✅ | ❌ | ❌ | ✅ | Modifier |
| `/orders/:id/status` | PUT | ✅ | ✅ | ❌ | ✅ | Changer statut |
| `/orders/:id/cancel` | PUT | ✅ | ❌ | ❌ | ✅ | Annuler |
| `/orders/:id/duplicate` | POST | ✅ | ❌ | ❌ | ✅ | Dupliquer |

### Deliveries
| Endpoint | Méthode | Backend | Livreur | Admin | Description |
|----------|---------|---------|---------|-------|-------------|
| `/deliveries` | GET | ✅ | ❌ | ✅ | Liste (admin) |
| `/deliveries/my-route` | GET | ✅ | ✅ | ❌ | Ma tournée |
| `/deliveries/assign` | POST | ✅ | ❌ | ✅ | Assigner livreurs |
| `/deliveries/optimize` | PUT | ✅ | ❌ | ✅ | Optimiser tournée |
| `/deliveries/:id` | GET | ✅ | ✅ | ✅ | Détail |
| `/deliveries/:id/status` | PUT | ✅ | ✅ | ❌ | Màj statut |
| `/deliveries/:id/complete` | PUT | ✅ | ✅ | ❌ | Compléter |
| `/deliveries/:id/fail` | PUT | ✅ | ✅ | ❌ | Échec |
| `/deliveries/collect-debt` | POST | ✅ | ✅ | ❌ | Encaisser dette |

### DailyCash
| Endpoint | Méthode | Backend | Livreur | Admin | Description |
|----------|---------|---------|---------|-------|-------------|
| `/daily-cash/today` | GET | ✅ | ✅ | ❌ | Ma caisse |
| `/daily-cash/my-history` | GET | ✅ | ✅ | ❌ | Historique |
| `/daily-cash` | GET | ✅ | ❌ | ✅ | Liste (admin) |
| `/daily-cash/close` | POST | ✅ | ✅ | ❌ | Clôturer |
| `/daily-cash/:id/validate` | PUT | ✅ | ❌ | ✅ | Valider clôture |

### Finance
| Endpoint | Méthode | Backend | Admin | Description |
|----------|---------|---------|-------|-------------|
| `/finance/overview` | GET | ✅ | ✅ | Vue d'ensemble |
| `/finance/debts` | GET | ✅ | ✅ | Liste dettes |
| `/finance/aging-report` | GET | ✅ | ✅ | Aging |
| `/finance/daily-summary` | GET | ✅ | ✅ | Résumé journalier |
| `/finance/reconciliation` | GET | ✅ | ✅ | Réconciliation |
| `/finance/cash-flow` | GET | ✅ | ✅ | Flux de trésorerie |

### Reports
| Endpoint | Méthode | Backend | Admin | Description |
|----------|---------|---------|-------|-------------|
| `/reports/daily` | GET | ✅ | ✅ | Rapport journalier |
| `/reports/weekly` | GET | ✅ | ✅ | Hebdomadaire |
| `/reports/monthly` | GET | ✅ | ✅ | Mensuel |
| `/reports/deliverer/:id` | GET | ✅ | ✅ | Performance livreur |
| `/reports/customer/:id` | GET | ✅ | ✅ | Relevé client |
| `/reports/export` | GET | ✅ | ✅ | Export données |

### Sync (Mobile)
| Endpoint | Méthode | Backend | Livreur | Description |
|----------|---------|---------|---------|-------------|
| `/sync/initial` | GET | ✅ | ✅ | Données initiales |
| `/sync/push` | POST | ✅ | ✅ | Upload transactions |
| `/sync/pull` | GET | ✅ | ✅ | Download màj |
| `/sync/status` | GET | ✅ | ✅ | Statut sync |

### Print
| Endpoint | Méthode | Backend | Livreur | Admin | Description |
|----------|---------|---------|---------|-------|-------------|
| `/print/delivery/:id` | GET | ✅ | ✅ | ✅ | Bon livraison |
| `/print/receipt/:id` | GET | ✅ | ✅ | ✅ | Reçu paiement |
| `/print/statement/:id` | GET | ✅ | ❌ | ✅ | Relevé client |
| `/print/delivery/:id/thermal` | GET | ✅ | ✅ | ❌ | Format thermal |
| `/print/receipt/:id/thermal` | GET | ✅ | ✅ | ❌ | Format thermal |

### Notifications
| Endpoint | Méthode | Backend | Livreur | Client | Admin | Description |
|----------|---------|---------|---------|--------|-------|-------------|
| `/notifications` | GET | ✅ | ✅ | ✅ | ✅ | Liste |
| `/notifications/:id/read` | PATCH | ✅ | ✅ | ✅ | ✅ | Marquer lue |
| `/notifications/read-all` | PATCH | ✅ | ✅ | ✅ | ✅ | Tout marquer |
| `/notifications/register-token` | POST | ✅ | ✅ | ✅ | ✅ | Enregistrer FCM |

---

## 🔄 FLUX MÉTIERS

### 1. Création Commande (Admin)
```
POST /orders
  ↓
Génération orderNumber (trigger SQL)
  ↓
Statut: pending
  ↓
Notification client (FCM)
```

### 2. Création Commande (Client)
```
POST /orders/customer
  ↓
Vérification crédit (credit_limit - current_debt - commande.total)
  ↓
Si OK: pending
  ↓
Notification admin
```

### 3. Livraison + Paiement (Livreur)
```
PUT /deliveries/:id/complete
  ↓
Transaction:
  1. Màj delivery (status=delivered, amountCollected, proofOfDelivery)
  2. Màj order (paymentStatus, amountPaid)
  3. Màj customer (currentDebt)
  4. Créer payment_history
  5. Créer delivery_transactions
  6. Màj daily_cash
  ↓
Notifications:
  - Client: "Commande livrée"
  - Admin: "Livraison complétée"
```

### 4. Paiement FIFO (Logique métier)
```
Montant reçu: 5000 DZD
  ↓
Priorité 1: Payer commande actuelle (2500 DZD)
  ↓
Priorité 2: Payer dettes anciennes par ordre chronologique FIFO
  ↓
Si excédent: Nouvelle dette négative (crédit client)
  ↓
Créer payment_history pour chaque application
```

---

## 📝 CONVENTIONS DE NOMMAGE

### Backend (TypeScript/Drizzle)
- **Tables**: snake_case (orders, daily_cash, payment_history)
- **Champs DB**: snake_case (order_number, amount_paid, created_at)
- **Variables TS**: camelCase (orderNumber, amountPaid, createdAt)
- **Enums**: PascalCase (OrderStatus, PaymentMode)
- **Interfaces**: PascalCase (Order, Delivery, Customer)
- **Fonctions**: camelCase (createOrder, updateDelivery)

### Flutter (Dart)
- **Classes**: PascalCase (Order, Delivery, Customer)
- **Variables**: camelCase (orderNumber, amountPaid)
- **Enums**: PascalCase (OrderStatus, PaymentMode)
- **Fichiers**: snake_case (order_model.dart, delivery_provider.dart)
- **Providers**: lowerCamelCase (orderProvider, deliveryNotifier)
- **Extensions**: PascalCase + Extension (OrderStatusExtension)

### React (TypeScript)
- **Composants**: PascalCase (OrderList, DeliveryCard)
- **Hooks**: camelCase + use (useOrders, useDeliveries)
- **Fichiers**: PascalCase pour composants (OrderList.tsx)
- **Types/Interfaces**: PascalCase (Order, DeliveryStatus)
- **Variables**: camelCase (orderNumber, isLoading)
- **Constants**: SCREAMING_SNAKE_CASE (API_BASE_URL)

---

## ⚠️ POINTS D'ATTENTION

### 1. Mapping Enum Backend ↔ Flutter
**Backend:** `in_delivery`  
**Flutter:** `inDelivery` (enum value) → mappé vers `in_delivery` pour API

### 2. Champs Calculés
- `orders.amountDue` = total - amountPaid (calculé backend)
- `customers.currentDebt` = SUM(orders.amountDue) (calculé trigger SQL)
- `daily_cash.difference` = expectedAmount - actualAmount

### 3. Soft Delete
- Toutes les tables ont `isActive` (soft delete)
- Jamais de DELETE physique sauf exception

### 4. Multi-tenant
- TOUS les endpoints DOIVENT filtrer par `organizationId`
- RLS activé en base de données

### 5. JWT Claims
```json
{
  "sub": "user_id",
  "email": "user@email.com",
  "role": "admin|manager|deliverer|customer",
  "organizationId": "org_uuid",
  "customerId": "customer_uuid"  // Uniquement pour role=customer
}
```

---

## 🧪 CHECKLIST VÉRIFICATION

Avant chaque release, vérifier :

- [ ] Tous les enums sont synchronisés (backend/mobile/admin)
- [ ] Les noms de champs correspondent à ce document
- [ ] Les endpoints API existent dans les 3 clients
- [ ] Les types TypeScript sont à jour
- [ ] Les migrations SQL sont créées
- [ ] Les tests passent sur les flux métiers critiques
- [ ] La documentation est à jour

---

**Version :** 1.0  
**Dernière mise à jour :** 2026-02-01  
**Mainteneur :** Équipe AWID
