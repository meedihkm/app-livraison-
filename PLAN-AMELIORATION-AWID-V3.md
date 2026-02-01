# 🏗️ Plan d'Amélioration AWID v3.0
## Architecture Extensible & Fonctionnalités par Persona

---

# 📋 Table des Matières

1. [Analyse des Personas](#1-analyse-des-personas)
2. [Architecture Proposée](#2-architecture-proposée)
3. [Migration Joi → Zod](#3-migration-joi--zod)
4. [Fonctionnalités Manquantes par Rôle](#4-fonctionnalités-manquantes-par-rôle)
5. [Roadmap Technique](#5-roadmap-technique)
6. [Structure de Projet Extensible](#6-structure-de-projet-extensible)

---

# 1. Analyse des Personas

## 👔 ADMIN (Gérant/Propriétaire)

### Profil
- Gère l'entreprise de livraison
- Besoin de visibilité totale sur les opérations
- Prend des décisions basées sur les données
- Temps limité, veut des informations rapides

### Frustrations Actuelles
- ❌ Pas de tableau de bord en temps réel
- ❌ Rapports manuels, pas d'exports automatisés
- ❌ Pas d'alertes proactives (crédit, retards, stocks)
- ❌ Gestion des prix complexe (pas de règles automatiques)
- ❌ Pas de vue consolidée multi-organisations

### Besoins Non Couverts
| Besoin | Priorité | Complexité |
|--------|----------|------------|
| Dashboard temps réel (WebSocket) | 🔴 Haute | Moyenne |
| Alertes automatiques (email/SMS/push) | 🔴 Haute | Moyenne |
| Rapports planifiés (PDF hebdo/mensuel) | 🟡 Moyenne | Faible |
| Gestion des prix par client/zone | 🟡 Moyenne | Moyenne |
| Objectifs et KPIs par livreur | 🟡 Moyenne | Faible |
| Multi-organisation (franchise) | 🟢 Basse | Haute |
| Intégration comptabilité (export) | 🟡 Moyenne | Moyenne |

---

## 🚚 LIVREUR

### Profil
- Sur le terrain toute la journée
- Utilise principalement le mobile
- Connexion parfois instable
- Doit être efficace et rapide

### Frustrations Actuelles
- ❌ Pas d'optimisation d'itinéraire automatique
- ❌ Mode hors-ligne limité
- ❌ Pas de navigation intégrée
- ❌ Signature client manquante
- ❌ Pas de photo de preuve de livraison
- ❌ Historique de gains peu visible

### Besoins Non Couverts
| Besoin | Priorité | Complexité |
|--------|----------|------------|
| Optimisation itinéraire (Google/Mapbox) | 🔴 Haute | Haute |
| Mode offline complet avec sync | 🔴 Haute | Haute |
| Signature électronique client | 🔴 Haute | Faible |
| Photo preuve de livraison | 🔴 Haute | Faible |
| Navigation GPS intégrée | 🟡 Moyenne | Moyenne |
| Calcul automatique des gains/commissions | 🟡 Moyenne | Moyenne |
| Chat avec l'admin/support | 🟢 Basse | Moyenne |
| Scan QR code commande | 🟡 Moyenne | Faible |

---

## 🏪 CLIENT (Cafétéria/Restaurant/Commerce)

### Profil
- Passe des commandes régulières
- Veut suivre ses livraisons
- Sensible aux prix et délais
- Gère un budget mensuel

### Frustrations Actuelles
- ❌ Pas de suivi en temps réel de la livraison
- ❌ Historique de factures incomplet
- ❌ Pas de programme de fidélité
- ❌ Réclamations difficiles à faire
- ❌ Pas de catalogue visuel des produits

### Besoins Non Couverts
| Besoin | Priorité | Complexité |
|--------|----------|------------|
| Tracking temps réel livraison | 🔴 Haute | Moyenne |
| Catalogue produits avec photos | 🔴 Haute | Faible |
| Historique factures PDF | 🟡 Moyenne | Faible |
| Système de réclamation | 🟡 Moyenne | Moyenne |
| Programme fidélité / points | 🟢 Basse | Moyenne |
| Notifications push commande | 🔴 Haute | Faible |
| Commande par WhatsApp/SMS | 🟢 Basse | Haute |
| Évaluation de la livraison | 🟡 Moyenne | Faible |

---

## 👨‍🍳 CUISINE/ATELIER (Préparateur)

### Profil
- Prépare les commandes
- Travaille avec les mains (écran tactile)
- Besoin d'interface simple et grande
- Gère les stocks au quotidien

### Frustrations Actuelles
- ❌ Pas de vue Kanban des commandes
- ❌ Pas d'alertes stock bas
- ❌ Interface pas optimisée tactile
- ❌ Pas de temps de préparation estimé
- ❌ Pas de gestion des recettes/compositions

### Besoins Non Couverts
| Besoin | Priorité | Complexité |
|--------|----------|------------|
| Vue Kanban drag & drop | 🔴 Haute | Moyenne |
| Alertes stock bas automatiques | 🔴 Haute | Faible |
| Interface tactile optimisée | 🟡 Moyenne | Moyenne |
| Timer de préparation | 🟡 Moyenne | Faible |
| Gestion des recettes/BOM | 🟢 Basse | Haute |
| Impression tickets cuisine | 🟡 Moyenne | Faible |
| Mode écran de production | 🟡 Moyenne | Moyenne |

---

# 2. Architecture Proposée

## 2.1 Architecture Actuelle vs Proposée

```
ACTUEL (Monolithique)                    PROPOSÉ (Clean Architecture)
========================                 ============================

┌─────────────────────┐                 ┌─────────────────────────────┐
│      Routes         │                 │      Presentation Layer     │
│   (tout mélangé)    │                 │  ┌─────────┐ ┌───────────┐  │
├─────────────────────┤                 │  │ Routes  │ │Controllers│  │
│    Middlewares      │                 │  └────┬────┘ └─────┬─────┘  │
├─────────────────────┤                 └───────┼───────────┼─────────┘
│     Services        │                         │           │
│  (logique métier)   │                 ┌───────▼───────────▼─────────┐
├─────────────────────┤                 │      Application Layer      │
│   Database (pool)   │                 │  ┌──────────┐ ┌──────────┐  │
└─────────────────────┘                 │  │Use Cases │ │   DTOs   │  │
                                        │  └────┬─────┘ └──────────┘  │
                                        └───────┼─────────────────────┘
                                                │
                                        ┌───────▼─────────────────────┐
                                        │       Domain Layer          │
                                        │  ┌──────────┐ ┌──────────┐  │
                                        │  │ Entities │ │ Services │  │
                                        │  └──────────┘ └──────────┘  │
                                        └───────┬─────────────────────┘
                                                │
                                        ┌───────▼─────────────────────┐
                                        │    Infrastructure Layer     │
                                        │ ┌────────┐ ┌──────┐ ┌─────┐ │
                                        │ │  Repos │ │Cache │ │Queue│ │
                                        │ └────────┘ └──────┘ └─────┘ │
                                        └─────────────────────────────┘
```

## 2.2 Structure de Dossiers Proposée

```
awid-api/
├── src/
│   ├── @types/                     # Types TypeScript globaux
│   │   ├── express.d.ts
│   │   └── environment.d.ts
│   │
│   ├── domain/                     # 🎯 CŒUR MÉTIER (pur, sans dépendances)
│   │   ├── entities/
│   │   │   ├── Order.ts
│   │   │   ├── User.ts
│   │   │   ├── Product.ts
│   │   │   ├── Delivery.ts
│   │   │   ├── Payment.ts
│   │   │   └── Organization.ts
│   │   │
│   │   ├── value-objects/          # Objets valeur immuables
│   │   │   ├── Money.ts
│   │   │   ├── Address.ts
│   │   │   ├── PhoneNumber.ts
│   │   │   ├── Email.ts
│   │   │   └── OrderStatus.ts
│   │   │
│   │   ├── events/                 # Domain Events
│   │   │   ├── OrderCreated.ts
│   │   │   ├── PaymentReceived.ts
│   │   │   ├── DeliveryCompleted.ts
│   │   │   └── CreditLimitExceeded.ts
│   │   │
│   │   ├── services/               # Services de domaine
│   │   │   ├── PricingService.ts
│   │   │   ├── CreditService.ts
│   │   │   └── RouteOptimizationService.ts
│   │   │
│   │   └── repositories/           # Interfaces (ports)
│   │       ├── IOrderRepository.ts
│   │       ├── IUserRepository.ts
│   │       └── IProductRepository.ts
│   │
│   ├── application/                # 🔄 CAS D'UTILISATION
│   │   ├── use-cases/
│   │   │   ├── orders/
│   │   │   │   ├── CreateOrder.ts
│   │   │   │   ├── UpdateOrderStatus.ts
│   │   │   │   ├── CancelOrder.ts
│   │   │   │   └── GetOrdersByCustomer.ts
│   │   │   │
│   │   │   ├── deliveries/
│   │   │   │   ├── AssignDelivery.ts
│   │   │   │   ├── CompleteDelivery.ts
│   │   │   │   ├── OptimizeRoute.ts
│   │   │   │   └── RecordProofOfDelivery.ts
│   │   │   │
│   │   │   ├── payments/
│   │   │   │   ├── RecordPayment.ts
│   │   │   │   ├── GenerateInvoice.ts
│   │   │   │   └── ProcessRefund.ts
│   │   │   │
│   │   │   └── reports/
│   │   │       ├── GenerateAgingReport.ts
│   │   │       ├── GenerateCashFlowForecast.ts
│   │   │       └── GenerateDailyReconciliation.ts
│   │   │
│   │   ├── dto/                    # Data Transfer Objects
│   │   │   ├── requests/
│   │   │   │   ├── CreateOrderRequest.ts
│   │   │   │   └── RecordPaymentRequest.ts
│   │   │   └── responses/
│   │   │       ├── OrderResponse.ts
│   │   │       └── FinancialOverviewResponse.ts
│   │   │
│   │   ├── validators/             # 🔷 ZOD SCHEMAS
│   │   │   ├── order.schema.ts
│   │   │   ├── payment.schema.ts
│   │   │   ├── user.schema.ts
│   │   │   └── common.schema.ts
│   │   │
│   │   └── mappers/                # Entity ↔ DTO
│   │       ├── OrderMapper.ts
│   │       └── UserMapper.ts
│   │
│   ├── infrastructure/             # 🔌 ADAPTATEURS EXTERNES
│   │   ├── database/
│   │   │   ├── PostgresConnection.ts
│   │   │   ├── repositories/
│   │   │   │   ├── PostgresOrderRepository.ts
│   │   │   │   ├── PostgresUserRepository.ts
│   │   │   │   └── PostgresProductRepository.ts
│   │   │   └── migrations/
│   │   │
│   │   ├── cache/
│   │   │   ├── RedisCache.ts
│   │   │   └── InMemoryCache.ts
│   │   │
│   │   ├── queue/
│   │   │   ├── BullMQAdapter.ts
│   │   │   └── jobs/
│   │   │       ├── SendNotificationJob.ts
│   │   │       ├── GenerateReportJob.ts
│   │   │       └── CleanupJob.ts
│   │   │
│   │   ├── external/               # Services externes
│   │   │   ├── maps/
│   │   │   │   ├── GoogleMapsService.ts
│   │   │   │   └── MapboxService.ts
│   │   │   ├── notifications/
│   │   │   │   ├── OneSignalService.ts
│   │   │   │   ├── SMSService.ts
│   │   │   │   └── EmailService.ts
│   │   │   ├── storage/
│   │   │   │   ├── S3Service.ts
│   │   │   │   └── LocalStorageService.ts
│   │   │   └── payments/
│   │   │       └── StripeService.ts
│   │   │
│   │   └── logging/
│   │       ├── WinstonLogger.ts
│   │       └── SentryErrorReporter.ts
│   │
│   ├── presentation/               # 🌐 API REST
│   │   ├── http/
│   │   │   ├── controllers/
│   │   │   │   ├── OrderController.ts
│   │   │   │   ├── DeliveryController.ts
│   │   │   │   ├── PaymentController.ts
│   │   │   │   └── ReportController.ts
│   │   │   │
│   │   │   ├── routes/
│   │   │   │   ├── v1/
│   │   │   │   │   ├── index.ts
│   │   │   │   │   ├── orders.routes.ts
│   │   │   │   │   ├── deliveries.routes.ts
│   │   │   │   │   └── financial.routes.ts
│   │   │   │   └── v2/              # Versioning API
│   │   │   │       └── index.ts
│   │   │   │
│   │   │   └── middlewares/
│   │   │       ├── auth.middleware.ts
│   │   │       ├── validate.middleware.ts
│   │   │       ├── rateLimit.middleware.ts
│   │   │       └── errorHandler.middleware.ts
│   │   │
│   │   └── websocket/              # Temps réel
│   │       ├── SocketServer.ts
│   │       ├── handlers/
│   │       │   ├── DeliveryTrackingHandler.ts
│   │       │   └── DashboardHandler.ts
│   │       └── rooms/
│   │           ├── OrganizationRoom.ts
│   │           └── DeliveryRoom.ts
│   │
│   ├── shared/                     # 🔧 UTILITAIRES PARTAGÉS
│   │   ├── errors/
│   │   │   ├── AppError.ts
│   │   │   ├── ValidationError.ts
│   │   │   ├── NotFoundError.ts
│   │   │   └── UnauthorizedError.ts
│   │   │
│   │   ├── utils/
│   │   │   ├── date.utils.ts
│   │   │   ├── crypto.utils.ts
│   │   │   └── pagination.utils.ts
│   │   │
│   │   └── constants/
│   │       ├── orderStatuses.ts
│   │       └── paymentModes.ts
│   │
│   ├── config/                     # ⚙️ CONFIGURATION
│   │   ├── app.config.ts
│   │   ├── database.config.ts
│   │   ├── redis.config.ts
│   │   ├── jwt.config.ts
│   │   └── env.validation.ts       # Validation .env avec Zod
│   │
│   └── main.ts                     # Point d'entrée
│
├── tests/
│   ├── unit/
│   │   ├── domain/
│   │   └── application/
│   ├── integration/
│   │   ├── repositories/
│   │   └── api/
│   └── e2e/
│
├── docs/
│   ├── api/                        # OpenAPI specs
│   ├── architecture/
│   └── deployment/
│
├── scripts/
│   ├── seed.ts
│   ├── migrate.ts
│   └── generate-types.ts
│
├── docker/
│   ├── Dockerfile
│   ├── Dockerfile.dev
│   └── docker-compose.yml
│
├── .env.example
├── tsconfig.json
├── package.json
└── README.md
```

---

# 3. Migration Joi → Zod

## 3.1 Pourquoi Zod ?

| Critère | Joi | Zod |
|---------|-----|-----|
| TypeScript natif | ❌ Types générés | ✅ Types inférés |
| Taille bundle | ~150KB | ~12KB |
| Performance | Moyenne | Excellente |
| Écosystème moderne | Legacy | tRPC, React Hook Form |
| Maintenance | Hapi (ralenti) | Très actif |
| Tree-shaking | ❌ | ✅ |

## 3.2 Exemples de Migration

### Avant (Joi)
```javascript
// api-v2/schemas/validation.js
const Joi = require('joi');

const orderSchema = Joi.object({
  customerId: Joi.string().uuid().required(),
  items: Joi.array().items(
    Joi.object({
      productId: Joi.string().uuid().required(),
      quantity: Joi.number().integer().min(1).max(1000).required(),
      price: Joi.number().positive().max(1000000),
    })
  ).min(1).required(),
  deliveryDate: Joi.date().iso().min('now'),
  notes: Joi.string().max(500).allow('', null),
  priority: Joi.string().valid('normal', 'urgent', 'scheduled').default('normal'),
});

// Validation manuelle
const validate = (schema) => (req, res, next) => {
  const { error, value } = schema.validate(req.body);
  if (error) {
    return res.status(400).json({ error: error.details[0].message });
  }
  req.body = value;
  next();
};
```

### Après (Zod)
```typescript
// src/application/validators/order.schema.ts
import { z } from 'zod';

// Schémas réutilisables
const uuidSchema = z.string().uuid('ID invalide');
const moneySchema = z.number().positive().max(1000000);

// Schéma item de commande
export const orderItemSchema = z.object({
  productId: uuidSchema,
  quantity: z.number().int().min(1).max(1000),
  price: moneySchema.optional(),
  notes: z.string().max(200).optional(),
});

// Schéma commande complet
export const createOrderSchema = z.object({
  customerId: uuidSchema,
  items: z.array(orderItemSchema).min(1, 'Au moins un article requis'),
  deliveryDate: z.coerce.date().min(new Date(), 'Date passée non autorisée').optional(),
  notes: z.string().max(500).optional().nullable(),
  priority: z.enum(['normal', 'urgent', 'scheduled']).default('normal'),
  deliveryAddress: z.object({
    street: z.string().min(5).max(200),
    city: z.string().min(2).max(100),
    coordinates: z.object({
      lat: z.number().min(-90).max(90),
      lng: z.number().min(-180).max(180),
    }).optional(),
  }).optional(),
});

// 🎯 TYPES INFÉRÉS AUTOMATIQUEMENT
export type CreateOrderInput = z.infer<typeof createOrderSchema>;
export type OrderItem = z.infer<typeof orderItemSchema>;

// Schéma de mise à jour (tous les champs optionnels)
export const updateOrderSchema = createOrderSchema.partial().extend({
  id: uuidSchema,
});

// Schéma de requête (query params)
export const orderQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  status: z.enum(['pending', 'confirmed', 'preparing', 'ready', 'delivered', 'cancelled']).optional(),
  customerId: uuidSchema.optional(),
  dateFrom: z.coerce.date().optional(),
  dateTo: z.coerce.date().optional(),
  sortBy: z.enum(['created_at', 'total', 'status']).default('created_at'),
  sortOrder: z.enum(['asc', 'desc']).default('desc'),
});

export type OrderQuery = z.infer<typeof orderQuerySchema>;
```

### Middleware de Validation Zod
```typescript
// src/presentation/http/middlewares/validate.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { AnyZodObject, ZodError } from 'zod';
import { ValidationError } from '@/shared/errors/ValidationError';

type ValidationTarget = 'body' | 'query' | 'params';

interface ValidateOptions {
  stripUnknown?: boolean;
}

export const validate = (
  schema: AnyZodObject,
  target: ValidationTarget = 'body',
  options: ValidateOptions = { stripUnknown: true }
) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await schema.parseAsync(req[target]);
      
      // Remplacer par les données validées et transformées
      req[target] = data;
      
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        // Formater les erreurs de manière lisible
        const errors = error.errors.map(err => ({
          field: err.path.join('.'),
          message: err.message,
          code: err.code,
        }));

        return res.status(400).json({
          success: false,
          error: 'Données invalides',
          details: errors,
        });
      }
      next(error);
    }
  };
};

// Raccourcis pratiques
export const validateBody = (schema: AnyZodObject) => validate(schema, 'body');
export const validateQuery = (schema: AnyZodObject) => validate(schema, 'query');
export const validateParams = (schema: AnyZodObject) => validate(schema, 'params');
```

### Utilisation dans les Routes
```typescript
// src/presentation/http/routes/v1/orders.routes.ts
import { Router } from 'express';
import { validateBody, validateQuery, validateParams } from '@/presentation/http/middlewares/validate.middleware';
import { createOrderSchema, updateOrderSchema, orderQuerySchema } from '@/application/validators/order.schema';
import { OrderController } from '@/presentation/http/controllers/OrderController';
import { authenticate, authorize } from '@/presentation/http/middlewares/auth.middleware';

const router = Router();
const orderController = new OrderController();

// Liste des commandes avec filtres
router.get(
  '/',
  authenticate,
  authorize(['admin', 'kitchen']),
  validateQuery(orderQuerySchema),
  orderController.list
);

// Créer une commande
router.post(
  '/',
  authenticate,
  authorize(['admin', 'customer']),
  validateBody(createOrderSchema),
  orderController.create
);

// Mettre à jour une commande
router.put(
  '/:id',
  authenticate,
  authorize(['admin']),
  validateParams(z.object({ id: z.string().uuid() })),
  validateBody(updateOrderSchema),
  orderController.update
);

export default router;
```

## 3.3 Schémas Zod Complets

```typescript
// src/application/validators/index.ts
export * from './common.schema';
export * from './auth.schema';
export * from './order.schema';
export * from './payment.schema';
export * from './delivery.schema';
export * from './user.schema';
export * from './product.schema';
```

```typescript
// src/application/validators/common.schema.ts
import { z } from 'zod';

// Primitives réutilisables
export const uuidSchema = z.string().uuid('Format UUID invalide');

export const phoneSchema = z.string()
  .regex(/^(\+213|0)(5|6|7)[0-9]{8}$/, 'Numéro de téléphone algérien invalide');

export const emailSchema = z.string().email('Email invalide').toLowerCase();

export const passwordSchema = z.string()
  .min(8, 'Minimum 8 caractères')
  .regex(/[A-Z]/, 'Au moins une majuscule')
  .regex(/[a-z]/, 'Au moins une minuscule')
  .regex(/[0-9]/, 'Au moins un chiffre');

export const moneySchema = z.number()
  .positive('Montant positif requis')
  .max(100000000, 'Montant trop élevé')
  .transform(v => Math.round(v * 100) / 100); // Arrondir à 2 décimales

export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

export const dateRangeSchema = z.object({
  dateFrom: z.coerce.date().optional(),
  dateTo: z.coerce.date().optional(),
}).refine(
  data => !data.dateFrom || !data.dateTo || data.dateFrom <= data.dateTo,
  { message: 'dateFrom doit être avant dateTo' }
);

export const coordinatesSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

export const addressSchema = z.object({
  street: z.string().min(5).max(200),
  city: z.string().min(2).max(100),
  wilaya: z.string().min(2).max(50).optional(),
  postalCode: z.string().regex(/^[0-9]{5}$/).optional(),
  coordinates: coordinatesSchema.optional(),
});

// Types inférés
export type UUID = z.infer<typeof uuidSchema>;
export type Phone = z.infer<typeof phoneSchema>;
export type Email = z.infer<typeof emailSchema>;
export type Money = z.infer<typeof moneySchema>;
export type Pagination = z.infer<typeof paginationSchema>;
export type DateRange = z.infer<typeof dateRangeSchema>;
export type Coordinates = z.infer<typeof coordinatesSchema>;
export type Address = z.infer<typeof addressSchema>;
```

```typescript
// src/application/validators/payment.schema.ts
import { z } from 'zod';
import { uuidSchema, moneySchema } from './common.schema';

export const paymentModeSchema = z.enum(['cash', 'bank', 'check', 'mobile', 'transfer']);

export const recordPaymentSchema = z.object({
  customerId: uuidSchema,
  amount: moneySchema,
  mode: paymentModeSchema.default('cash'),
  targetOrders: z.array(uuidSchema).max(50).optional(),
  notes: z.string().max(500).optional().nullable(),
  deliveryId: uuidSchema.optional().nullable(),
  receiptNumber: z.string().max(50).optional(),
});

export const paymentQuerySchema = z.object({
  customerId: uuidSchema.optional(),
  collectorId: uuidSchema.optional(),
  mode: paymentModeSchema.optional(),
  dateFrom: z.coerce.date().optional(),
  dateTo: z.coerce.date().optional(),
  minAmount: z.coerce.number().positive().optional(),
  maxAmount: z.coerce.number().positive().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

export type RecordPaymentInput = z.infer<typeof recordPaymentSchema>;
export type PaymentQuery = z.infer<typeof paymentQuerySchema>;
export type PaymentMode = z.infer<typeof paymentModeSchema>;
```

```typescript
// src/application/validators/auth.schema.ts
import { z } from 'zod';
import { emailSchema, passwordSchema, phoneSchema } from './common.schema';

export const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1, 'Mot de passe requis'),
  deviceInfo: z.object({
    platform: z.enum(['ios', 'android', 'web']).optional(),
    deviceId: z.string().max(100).optional(),
    appVersion: z.string().max(20).optional(),
  }).optional(),
});

export const registerSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  confirmPassword: z.string(),
  name: z.string().min(2).max(100),
  phone: phoneSchema,
  organizationId: z.string().uuid().optional(),
}).refine(
  data => data.password === data.confirmPassword,
  { message: 'Les mots de passe ne correspondent pas', path: ['confirmPassword'] }
);

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: passwordSchema,
  confirmNewPassword: z.string(),
}).refine(
  data => data.newPassword === data.confirmNewPassword,
  { message: 'Les mots de passe ne correspondent pas', path: ['confirmNewPassword'] }
).refine(
  data => data.currentPassword !== data.newPassword,
  { message: 'Le nouveau mot de passe doit être différent', path: ['newPassword'] }
);

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(32).max(256),
});

export type LoginInput = z.infer<typeof loginSchema>;
export type RegisterInput = z.infer<typeof registerSchema>;
export type ChangePasswordInput = z.infer<typeof changePasswordSchema>;
```

---

# 4. Fonctionnalités Manquantes par Rôle

## 4.1 Admin - Nouvelles Fonctionnalités

### A1. Dashboard Temps Réel
```typescript
// src/presentation/websocket/handlers/DashboardHandler.ts
interface DashboardData {
  orders: {
    pending: number;
    preparing: number;
    ready: number;
    inDelivery: number;
  };
  deliveries: {
    active: number;
    completed: number;
    failed: number;
  };
  revenue: {
    today: number;
    collected: number;
    pending: number;
  };
  alerts: Alert[];
}
```

### A2. Système d'Alertes
```typescript
// src/domain/events/alerts/
- CreditLimitExceeded
- DeliveryDelayed
- StockLow
- LargePaymentReceived
- UnusualActivity
```

### A3. Gestion Tarification Avancée
```typescript
// src/domain/services/PricingService.ts
interface PricingRule {
  type: 'customer' | 'zone' | 'volume' | 'time';
  conditions: PricingCondition[];
  discount: { type: 'percentage' | 'fixed'; value: number };
  validFrom?: Date;
  validUntil?: Date;
}
```

---

## 4.2 Livreur - Nouvelles Fonctionnalités

### L1. Optimisation Itinéraire
```typescript
// src/infrastructure/external/maps/RouteOptimizer.ts
interface OptimizedRoute {
  waypoints: Waypoint[];
  totalDistance: number;     // km
  totalDuration: number;     // minutes
  fuelEstimate: number;      // litres
  sequence: string[];        // order IDs dans l'ordre optimal
}
```

### L2. Preuve de Livraison
```typescript
// src/domain/entities/ProofOfDelivery.ts
interface ProofOfDelivery {
  deliveryId: string;
  signature: {
    dataUrl: string;         // Base64 SVG
    signedBy: string;
    signedAt: Date;
  };
  photos: {
    url: string;
    type: 'product' | 'location' | 'receipt';
    takenAt: Date;
  }[];
  location: Coordinates;
  notes?: string;
}
```

### L3. Mode Hors-ligne
```typescript
// Mobile - Hive/SQLite sync
interface OfflineCapability {
  // Données synchronisées au démarrage
  deliveries: Delivery[];
  customers: CustomerBasic[];
  products: ProductBasic[];
  
  // Actions en attente de sync
  pendingActions: QueuedAction[];
  
  // Dernier sync
  lastSyncAt: Date;
}
```

---

## 4.3 Client - Nouvelles Fonctionnalités

### C1. Tracking Temps Réel
```typescript
// src/presentation/websocket/rooms/DeliveryTrackingRoom.ts
interface TrackingUpdate {
  deliveryId: string;
  status: DeliveryStatus;
  deliverer: {
    name: string;
    phone: string;
    location: Coordinates;
  };
  eta: number;               // minutes
  distanceRemaining: number; // km
}
```

### C2. Système de Réclamation
```typescript
// src/domain/entities/Claim.ts
interface Claim {
  id: string;
  orderId: string;
  customerId: string;
  type: 'quality' | 'delay' | 'missing' | 'wrong' | 'damage' | 'other';
  description: string;
  photos?: string[];
  status: 'open' | 'investigating' | 'resolved' | 'rejected';
  resolution?: {
    type: 'refund' | 'replacement' | 'credit' | 'apology';
    amount?: number;
    notes: string;
    resolvedBy: string;
    resolvedAt: Date;
  };
}
```

### C3. Évaluation Livraison
```typescript
// src/domain/entities/DeliveryRating.ts
interface DeliveryRating {
  deliveryId: string;
  customerId: string;
  overall: 1 | 2 | 3 | 4 | 5;
  categories: {
    punctuality: 1 | 2 | 3 | 4 | 5;
    productQuality: 1 | 2 | 3 | 4 | 5;
    delivererBehavior: 1 | 2 | 3 | 4 | 5;
  };
  comment?: string;
  createdAt: Date;
}
```

---

## 4.4 Cuisine - Nouvelles Fonctionnalités

### K1. Vue Kanban
```typescript
// Frontend - React/Flutter
interface KanbanBoard {
  columns: {
    pending: Order[];
    preparing: Order[];
    ready: Order[];
    pickedUp: Order[];
  };
  // Drag & drop pour changer le statut
}
```

### K2. Gestion Stock
```typescript
// src/domain/entities/Stock.ts
interface StockItem {
  productId: string;
  quantity: number;
  unit: 'kg' | 'l' | 'piece' | 'box';
  minThreshold: number;      // Alerte si < threshold
  reorderQuantity: number;   // Quantité à commander
  lastCountAt: Date;
  location?: string;         // Emplacement entrepôt
}

// src/domain/events/StockLow.ts
interface StockLowEvent {
  productId: string;
  productName: string;
  currentQuantity: number;
  threshold: number;
  suggestedReorder: number;
}
```

---

# 5. Roadmap Technique

## Phase 1: Fondations (4 semaines)

### Semaine 1-2: Migration TypeScript + Architecture
- [ ] Convertir le projet en TypeScript
- [ ] Mettre en place la structure Clean Architecture
- [ ] Migrer Joi → Zod pour tous les schémas
- [ ] Configurer ESLint, Prettier, Husky

### Semaine 3-4: Infrastructure
- [ ] Implémenter le pattern Repository
- [ ] Mettre en place les Domain Events
- [ ] Configurer BullMQ pour les jobs async
- [ ] Tests unitaires couche Domain

## Phase 2: Sécurité & Performance (3 semaines)

### Semaine 5-6: Sécurité Avancée
- [ ] Implémenter Rate Limiting intelligent
- [ ] Ajouter WAF rules (SQL injection, XSS)
- [ ] Mettre en place audit logging complet
- [ ] Tokens avec rotation automatique

### Semaine 7: Performance
- [ ] Optimiser les requêtes N+1 restantes
- [ ] Implémenter cache multi-niveau
- [ ] Compression et lazy loading images
- [ ] Monitoring APM (Datadog/NewRelic)

## Phase 3: Fonctionnalités Admin (4 semaines)

### Semaine 8-9: Dashboard & Alertes
- [ ] WebSocket pour temps réel
- [ ] Dashboard avec métriques clés
- [ ] Système d'alertes configurables
- [ ] Notifications push/email/SMS

### Semaine 10-11: Finance & Rapports
- [ ] Rapports PDF automatisés
- [ ] Export comptable
- [ ] Prévisions avancées ML
- [ ] Réconciliation bancaire

## Phase 4: Fonctionnalités Terrain (4 semaines)

### Semaine 12-13: Livreur
- [ ] Optimisation itinéraire (Google/Mapbox)
- [ ] Signature électronique
- [ ] Photo preuve de livraison
- [ ] Mode hors-ligne complet

### Semaine 14-15: Client & Cuisine
- [ ] Tracking temps réel
- [ ] Système réclamations
- [ ] Vue Kanban cuisine
- [ ] Gestion stocks avec alertes

## Phase 5: Scaling & Bonus (2 semaines)

### Semaine 16-17: Production Ready
- [ ] Load testing (Artillery/k6)
- [ ] Documentation API complète
- [ ] Monitoring et alerting ops
- [ ] CI/CD pipeline optimisé
- [ ] Multi-organisation (franchise)

---

# 6. Structure de Projet Extensible

## 6.1 Principes SOLID Appliqués

### Single Responsibility
```typescript
// ❌ Avant: Route qui fait tout
router.post('/orders', async (req, res) => {
  // Validation, création, notification, audit... 200 lignes
});

// ✅ Après: Séparation des responsabilités
router.post('/orders',
  validateBody(createOrderSchema),  // Validation
  orderController.create            // Délègue au controller
);

// Controller délègue au use case
class OrderController {
  async create(req: Request, res: Response) {
    const result = await this.createOrderUseCase.execute(req.body, req.user);
    res.status(201).json(result);
  }
}

// Use case orchestre le domaine
class CreateOrderUseCase {
  async execute(input: CreateOrderInput, user: User) {
    const order = Order.create(input);          // Domaine
    await this.orderRepository.save(order);     // Persistence
    await this.eventBus.publish(new OrderCreated(order)); // Events
    return OrderMapper.toDTO(order);            // Response
  }
}
```

### Dependency Inversion
```typescript
// src/domain/repositories/IOrderRepository.ts
interface IOrderRepository {
  findById(id: string): Promise<Order | null>;
  findByCustomer(customerId: string, options: QueryOptions): Promise<Order[]>;
  save(order: Order): Promise<void>;
  delete(id: string): Promise<void>;
}

// src/infrastructure/database/repositories/PostgresOrderRepository.ts
class PostgresOrderRepository implements IOrderRepository {
  constructor(private pool: Pool) {}
  
  async findById(id: string): Promise<Order | null> {
    const result = await this.pool.query(
      'SELECT * FROM orders WHERE id = $1', [id]
    );
    return result.rows[0] ? OrderMapper.toDomain(result.rows[0]) : null;
  }
}

// Injection dans le use case
class CreateOrderUseCase {
  constructor(
    private orderRepository: IOrderRepository,  // Interface, pas implémentation
    private eventBus: IEventBus
  ) {}
}
```

## 6.2 Event-Driven Architecture

```typescript
// src/domain/events/DomainEvent.ts
abstract class DomainEvent {
  readonly occurredAt: Date = new Date();
  abstract readonly eventType: string;
}

// src/domain/events/OrderCreated.ts
class OrderCreated extends DomainEvent {
  readonly eventType = 'order.created';
  
  constructor(
    readonly orderId: string,
    readonly customerId: string,
    readonly total: number,
    readonly items: OrderItem[]
  ) {
    super();
  }
}

// src/application/event-handlers/OrderCreatedHandler.ts
class OrderCreatedHandler implements IEventHandler<OrderCreated> {
  constructor(
    private notificationService: INotificationService,
    private stockService: IStockService
  ) {}

  async handle(event: OrderCreated): Promise<void> {
    // Notifier la cuisine
    await this.notificationService.notifyKitchen(event.orderId);
    
    // Mettre à jour le stock prévisionnel
    await this.stockService.reserveItems(event.items);
    
    // Notifier le client
    await this.notificationService.notifyCustomer(
      event.customerId,
      `Commande #${event.orderId} reçue`
    );
  }
}
```

## 6.3 Configuration Extensible

```typescript
// src/config/env.validation.ts
import { z } from 'zod';

const envSchema = z.object({
  // App
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  API_VERSION: z.string().default('v1'),
  
  // Database
  DATABASE_URL: z.string().url(),
  DB_POOL_MIN: z.coerce.number().default(2),
  DB_POOL_MAX: z.coerce.number().default(10),
  
  // Redis
  REDIS_URL: z.string().url().optional(),
  
  // JWT
  JWT_SECRET: z.string().min(32),
  JWT_ACCESS_EXPIRY: z.string().default('15m'),
  JWT_REFRESH_EXPIRY: z.string().default('7d'),
  
  // External Services
  GOOGLE_MAPS_API_KEY: z.string().optional(),
  ONESIGNAL_APP_ID: z.string().optional(),
  ONESIGNAL_API_KEY: z.string().optional(),
  SENTRY_DSN: z.string().url().optional(),
  
  // Storage
  STORAGE_TYPE: z.enum(['local', 's3']).default('local'),
  S3_BUCKET: z.string().optional(),
  S3_REGION: z.string().optional(),
  
  // Features Flags
  FEATURE_ROUTE_OPTIMIZATION: z.coerce.boolean().default(false),
  FEATURE_REALTIME_TRACKING: z.coerce.boolean().default(false),
  FEATURE_MULTI_ORG: z.coerce.boolean().default(false),
});

export type EnvConfig = z.infer<typeof envSchema>;

// Validation au démarrage
export const validateEnv = (): EnvConfig => {
  const parsed = envSchema.safeParse(process.env);
  
  if (!parsed.success) {
    console.error('❌ Configuration invalide:');
    console.error(parsed.error.format());
    process.exit(1);
  }
  
  return parsed.data;
};

export const config = validateEnv();
```

---

# 📊 Résumé des Priorités

| Priorité | Fonctionnalité | Persona | Effort |
|----------|----------------|---------|--------|
| 🔴 P0 | Migration TypeScript + Zod | Tous | 2 sem |
| 🔴 P0 | Dashboard temps réel | Admin | 2 sem |
| 🔴 P0 | Mode hors-ligne complet | Livreur | 3 sem |
| 🔴 P0 | Tracking livraison | Client | 2 sem |
| 🟡 P1 | Optimisation itinéraire | Livreur | 2 sem |
| 🟡 P1 | Preuve de livraison | Livreur | 1 sem |
| 🟡 P1 | Système alertes | Admin | 2 sem |
| 🟡 P1 | Vue Kanban | Cuisine | 1 sem |
| 🟡 P1 | Gestion stocks | Cuisine | 2 sem |
| 🟢 P2 | Réclamations | Client | 2 sem |
| 🟢 P2 | Programme fidélité | Client | 2 sem |
| 🟢 P2 | Multi-organisation | Admin | 4 sem |

---

**Document préparé pour AWID v3.0**  
**Architecture: Clean Architecture + Domain-Driven Design**  
**Stack: TypeScript, Zod, PostgreSQL, Redis, BullMQ, Socket.io**
EOF