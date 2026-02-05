# 🚀 Plan d'Optimisation Performance - AWID API v2

**Date:** 2026-02-05  
**Version:** 1.0.0

---

## 📊 Analyse des Problèmes Identifiés

### 🔴 CRITIQUE - Requêtes N+1 Détectées

#### 1. **orders.routes.js** - Liste des commandes

**Ligne 202-205:**

```javascript
for (const order of result.rows) {
  const items = await getOrderItems(order.id); // ❌ N+1
  orders.push(formatOrder(order, items));
}
```

**Impact:** Si 50 commandes → 51 requêtes (1 + 50)  
**Solution:** JOIN avec json_agg pour récupérer items en 1 requête

---

#### 2. **orders.routes.js** - Création/Modification commande

**Ligne 318-322:**

```javascript
for (const item of items) {
  const product = await pool.query(
    "SELECT price FROM products WHERE id = $1", // ❌ N+1
    [item.productId],
  );
}
```

**Impact:** Si 10 items → 11 requêtes  
**Solution:** SELECT WHERE id = ANY($1) pour récupérer tous les produits en 1 requête

---

#### 3. **deliveries.routes.js** - Liste des livraisons

**Ligne 217-220:**

```javascript
for (const d of result.rows) {
  const order = await getOrderWithItems(d.order_id);  // ❌ N+1
  deliveries.push({...});
}
```

**Impact:** Si 30 livraisons → 31 requêtes  
**Solution:** JOIN avec json_agg pour récupérer orders + items en 1 requête

---

#### 4. **recurring-orders.routes.js** - Création items

**Ligne 276-279:**

```javascript
for (const item of items) {
  await pool.query(
    `INSERT INTO recurring_order_items ...`,  // ❌ N+1
    [...]
  );
}
```

**Impact:** Si 10 items → 10 requêtes INSERT  
**Solution:** INSERT multiple avec VALUES ($1, $2), ($3, $4), ...

---

#### 5. **financial.routes.js** - Application paiement

**Ligne 448-450:**

```javascript
for (const order of ordersToUpdate.rows) {
  await pool.query(
    `UPDATE orders SET amount_paid = $1 ...`,  // ❌ N+1
    [...]
  );
}
```

**Impact:** Si 5 commandes → 5 requêtes UPDATE  
**Solution:** UPDATE avec CASE WHEN ou transaction batch

---

### 🟡 MOYEN - Cache Non Utilisé

#### Endpoints sans cache actuellement:

- ❌ `GET /api/orders` (liste commandes)
- ❌ `GET /api/deliveries` (liste livraisons)
- ❌ `GET /api/financial/overview` (stats financières)
- ❌ `GET /api/financial/debts` (liste dettes)
- ❌ `GET /api/recurring-orders` (liste récurrentes)
- ❌ `GET /api/favorites` (liste favoris)
- ❌ `GET /api/notifications` (liste notifications)

#### Endpoints avec cache ✅:

- ✅ `GET /api/users` (300s)
- ✅ `GET /api/users/deliverers` (300s)
- ✅ `GET /api/products` (300s)
- ✅ `GET /api/products/categories` (1800s)
- ✅ `GET /api/organization/settings` (600s)

---

## 🎯 Plan d'Action Prioritaire

### Phase 1 : Optimiser Requêtes N+1 (CRITIQUE)

#### 1.1 Orders - Liste avec items (1 requête au lieu de N+1)

```sql
SELECT
  o.*,
  u.name as customer_name,
  u.phone as customer_phone,
  json_agg(
    json_build_object(
      'id', oi.id,
      'productId', oi.product_id,
      'productName', p.name,
      'quantity', oi.quantity,
      'price', oi.price
    )
  ) as items
FROM orders o
LEFT JOIN users u ON o.customer_id = u.id
LEFT JOIN order_items oi ON o.id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.id
WHERE o.organization_id = $1
GROUP BY o.id, u.name, u.phone
ORDER BY o.created_at DESC
```

#### 1.2 Orders - Création avec batch insert items

```sql
-- Au lieu de N INSERT
INSERT INTO order_items (order_id, product_id, quantity, price)
VALUES
  ($1, $2, $3, $4),
  ($1, $5, $6, $7),
  ($1, $8, $9, $10)
RETURNING *;
```

#### 1.3 Orders - Récupérer prix produits en 1 requête

```sql
-- Au lieu de N SELECT
SELECT id, price
FROM products
WHERE id = ANY($1::uuid[])
  AND organization_id = $2;
```

#### 1.4 Deliveries - Liste avec orders + items (1 requête)

```sql
SELECT
  d.*,
  json_build_object(
    'id', o.id,
    'orderNumber', o.order_number,
    'total', o.total,
    'items', (
      SELECT json_agg(
        json_build_object(
          'productName', p.name,
          'quantity', oi.quantity,
          'price', oi.price
        )
      )
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = o.id
    )
  ) as order
FROM deliveries d
LEFT JOIN orders o ON d.order_id = o.id
WHERE d.organization_id = $1
```

#### 1.5 Financial - Batch UPDATE paiements

```sql
-- Au lieu de N UPDATE
UPDATE orders
SET
  amount_paid = CASE id
    WHEN $1 THEN $2
    WHEN $3 THEN $4
    WHEN $5 THEN $6
  END,
  payment_status = CASE id
    WHEN $1 THEN $7
    WHEN $3 THEN $8
    WHEN $5 THEN $9
  END,
  updated_at = NOW()
WHERE id IN ($1, $3, $5);
```

---

### Phase 2 : Ajouter Cache sur Endpoints Fréquents

#### 2.1 Cache Court (60s) - Données changeantes

```javascript
// Liste commandes (change souvent)
router.get("/", authenticate, cacheMiddleware(60), async (req, res) => {
  // ...
});

// Liste livraisons
router.get("/", authenticate, cacheMiddleware(60), async (req, res) => {
  // ...
});
```

#### 2.2 Cache Moyen (300s = 5min) - Données semi-statiques

```javascript
// Stats financières
router.get(
  "/overview",
  authenticate,
  cacheMiddleware(300),
  async (req, res) => {
    // ...
  },
);

// Liste dettes
router.get("/debts", authenticate, cacheMiddleware(300), async (req, res) => {
  // ...
});

// Commandes récurrentes
router.get("/", authenticate, cacheMiddleware(300), async (req, res) => {
  // ...
});
```

#### 2.3 Cache Long (600s = 10min) - Données stables

```javascript
// Favoris (changent rarement)
router.get(
  "/my-favorites",
  authenticate,
  cacheMiddleware(600),
  async (req, res) => {
    // ...
  },
);

// Notifications (lues rarement)
router.get("/", authenticate, cacheMiddleware(600), async (req, res) => {
  // ...
});
```

---

### Phase 3 : Invalidation Cache Intelligente

#### 3.1 Invalidation après mutations

```javascript
// Après création commande
await cacheService.invalidate(`cache:orders:${req.user.organization_id}*`);

// Après paiement
await cacheService.invalidate(`cache:financial:${req.user.organization_id}*`);
await cacheService.invalidate(`cache:orders:${req.user.organization_id}*`);

// Après modification livraison
await cacheService.invalidate(`cache:deliveries:${req.user.organization_id}*`);
await cacheService.invalidate(`cache:orders:${req.user.organization_id}*`);
```

---

### Phase 4 : Indexes Base de Données

#### 4.1 Vérifier indexes existants

```sql
SELECT
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

#### 4.2 Ajouter indexes manquants (si nécessaire)

```sql
-- Index sur foreign keys (si pas déjà présents)
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_organization_id ON orders(organization_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_order_id ON deliveries(order_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_deliverer_id ON deliveries(deliverer_id);

-- Index composites pour requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_orders_org_status ON orders(organization_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_org_created ON orders(organization_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_deliveries_org_status ON deliveries(organization_id, status);
```

---

### Phase 5 : CDN pour Assets Statiques

#### 5.1 Configuration Vercel (si déployé sur Vercel)

```json
// vercel.json
{
  "headers": [
    {
      "source": "/uploads/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ]
}
```

#### 5.2 Alternative : Cloudflare CDN

- Configurer Cloudflare devant l'API
- Cache automatique des assets statiques
- Compression Brotli/Gzip

#### 5.3 Alternative : AWS CloudFront

- Créer distribution CloudFront
- Origin: API Vercel
- Cache behavior: /uploads/\* → TTL 1 an

---

## 📈 Gains Attendus

### Requêtes N+1 Optimisées

- **Avant:** 51 requêtes pour 50 commandes
- **Après:** 1 requête pour 50 commandes
- **Gain:** 98% de requêtes en moins ⚡

### Cache Ajouté

- **Avant:** Chaque requête → DB
- **Après:** 1 requête DB / 5 min (cache hit 80%+)
- **Gain:** 80% de charge DB en moins 📉

### Performance Globale

- **Temps réponse API:** -50% à -70%
- **Charge DB:** -60% à -80%
- **Coût infrastructure:** -30% à -50%

---

## 🔧 Outils de Monitoring

### 1. Métriques à suivre

```javascript
// Déjà implémenté dans metrics.middleware.js
- httpRequestDuration (temps réponse)
- httpRequestsTotal (nombre requêtes)
- cacheHitsTotal (cache hits)
- cacheMissesTotal (cache misses)
```

### 2. Logs de performance

```javascript
// Ajouter dans logger
logger.info("Query performance", {
  query: "getOrders",
  duration: Date.now() - start,
  rowCount: result.rows.length,
});
```

### 3. PostgreSQL slow queries

```sql
-- Activer log des requêtes lentes
ALTER DATABASE awid SET log_min_duration_statement = 1000; -- 1s

-- Voir les requêtes lentes
SELECT * FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

---

## ✅ Checklist d'Implémentation

### Phase 1 - Requêtes N+1 (CRITIQUE)

- [ ] Optimiser `GET /api/orders` (liste avec items)
- [ ] Optimiser `POST /api/orders` (batch insert items)
- [ ] Optimiser `PUT /api/orders/:id` (batch insert items)
- [ ] Optimiser `GET /api/deliveries` (liste avec orders)
- [ ] Optimiser `POST /api/financial/payments` (batch update)
- [ ] Optimiser `POST /api/recurring-orders` (batch insert items)

### Phase 2 - Cache (IMPORTANT)

- [ ] Ajouter cache sur `GET /api/orders`
- [ ] Ajouter cache sur `GET /api/deliveries`
- [ ] Ajouter cache sur `GET /api/financial/overview`
- [ ] Ajouter cache sur `GET /api/financial/debts`
- [ ] Ajouter cache sur `GET /api/recurring-orders`
- [ ] Ajouter cache sur `GET /api/favorites`
- [ ] Ajouter cache sur `GET /api/notifications`

### Phase 3 - Invalidation (IMPORTANT)

- [ ] Invalider cache après création commande
- [ ] Invalider cache après modification commande
- [ ] Invalider cache après paiement
- [ ] Invalider cache après livraison
- [ ] Invalider cache après modification produit

### Phase 4 - Indexes (MOYEN)

- [ ] Vérifier indexes existants
- [ ] Ajouter indexes manquants
- [ ] Tester performance avec EXPLAIN ANALYZE

### Phase 5 - CDN (LONG TERME)

- [ ] Configurer CDN (Vercel/Cloudflare/CloudFront)
- [ ] Tester cache assets statiques
- [ ] Monitorer hit rate CDN

---

## 📊 Estimation Temps

- **Phase 1 (N+1):** 4-6 heures
- **Phase 2 (Cache):** 2-3 heures
- **Phase 3 (Invalidation):** 1-2 heures
- **Phase 4 (Indexes):** 1 heure
- **Phase 5 (CDN):** 2-3 heures

**Total:** 10-15 heures de développement

---

## 🎯 Priorités

1. 🔴 **URGENT:** Optimiser N+1 sur `GET /api/orders` (endpoint le plus utilisé)
2. 🔴 **URGENT:** Optimiser N+1 sur `POST /api/orders` (création commande)
3. 🟠 **IMPORTANT:** Ajouter cache sur endpoints fréquents
4. 🟡 **MOYEN:** Vérifier et ajouter indexes
5. 🟢 **LONG TERME:** CDN pour assets

---

**Fin du plan d'optimisation**
