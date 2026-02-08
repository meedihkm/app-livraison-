# Problèmes potentiels après conversion TEXT → UUID

## ✅ État actuel
- Base de données : 100% convertie en UUID
- Backend : Compatible (utilise des paramètres SQL)
- Mobile : Compatible (utilise String)

## ❌ PROBLÈME PRINCIPAL : Tokens JWT invalides

### Symptôme
```
401 Token manquant
GET /api/orders?page=1&limit=20 401
GET /api/financial/debts?page=1&limit=50 401
```

### Cause
Les anciens tokens JWT contiennent des `user.id` en format TEXT, mais la base de données cherche maintenant des UUID.

Exemple :
```javascript
// Ancien token (TEXT)
decoded.id = "070ad90e-e41b-40fb-82c0-8961f70dfd0a" (type: string TEXT)

// Requête SQL
SELECT id FROM users WHERE id = $1
// PostgreSQL cherche maintenant un UUID, pas un TEXT
```

### Solution 1 : Forcer la reconnexion (RECOMMANDÉ)
**Tous les utilisateurs doivent se reconnecter pour obtenir de nouveaux tokens.**

#### Option A : Révoquer tous les tokens existants
```bash
psql -U awid_user -d awid -c "UPDATE refresh_tokens SET revoked = true;"
```

#### Option B : Supprimer tous les tokens
```bash
psql -U awid_user -d awid -c "TRUNCATE refresh_tokens;"
```

### Solution 2 : Modifier le middleware auth (temporaire)
Ajouter une conversion explicite dans `api-v2/middleware/auth.js` :

```javascript
// Ligne 23 - AVANT
const result = await pool.query(
  'SELECT id, organization_id, role, active FROM users WHERE id = $1',
  [decoded.id]
);

// APRÈS (avec cast explicite)
const result = await pool.query(
  'SELECT id, organization_id, role, active FROM users WHERE id = $1::uuid',
  [decoded.id]
);
```

**⚠️ Cette solution est temporaire car elle suppose que decoded.id est toujours un UUID valide.**

---

## 🔍 Autres problèmes potentiels

### 1. Refresh Tokens en base
**Problème :** La table `refresh_tokens` a `user_id` en UUID, mais les anciens tokens pointent vers des TEXT.

**Solution :** Même que ci-dessus - forcer la reconnexion.

### 2. Sessions actives
**Problème :** Les sessions en cours ont des `req.user.id` en TEXT dans la mémoire du serveur.

**Solution :** Redémarrer le backend API.

```bash
# Dans Coolify, redémarrer le service api-v2
```

### 3. Cache Redis (si utilisé)
**Problème :** Les clés de cache peuvent contenir des ID en TEXT.

**Solution :** Vider le cache Redis.

```bash
redis-cli FLUSHALL
```

### 4. Logs et Audit
**Problème :** Les anciens logs contiennent des ID en TEXT.

**Solution :** Aucune action nécessaire - les logs historiques restent en TEXT, les nouveaux seront en UUID.

### 5. Données JSON stockées
**Problème :** Les colonnes JSONB (comme `target_orders` dans `payments`) peuvent contenir des ID en TEXT.

**Vérification :**
```sql
SELECT id, target_orders 
FROM payments 
WHERE target_orders IS NOT NULL;
```

**Solution :** Si nécessaire, mettre à jour manuellement :
```sql
-- Exemple si target_orders contient des ID
UPDATE payments 
SET target_orders = (
  SELECT jsonb_agg(order_id::uuid::text)
  FROM jsonb_array_elements_text(target_orders) AS order_id
)
WHERE target_orders IS NOT NULL;
```

### 6. Requêtes avec LIKE sur les ID
**Problème :** Les requêtes qui font `WHERE id LIKE '%something%'` ne fonctionneront plus.

**Vérification :** Chercher dans le code :
```bash
grep -r "LIKE.*id" api-v2/
```

**Solution :** Remplacer par des comparaisons exactes ou utiliser `::text` :
```sql
-- AVANT
WHERE id LIKE '%abc%'

-- APRÈS
WHERE id::text LIKE '%abc%'
```

### 7. Comparaisons de chaînes
**Problème :** Les comparaisons `id > 'something'` ne fonctionnent plus.

**Solution :** Utiliser des comparaisons UUID appropriées ou convertir en text.

### 8. Ordre de tri
**Problème :** `ORDER BY id` donnera un ordre différent (UUID vs TEXT).

**Impact :** Mineur - l'ordre change mais reste cohérent.

**Solution :** Si l'ordre TEXT est important, utiliser `ORDER BY id::text`.

---

## 📋 Checklist de migration

### Étape 1 : Préparation
- [x] Backup de la base de données créé
- [x] Conversion TEXT → UUID terminée
- [x] Foreign keys recréées
- [x] Vues recréées

### Étape 2 : Nettoyage des sessions
- [ ] Révoquer tous les refresh tokens
```bash
psql -U awid_user -d awid -c "TRUNCATE refresh_tokens;"
```

- [ ] Redémarrer le backend API
```bash
# Dans Coolify : Redémarrer le service api-v2
```

- [ ] Vider le cache Redis (si utilisé)
```bash
redis-cli FLUSHALL
```

### Étape 3 : Tests
- [ ] Se connecter avec un compte admin
- [ ] Se connecter avec un compte customer
- [ ] Se connecter avec un compte deliverer
- [ ] Créer une commande
- [ ] Créer une livraison
- [ ] Enregistrer un paiement
- [ ] Vérifier les statistiques

### Étape 4 : Validation
- [ ] Vérifier les logs backend (pas d'erreurs 401)
- [ ] Vérifier que l'app mobile fonctionne
- [ ] Vérifier les vues dans CloudBeaver

---

## 🚀 Actions immédiates à faire

### 1. Révoquer tous les tokens (OBLIGATOIRE)
```bash
psql -U awid_user -d awid -c "TRUNCATE refresh_tokens;"
```

### 2. Redémarrer le backend (OBLIGATOIRE)
Dans Coolify :
1. Aller dans le service api-v2
2. Cliquer sur "Restart"
3. Attendre que le service redémarre

### 3. Demander aux utilisateurs de se reconnecter
Tous les utilisateurs de l'app mobile doivent :
1. Se déconnecter
2. Se reconnecter avec leurs identifiants

### 4. Tester
```bash
# Test de connexion
curl -X POST http://ton-api/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"ton_password"}'

# Vérifier que le token fonctionne
curl -X GET http://ton-api/api/orders \
  -H "Authorization: Bearer TON_TOKEN"
```

---

## 📝 Notes importantes

1. **Les UUID sont rétrocompatibles** : PostgreSQL accepte les UUID sous forme de string
2. **Les anciens tokens sont invalides** : Tous les utilisateurs doivent se reconnecter
3. **Pas de perte de données** : Toutes les données sont préservées
4. **Performance améliorée** : Les UUID sont plus rapides que TEXT pour les index

## 🔧 Commandes utiles

### Vérifier les tokens actifs
```sql
SELECT COUNT(*) FROM refresh_tokens WHERE revoked = false AND expires_at > NOW();
```

### Voir les dernières connexions
```sql
SELECT user_id, created_at FROM refresh_tokens ORDER BY created_at DESC LIMIT 10;
```

### Vérifier les types de colonnes
```sql
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND (column_name LIKE '%_id' OR column_name = 'id')
ORDER BY table_name, column_name;
```
