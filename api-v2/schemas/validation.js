const { z } = require("zod");

// ========================================
// HELPERS DE SANITIZATION
// ========================================

// Helper pour sanitizer les strings (trim + escape HTML basique)
const sanitizedString = (min = 0, max = 255) =>
  z
    .string()
    .trim()
    .min(min, min > 0 ? `Minimum ${min} caractères` : undefined)
    .max(max, `Maximum ${max} caractères`)
    .transform((val) => {
      // Escape HTML basique pour prévenir XSS
      return val
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#x27;")
        .replace(/\//g, "&#x2F;");
    });

// Helper pour email sanitized
const sanitizedEmail = () =>
  z.string().email("Email invalide").max(255).trim().toLowerCase();

// Helper pour phone sanitized
const sanitizedPhone = () =>
  z
    .string()
    .max(20)
    .trim()
    .regex(/^[0-9+\-\s()]*$/, "Numéro de téléphone invalide")
    .optional();

const schemas = {
  // ========================================
  // AUTH
  // ========================================
  login: z.object({
    email: sanitizedEmail(),
    password: z.string().min(1, "Mot de passe requis").max(128),
  }),

  refreshToken: z.object({
    refreshToken: z.string().min(1, "Refresh token requis"),
  }),

  // ========================================
  // USERS
  // ========================================
  createUser: z.object({
    email: sanitizedEmail(),
    password: z.string().min(6, "Mot de passe: minimum 6 caractères").max(128),
    name: sanitizedString(1, 100),
    phone: sanitizedPhone(),
    role: z.enum(["customer", "deliverer", "kitchen"], {
      errorMap: () => ({ message: "Rôle invalide" }),
    }),
  }),

  updateUser: z.object({
    name: sanitizedString(1, 100).optional(),
    phone: sanitizedPhone(),
    email: sanitizedEmail().optional(),
    active: z.boolean().optional(),
    creditLimit: z.number().min(0).max(100000000).optional(),
  }),

  // ========================================
  // PRODUCTS
  // ========================================
  createProduct: z.object({
    name: sanitizedString(1, 100),
    price: z.number().positive("Prix doit être positif").max(1000000),
    imageUrl: z.string().url("URL invalide").optional().nullable(),
    category: sanitizedString(0, 50).optional().nullable(),
    isNew: z.boolean().optional(),
    isPromo: z.boolean().optional(),
    promoPrice: z.number().positive().max(1000000).optional().nullable(),
  }),

  updateProduct: z.object({
    name: sanitizedString(1, 100),
    price: z.number().positive("Prix doit être positif").max(1000000),
    imageUrl: z.string().url("URL invalide").optional().nullable(),
    category: sanitizedString(0, 50).optional().nullable(),
    isNew: z.boolean().optional(),
    isPromo: z.boolean().optional(),
    promoPrice: z.number().positive().max(1000000).optional().nullable(),
  }),

  reorderProduct: z.object({
    direction: z.enum(["up", "down"]),
  }),

  // ========================================
  // ORDERS
  // ========================================
  createOrder: z.object({
    items: z
      .array(
        z.object({
          productId: z.string().uuid("ID produit invalide"),
          quantity: z
            .number()
            .int()
            .positive("Quantité doit être positive")
            .max(1000, "Quantité maximale: 1000"),
        }),
      )
      .min(1, "Au moins un article requis")
      .max(100, "Maximum 100 articles par commande"),
  }),

  updateOrder: z.object({
    items: z
      .array(
        z.object({
          productId: z.string().uuid("ID produit invalide"),
          quantity: z
            .number()
            .int()
            .positive("Quantité doit être positive")
            .max(1000, "Quantité maximale: 1000"),
        }),
      )
      .min(1, "Au moins un article requis")
      .max(100, "Maximum 100 articles par commande"),
  }),

  assignDeliverer: z.object({
    delivererId: z.string().uuid("ID livreur invalide"),
  }),

  // ========================================
  // DELIVERIES
  // ========================================
  updateDeliveryStatus: z.object({
    status: z.enum(["in_progress", "delivered", "failed", "postponed"]),
    paymentStatus: z.enum(["unpaid", "partial", "paid"]).optional(),
    amountCollected: z
      .number()
      .min(0)
      .max(10000000, "Montant trop élevé")
      .optional(),
    comment: sanitizedString(0, 500).optional().nullable(),
    failureReason: sanitizedString(0, 100).optional().nullable(),
    postponedTo: z.string().datetime("Date invalide").optional().nullable(),
  }),

  // ========================================
  // LOCATION
  // ========================================
  updateLocation: z.object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    accuracy: z.number().min(0).optional(),
  }),

  // ========================================
  // FINANCIAL / PAYMENTS
  // ========================================
  recordPayment: z.object({
    customerId: z.string().uuid("ID client invalide"),
    amount: z
      .number()
      .positive("Montant doit être positif")
      .max(10000000, "Montant trop élevé"),
    mode: z
      .enum(["cash", "check", "transfer", "card", "other"])
      .default("cash"),
    notes: sanitizedString(0, 500).optional().nullable(),
    targetOrders: z.array(z.string().uuid()).optional().nullable(),
  }),

  updateCreditLimit: z.object({
    limit: z
      .number()
      .min(0, "Limite doit être positive")
      .max(100000000, "Limite trop élevée"),
  }),

  // ========================================
  // RECURRING ORDERS
  // ========================================
  createRecurringOrder: z.object({
    name: sanitizedString(1, 100),
    frequency: z.enum(["daily", "weekly", "monthly"]),
    dayOfWeek: z.number().int().min(0).max(6).optional().nullable(),
    dayOfMonth: z.number().int().min(1).max(31).optional().nullable(),
    time: z
      .string()
      .regex(
        /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/,
        "Format heure invalide (HH:MM)",
      ),
    items: z
      .array(
        z.object({
          productId: z.string().uuid("ID produit invalide"),
          quantity: z
            .number()
            .int()
            .positive("Quantité doit être positive")
            .max(1000),
        }),
      )
      .min(1, "Au moins un article requis")
      .max(100, "Maximum 100 articles"),
  }),

  updateRecurringOrder: z.object({
    name: sanitizedString(1, 100).optional(),
    frequency: z.enum(["daily", "weekly", "monthly"]).optional(),
    dayOfWeek: z.number().int().min(0).max(6).optional().nullable(),
    dayOfMonth: z.number().int().min(1).max(31).optional().nullable(),
    time: z
      .string()
      .regex(
        /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/,
        "Format heure invalide (HH:MM)",
      )
      .optional(),
    active: z.boolean().optional(),
    items: z
      .array(
        z.object({
          productId: z.string().uuid("ID produit invalide"),
          quantity: z
            .number()
            .int()
            .positive("Quantité doit être positive")
            .max(1000),
        }),
      )
      .min(1, "Au moins un article requis")
      .max(100, "Maximum 100 articles")
      .optional(),
  }),

  // ========================================
  // FAVORITES
  // ========================================
  createFavorite: z.object({
    name: sanitizedString(1, 100),
    items: z
      .array(
        z.object({
          productId: z.string().uuid("ID produit invalide"),
          quantity: z
            .number()
            .int()
            .positive("Quantité doit être positive")
            .max(1000),
        }),
      )
      .min(1, "Au moins un article requis")
      .max(100, "Maximum 100 articles"),
  }),

  updateFavorite: z.object({
    name: sanitizedString(1, 100).optional(),
    items: z
      .array(
        z.object({
          productId: z.string().uuid("ID produit invalide"),
          quantity: z
            .number()
            .int()
            .positive("Quantité doit être positive")
            .max(1000),
        }),
      )
      .min(1, "Au moins un article requis")
      .max(100, "Maximum 100 articles")
      .optional(),
  }),

  // ========================================
  // PACKAGING
  // ========================================
  recordPackaging: z.object({
    deliveryId: z.string().uuid("ID livraison invalide"),
    packagingTypeId: z.string().uuid("ID type consigne invalide"),
    quantityGiven: z
      .number()
      .int()
      .min(0, "Quantité donnée doit être positive")
      .max(1000),
    quantityReturned: z
      .number()
      .int()
      .min(0, "Quantité retournée doit être positive")
      .max(1000),
  }),

  createPackagingType: z.object({
    name: sanitizedString(1, 100),
    value: z.number().positive("Valeur doit être positive").max(100000),
    description: sanitizedString(0, 255).optional().nullable(),
  }),

  updatePackagingType: z.object({
    name: sanitizedString(1, 100).optional(),
    value: z
      .number()
      .positive("Valeur doit être positive")
      .max(100000)
      .optional(),
    description: sanitizedString(0, 255).optional().nullable(),
  }),

  // ========================================
  // NOTIFICATIONS
  // ========================================
  sendNotification: z.object({
    userId: z.string().uuid("ID utilisateur invalide").optional().nullable(),
    role: z
      .enum(["customer", "deliverer", "kitchen", "admin"])
      .optional()
      .nullable(),
    title: sanitizedString(1, 100),
    message: sanitizedString(1, 500),
    type: z.enum(["info", "warning", "error", "success"]).default("info"),
  }),

  // ========================================
  // ORGANIZATION
  // ========================================
  updateOrgSettings: z.object({
    kitchenMode: z.boolean().optional(),
  }),

  // ========================================
  // KITCHEN
  // ========================================
  kitchenStatus: z.object({
    status: z.enum(["preparing", "ready"]),
  }),

  // ========================================
  // SUPER ADMIN
  // ========================================
  createOrganization: z.object({
    name: sanitizedString(1, 100),
    type: sanitizedString(0, 50).optional(),
    adminEmail: sanitizedEmail(),
    adminPassword: z
      .string()
      .min(6, "Mot de passe: minimum 6 caractères")
      .max(128),
    adminName: sanitizedString(1, 100),
    adminPhone: sanitizedPhone(),
  }),

  toggleOrgStatus: z.object({
    active: z.boolean(),
  }),

  // ========================================
  // REALTIME
  // ========================================
  // Déjà défini dans updateLocation ci-dessus

  // ========================================
  // UUID PARAM VALIDATION
  // ========================================
  uuidParam: z.object({
    id: z.string().uuid("ID invalide"),
  }),
};

module.exports = schemas;
