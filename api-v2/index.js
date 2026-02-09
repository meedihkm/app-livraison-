const express = require("express");
const cors = require("cors");
const compression = require("compression");

// Security configurations
const corsOptions = require("./config/cors");
const { corsErrorHandler } = require("./config/cors");
const {
  securityMiddleware,
  additionalSecurityHeaders,
} = require("./config/security");
const httpsRedirect = require("./middleware/httpsRedirect");
const { globalLimiter } = require("./middleware/rateLimit");

// Routes
const authRoutes = require("./routes/auth.routes");
const productsRoutes = require("./routes/products.routes");
const usersRoutes = require("./routes/users.routes");
const ordersRoutes = require("./routes/orders.routes");
const deliveriesRoutes = require("./routes/deliveries.routes");
const organizationRoutes = require("./routes/organization.routes");
const superAdminRoutes = require("./routes/superAdmin.routes");
const packagingRoutes = require("./routes/packaging.routes");
const recurringOrdersRoutes = require("./routes/recurring-orders.routes");
const favoritesRoutes = require("./routes/favorites.routes");
const financialRoutes = require("./routes/financial.routes"); // Route unifiÃƒÂ©e finances (legacy)
const financialRoutesV2 = require("./routes/financial.routes.v2"); // Routes refactorisÃƒÂ©es v2
const notificationsRoutes = require("./routes/notifications.routes");
const realtimeRoutes = require("./routes/realtime.routes");

const { initSentry, getHandlers } = require("./config/sentry");
const logger = require("./config/logger");
const { requestLogger } = require("./config/logger");
const {
  metricsMiddleware,
  metricsEndpoint,
} = require("./middleware/metrics.middleware");
const healthRoutes = require("./routes/health.routes");

const app = express();

// 0. Initialiser Sentry
initSentry(app);

// Trust proxy pour Vercel
app.set("trust proxy", 1);

// ============================================
// SECURITY MIDDLEWARE (ordre important)
// ============================================

// 1. Sentry Request Handler (doit ÃƒÂªtre le premier middleware)
app.use(getHandlers().requestHandler());
app.use(getHandlers().tracingHandler());

// 2. Redirection HTTPS en production
app.use(httpsRedirect);

// 3. Headers de sÃƒÂ©curitÃƒÂ© Helmet (CSP, HSTS, etc.)
app.use(securityMiddleware);

// 4. Headers de sÃƒÂ©curitÃƒÂ© additionnels
app.use(additionalSecurityHeaders);

// 5. CORS
app.use(cors(corsOptions));
app.use(corsErrorHandler);

// 6. Compression Gzip (Level 6 balance speed/size, threshold 1KB)
app.use(
  compression({
    level: 6,
    threshold: 1024,
    filter: (req, res) => {
      if (req.headers["x-no-compression"]) return false;
      return compression.filter(req, res);
    },
  }),
);

// 7. Servir les fichiers statiques (Uploads) avec Cache-Control agressif pour CDN
app.use(
  "/uploads",
  express.static("uploads", {
    maxAge: "1y",
    immutable: true,
    setHeaders: (res, path) => {
      if (path.endsWith(".webp")) {
        res.setHeader("Cache-Control", "public, max-age=31536000, immutable");
      }
    },
  }),
);

// 6. Metrics RED (Prometheus) - Avant body parsing pour capturer tout
app.use(metricsMiddleware);

// 7. Body parsing avec limite
app.use(express.json({ limit: "1mb" }));

// 8. Logger structurÃƒÂ© (Winston)
app.use(requestLogger);

// 9. Rate limiting global
app.use("/api/", globalLimiter);

// Routes publiques (Monitoring)
app.get("/", (req, res) => {
  res.json({
    status: "ok",
    version: "2.0.0",
    name: "Awid API",
    timestamp: new Date().toISOString(),
  });
});

app.use("/api/health", healthRoutes); // /health, /health/live, /health/ready
app.get("/metrics", metricsEndpoint); // Endpoint Prometheus

// Documentation API (Swagger)
const swaggerUi = require("swagger-ui-express");
const swaggerSpecs = require("./config/swagger");
// Serve Swagger UI
app.use(
  "/api-docs",
  swaggerUi.serve,
  swaggerUi.setup(swaggerSpecs, {
    customCss: ".swagger-ui .topbar { display: none }",
    customSiteTitle: "Awid API Documentation",
  }),
);
app.get("/api-docs-json", (req, res) => {
  res.setHeader("Content-Type", "application/json");
  res.send(swaggerSpecs);
});

// ============================================
// ROUTES API (RefactorisÃƒÂ©es)
// ============================================

// Routes d'authentification
app.use("/api/auth", authRoutes);

// Routes de gestion des ressources
app.use("/api/products", productsRoutes);
app.use("/api/users", usersRoutes);
app.use("/api/orders", ordersRoutes);
app.use("/api/deliveries", deliveriesRoutes);
app.use("/api/deliverers", deliveriesRoutes); // Alias pour compatibilitÃƒÂ©

// Routes d'organisation et finances
app.use("/api/organization", organizationRoutes);
app.use("/api/financial", financialRoutes); // Route unifiÃƒÂ©e finances (overview, debts, payments)
app.use("/api/financial/v2", financialRoutesV2); // Routes refactorisÃƒÂ©es v2 (tests)

// Routes de gestion des consignes
app.use("/api/packaging", packagingRoutes);

// Routes des commandes rÃƒÂ©currentes (RefactorisÃƒÂ©es)
app.use("/api/recurring-orders", recurringOrdersRoutes); // Nouvelle route refactorisÃƒÂ©e

// Routes des favoris et notifications
app.use("/api/favorites", favoritesRoutes);
app.use("/api/notifications", notificationsRoutes);
app.use("/api/realtime", realtimeRoutes); // Routes GPS/localisation temps rÃƒÂ©el
app.use("/api/audit-logs", organizationRoutes); // Routes audit dans organization
// BullMQ & Bull Board
const { createBullBoard } = require("@bull-board/api");
const { BullMQAdapter } = require("@bull-board/api/bullMQAdapter");
const { ExpressAdapter } = require("@bull-board/express");

// Queues & Workers
const { queues } = require("./queues");
const { initWorkers } = require("./workers");

// DÃƒÂ©marrer les workers
initWorkers();

// Setup Bull Board Dashboard
const serverAdapter = new ExpressAdapter();
serverAdapter.setBasePath("/api/admin/queues");

createBullBoard({
  queues: queues.map((q) => new BullMQAdapter(q)),
  serverAdapter: serverAdapter,
});

app.use("/api/admin/queues", serverAdapter.getRouter());

app.use("/api/super-admin", superAdminRoutes);

// Page Super Admin HTML - Servir le fichier statique
const adminPageRouter = require("./routes/admin-page");
app.use("/api/admin", adminPageRouter);

// 404 handler
app.use("/api/*", (req, res) => {
  res.status(404).json({ error: "Route non trouvÃƒÂ©e" });
});

// The Sentry error handler must be before any other error middleware and after all controllers
app.use(getHandlers().errorHandler());

// Custom Error handler
app.use((err, req, res, next) => {
  // Logger l'erreur avec Winston (avec stacktrace complet)
  logger.error(err.message, {
    stack: err.stack,
    url: req.originalUrl,
    method: req.method,
    requestId: req.headers["x-request-id"],
  });

  // RÃƒÂ©ponse client sans stacktrace (sauf Sentry ID si disponible)
  const response = {
    error: "Erreur serveur interne",
    requestId: res.sentry, // ID d'erreur Sentry pour le support
  };

  res.status(500).json(response);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
});

module.exports = app;

