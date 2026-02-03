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
const financialRoutes = require("./routes/financial.routes"); // Route unifiÃ©e finances (legacy)
const financialRoutesV2 = require("./routes/financial.routes.v2"); // Routes refactorisÃ©es v2
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

// 1. Sentry Request Handler (doit Ãªtre le premier middleware)
app.use(getHandlers().requestHandler());
app.use(getHandlers().tracingHandler());

// 2. Redirection HTTPS en production
app.use(httpsRedirect);

// 3. Headers de sÃ©curitÃ© Helmet (CSP, HSTS, etc.)
app.use(securityMiddleware);

// 4. Headers de sÃ©curitÃ© additionnels
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

// 8. Logger structurÃ© (Winston)
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
// ROUTES API (RefactorisÃ©es)
// ============================================

// Routes d'authentification
app.use("/api/auth", authRoutes);

// Routes de gestion des ressources
app.use("/api/products", productsRoutes);
app.use("/api/users", usersRoutes);
app.use("/api/orders", ordersRoutes);
app.use("/api/deliveries", deliveriesRoutes);
app.use("/api/deliverers", deliveriesRoutes); // Alias pour compatibilitÃ©

// Routes d'organisation et finances
app.use("/api/organization", organizationRoutes);
app.use("/api/financial", financialRoutes); // Route unifiÃ©e finances (overview, debts, payments)
app.use("/api/financial/v2", financialRoutesV2); // Routes refactorisÃ©es v2 (tests)

// Routes de gestion des consignes
app.use("/api/packaging", packagingRoutes);

// Routes des commandes rÃ©currentes (RefactorisÃ©es)
app.use("/api/recurring-orders", recurringOrdersRoutes); // Nouvelle route refactorisÃ©e

// Routes des favoris et notifications
app.use("/api/favorites", favoritesRoutes);
app.use("/api/notifications", notificationsRoutes);
app.use("/api/realtime", realtimeRoutes); // Routes GPS/localisation temps rÃ©el
app.use("/api/audit-logs", organizationRoutes); // Routes audit dans organization
// BullMQ & Bull Board
const { createBullBoard } = require("@bull-board/api");
const { BullMQAdapter } = require("@bull-board/api/bullMQAdapter");
const { ExpressAdapter } = require("@bull-board/express");

// Queues & Workers
const { queues } = require("./queues");
const { initWorkers } = require("./workers");

// DÃ©marrer les workers
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

// Page Super Admin HTML (inline pour Vercel serverless)
// Note: Sentry.Handlers.tracingHandler ne trace pas les chaÃ®nes HTML brutes via send()
app.get("/api/admin", (req, res) => {
  res.setHeader("Content-Type", "text/html");
  res.send(`<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Super Admin - Awid v2</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #1a1a2e; color: #fff; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { color: #2E7D32; margin-bottom: 20px; }
        .card { background: #16213e; border-radius: 10px; padding: 20px; margin-bottom: 20px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }
        .stat-box { background: #0f3460; padding: 20px; border-radius: 8px; text-align: center; }
        .stat-box h3 { color: #2E7D32; font-size: 2em; }
        .stat-box p { color: #aaa; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #0f3460; }
        th { background: #0f3460; color: #2E7D32; }
        tr:hover { background: #0f3460; }
        .btn { padding: 8px 16px; border: none; border-radius: 5px; cursor: pointer; margin: 2px; }
        .btn-danger { background: #e94560; color: #fff; }
        .btn-success { background: #2E7D32; color: #fff; }
        .btn-warning { background: #f39c12; color: #000; }
        .form-group { margin-bottom: 15px; }
        .form-group label { display: block; margin-bottom: 5px; color: #aaa; }
        .form-group input { width: 100%; padding: 10px; border: 1px solid #0f3460; border-radius: 5px; background: #1a1a2e; color: #fff; }
        .tabs { display: flex; gap: 10px; margin-bottom: 20px; flex-wrap: wrap; }
        .tab { padding: 10px 20px; background: #0f3460; border: none; color: #fff; cursor: pointer; border-radius: 5px; }
        .tab.active { background: #2E7D32; color: #fff; }
        .hidden { display: none; }
        .status-active { color: #00ff00; }
        .status-inactive { color: #ff0000; }
        #login-section { max-width: 400px; margin: 50px auto; }
        #login-section h2 { color: #2E7D32; margin-bottom: 20px; text-align: center; }
        .error-msg { color: #e94560; margin-top: 10px; text-align: center; }
        #main-content { display: none; }
    </style>
</head>
<body>
    <div class="container">
        <h1>â´°âµ¡âµ‰â´· Super Admin Panel v2</h1>
        <div id="login-section" class="card">
            <h2>Authentification</h2>
            <form id="login-form">
                <div class="form-group">
                    <label>ClÃ© Super Admin</label>
                    <input type="password" id="admin-key" required placeholder="Entrez votre clÃ© secrÃ¨te">
                </div>
                <button type="submit" class="btn btn-success" style="width:100%">Se connecter</button>
                <p id="login-error" class="error-msg hidden"></p>
            </form>
        </div>
        <div id="main-content">
            <div class="tabs">
                <button class="tab active" onclick="showTab('stats')">ðŸ“Š Stats</button>
                <button class="tab" onclick="showTab('orgs')">ðŸ¢ Organisations</button>
                <button class="tab" onclick="showTab('users')">ðŸ‘¥ Utilisateurs</button>
                <button class="tab" onclick="showTab('create')">âž• CrÃ©er Organisation</button>
                <button class="tab btn-danger" onclick="logout()" style="margin-left:auto">ðŸšª DÃ©connexion</button>
            </div>
            <div id="stats" class="card"><h2>Statistiques Globales</h2><div id="stats-content" class="stats"></div></div>
            <div id="orgs" class="card hidden"><h2>Organisations</h2><table><thead><tr><th>ID</th><th>Nom</th><th>Type</th><th>Statut</th><th>Actions</th></tr></thead><tbody id="orgs-table"></tbody></table></div>
            <div id="users" class="card hidden"><h2>Tous les Utilisateurs</h2><table><thead><tr><th>Nom</th><th>Email</th><th>RÃ´le</th><th>Organisation</th><th>Statut</th></tr></thead><tbody id="users-table"></tbody></table></div>
            <div id="create" class="card hidden"><h2>CrÃ©er une Organisation</h2><form id="create-form"><div class="form-group"><label>Nom</label><input type="text" id="org-name" required></div><div class="form-group"><label>Type</label><input type="text" id="org-type" value="restaurant"></div><div class="form-group"><label>Email Admin</label><input type="email" id="admin-email" required></div><div class="form-group"><label>Mot de passe (min 6)</label><input type="password" id="admin-password" required minlength="6"></div><div class="form-group"><label>Nom Admin</label><input type="text" id="admin-name" required></div><div class="form-group"><label>TÃ©lÃ©phone</label><input type="text" id="admin-phone"></div><button type="submit" class="btn btn-success">CrÃ©er</button></form></div>
        </div>
    </div>
    <script>
        const API = window.location.origin + '/api';
        let KEY = '';
        function getHeaders() { return { 'Content-Type': 'application/json', 'x-super-admin-key': KEY }; }
        function checkAuth() { const k = sessionStorage.getItem('superAdminKey'); if (k) { KEY = k; showMainContent(); } }
        document.getElementById('login-form').onsubmit = async (e) => { e.preventDefault(); const key = document.getElementById('admin-key').value; try { const res = await fetch(API + '/super-admin/test', { headers: { 'Content-Type': 'application/json', 'x-super-admin-key': key } }); const data = await res.json(); if (data.success) { KEY = key; sessionStorage.setItem('superAdminKey', key); showMainContent(); } else { document.getElementById('login-error').textContent = 'ClÃ© invalide'; document.getElementById('login-error').classList.remove('hidden'); } } catch (err) { document.getElementById('login-error').textContent = 'Erreur'; document.getElementById('login-error').classList.remove('hidden'); } };
        function showMainContent() { document.getElementById('login-section').style.display = 'none'; document.getElementById('main-content').style.display = 'block'; loadStats(); loadOrgs(); loadUsers(); }
        function logout() { sessionStorage.removeItem('superAdminKey'); KEY = ''; document.getElementById('login-section').style.display = 'block'; document.getElementById('main-content').style.display = 'none'; }
        async function fetchAPI(endpoint) { const res = await fetch(API + endpoint, { headers: getHeaders() }); if (res.status === 403) { logout(); return { success: false }; } return res.json(); }
        function esc(t) { if (!t) return ''; const d = document.createElement('div'); d.textContent = t; return d.innerHTML; }
        async function loadStats() { const data = await fetchAPI('/super-admin/stats'); if (data.success) { document.getElementById('stats-content').innerHTML = '<div class="stat-box"><h3>'+data.data.totalOrganizations+'</h3><p>Organisations</p></div><div class="stat-box"><h3>'+data.data.activeOrganizations+'</h3><p>Actives</p></div><div class="stat-box"><h3>'+data.data.totalUsers+'</h3><p>Utilisateurs</p></div><div class="stat-box"><h3>'+data.data.totalOrders+'</h3><p>Commandes</p></div>'; } }
        async function loadOrgs() { const data = await fetchAPI('/super-admin/organizations'); if (data.success) { document.getElementById('orgs-table').innerHTML = data.data.map(o => '<tr><td>'+o.id+'</td><td>'+esc(o.name)+'</td><td>'+esc(o.type)+'</td><td class="'+(o.active?'status-active':'status-inactive')+'">'+(o.active?'Actif':'Inactif')+'</td><td><button class="btn btn-warning" onclick="toggleOrg(&#39;'+o.id+'&#39;,'+(!o.active)+')">'+(o.active?'DÃ©sactiver':'Activer')+'</button> <button class="btn btn-danger" onclick="deleteOrg(&#39;'+o.id+'&#39;)">Supprimer</button></td></tr>').join(''); } }
        async function loadUsers() { const data = await fetchAPI('/super-admin/users'); if (data.success) { document.getElementById('users-table').innerHTML = data.data.map(u => '<tr><td>'+esc(u.name)+'</td><td>'+esc(u.email)+'</td><td>'+esc(u.role)+'</td><td>'+esc(u.organization_name)+'</td><td class="'+(u.active?'status-active':'status-inactive')+'">'+(u.active?'Actif':'Inactif')+'</td></tr>').join(''); } }
        async function toggleOrg(id, active) { await fetch(API + '/super-admin/organizations/' + id + '/status', { method: 'PATCH', headers: getHeaders(), body: JSON.stringify({ active }) }); loadOrgs(); loadStats(); loadUsers(); }
        async function deleteOrg(id) { if (confirm('Supprimer cette organisation et toutes ses donnÃ©es ?')) { await fetch(API + '/super-admin/organizations/' + id, { method: 'DELETE', headers: getHeaders() }); loadOrgs(); loadStats(); loadUsers(); } }
        document.getElementById('create-form').onsubmit = async (e) => { e.preventDefault(); const body = { name: document.getElementById('org-name').value, type: document.getElementById('org-type').value, adminEmail: document.getElementById('admin-email').value, adminPassword: document.getElementById('admin-password').value, adminName: document.getElementById('admin-name').value, adminPhone: document.getElementById('admin-phone').value }; const res = await fetch(API + '/super-admin/organizations', { method: 'POST', headers: getHeaders(), body: JSON.stringify(body) }); const data = await res.json(); if (data.success) { alert('Organisation crÃ©Ã©e !'); e.target.reset(); loadOrgs(); loadStats(); } else { alert('Erreur: ' + (data.error || 'Inconnue')); } };
        function showTab(tab) { document.querySelectorAll('#main-content .card').forEach(c => c.classList.add('hidden')); document.querySelectorAll('.tab').forEach(t => t.classList.remove('active')); document.getElementById(tab).classList.remove('hidden'); event.target.classList.add('active'); }
        checkAuth();
    </script>
</body>
</html>`);
});

// 404 handler
app.use("/api/*", (req, res) => {
  res.status(404).json({ error: "Route non trouvÃ©e" });
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

  // RÃ©ponse client sans stacktrace (sauf Sentry ID si disponible)
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
