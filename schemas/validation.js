const { z } = require("zod");

const schemas = {
  // Auth
  login: z.object({
    email: z.string().email("Email invalide").max(255),
    password: z.string().min(1, "Mot de passe requis").max(128),
  }),

  refreshToken: z.object({
    refreshToken: z.string().min(1, "Refresh token requis"),
  }),

  // Users
  createUser: z.object({
    email: z.string().email("Email invalide").max(255),
    password: z.string().min(6, "Mot de passe: minimum 6 caractÃ¨res").max(128),
    name: z.string().min(1, "Nom requis").max(100),
    phone: z.string().max(20).optional(),
    role: z.enum(["customer", "deliverer", "kitchen"], {
      errorMap: () => ({ message: "RÃ´le invalide" }),
    }),
  }),

  // Products
  createProduct: z.object({
    name: z.string().min(1, "Nom requis").max(100),
    price: z.number().positive("Prix doit Ãªtre positif"),
    imageUrl: z.string().optional().nullable(),
    category: z.string().max(50).optional().nullable(),
    isNew: z.boolean().optional(),
    isPromo: z.boolean().optional(),
    promoPrice: z.number().positive().optional().nullable(),
  }),

  updateProduct: z.object({
    name: z.string().min(1, "Nom requis").max(100),
    price: z.number().positive("Prix doit Ãªtre positif"),
    imageUrl: z.string().optional().nullable(),
    category: z.string().max(50).optional().nullable(),
    isNew: z.boolean().optional(),
    isPromo: z.boolean().optional(),
    promoPrice: z.number().positive().optional().nullable(),
  }),

  reorderProduct: z.object({
    direction: z.enum(["up", "down"]),
  }),

  // Orders
  createOrder: z.object({
    items: z
      .array(
        z.object({
          productId: z.string().uuid("ID produit invalide"),
          quantity: z.number().int().positive("QuantitÃ© doit Ãªtre positive"),
        }),
      )
      .min(1, "Au moins un article requis"),
  }),

  updateOrder: z.object({
    items: z
      .array(
        z.object({
          productId: z.string().uuid("ID produit invalide"),
          quantity: z.number().int().positive("QuantitÃ© doit Ãªtre positive"),
        }),
      )
      .min(1, "Au moins un article requis"),
  }),

  assignDeliverer: z.object({
    delivererId: z.string().min(1, "ID livreur requis"),
  }),

  // Deliveries
  updateDeliveryStatus: z.object({
    status: z.enum(["in_progress", "delivered", "failed", "postponed"]),
    paymentStatus: z.enum(["unpaid", "partial", "paid"]).optional(),
    amountCollected: z.number().min(0).optional(),
    comment: z.string().max(500).optional().nullable(),
    failureReason: z.string().max(100).optional().nullable(),
    postponedTo: z.string().optional().nullable(),
  }),

  // Location
  updateLocation: z.object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
  }),

  // Organization
  updateOrgSettings: z.object({
    kitchenMode: z.boolean().optional(),
  }),

  // Kitchen
  kitchenStatus: z.object({
    status: z.enum(["preparing", "ready"]),
  }),

  // Super Admin
  createOrganization: z.object({
    name: z.string().min(1, "Nom requis").max(100),
    type: z.string().max(50).optional(),
    adminEmail: z.string().email("Email admin invalide").max(255),
    adminPassword: z
      .string()
      .min(6, "Mot de passe: minimum 6 caractÃ¨res")
      .max(128),
    adminName: z.string().min(1, "Nom admin requis").max(100),
    adminPhone: z.string().max(20).optional(),
  }),

  toggleOrgStatus: z.object({
    active: z.boolean(),
  }),

  // UUID param validation
  uuidParam: z.object({
    id: z.string().uuid("ID invalide"),
  }),

  // Debt (Feature 1)
  recordDebtPayment: z.object({
    customer_id: z.string().uuid("ID client invalide"),
    amount: z.number().positive("Montant doit Ãªtre positif"),
    payment_type: z.enum(["cash", "check", "transfer", "other"]).optional(),
    delivery_id: z.string().uuid("ID livraison invalide").optional().nullable(),
    note: z.string().max(500).optional().nullable(),
  }),

  // Payment recording
  recordPayment: z.object({
    clientId: z.string().uuid("ID client invalide"),
    amount: z.number().positive("Montant doit Ãªtre positif"),
    mode: z.enum(["auto", "manual", "oldest_first", "specific"]).optional(),
    deliveryId: z.string().uuid("ID livraison invalide").optional().nullable(),
    targetOrders: z.array(z.string().uuid()).optional().nullable(),
    notes: z.string().max(500).optional().nullable(),
  }),
};

module.exports = schemas;
