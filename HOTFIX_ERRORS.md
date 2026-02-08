# 🔥 HOTFIX - Erreurs Critiques Post-Déploiement

**Date:** 2026-02-05  
**Priorité:** 🔴 CRITIQUE

---

## 🐛 Erreurs Identifiées

### 1. Fonction PostgreSQL `get_unread_count` - Type incorrect

**Erreur:**

```
operator does not exist: uuid = text
PL/pgSQL function get_unread_count(text) line 5
```

**Cause:** La fonction attend TEXT mais reçoit UUID

**Solution:** Recréer la fonction avec UUID

```sql
DROP FUNCTION IF EXISTS get_unread_count(text);

CREATE OR REPLACE FUNCTION get_unread_count(p_user_id uuid)
RETURNS integer AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM notifications
        WHERE user_id = p_user_id
          AND is_read = false
          AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
    );
END;
$$ LANGUAGE plpgsql;
```

---

### 2. Fonction PostgreSQL `detect_order_pattern` manquante

**Erreur:**

```
Cannot read properties of undefined (reading 'detect_order_pattern')
```

**Cause:** La fonction n'existe pas dans la base de données

**Solution DÉFINITIVE:** Créer la fonction PostgreSQL complète

```sql
-- Voir api-v2/migrations/HOTFIX_001_fix_functions.sql
CREATE OR REPLACE FUNCTION detect_order_pattern(
  p_client_id uuid,
  p_organization_id uuid,
  p_items_json text
)
RETURNS jsonb AS $$
-- Fonction qui détecte si un client commande souvent les mêmes produits
-- Retourne: {hasPattern, should_suggest, occurrences, minPatternCount}
$$;
```

**Logique:**

1. Parse les items JSON reçus
2. Extrait les product_ids
3. Récupère le seuil minimum depuis user_preferences (défaut: 3)
4. Compte combien de fois le client a commandé exactement les mêmes produits
5. Suggère de sauvegarder comme favori si occurrences >= seuil

**Fichier:** `api-v2/migrations/HOTFIX_001_fix_functions.sql`

---

### 3. Audit log - Détails trop longs

**Erreur:**

```
value too long for type character varying(100)
```

**Cause:** La colonne `details` dans `audit_logs` est limitée à 100 caractères mais reçoit du JSON

**Solution:** Modifier la colonne pour accepter JSONB

```sql
ALTER TABLE audit_logs
ALTER COLUMN details TYPE jsonb USING details::jsonb;
```

---

### 4. Validation trop stricte sur assignDeliverer

**Erreur:**

```
POST /api/orders/.../assign 400 (multiple clics)
```

**Cause:** Le schéma `assignDeliverer` valide UUID mais le mobile envoie peut-être un format différent

**Solution:** Vérifier le schéma

```javascript
// api-v2/schemas/validation.js
assignDeliverer: z.object({
  delivererId: z.string().uuid("ID livreur invalide"),
}),
```

**Debug:** Ajouter un log pour voir ce qui est envoyé

```javascript
// api-v2/routes/orders.routes.js - ligne 605
router.post("/:id/assign", ..., async (req, res) => {
  logger.info('ASSIGN DEBUG', { body: req.body, delivererId: req.body.delivererId });
  // ...
});
```

---

## 🚀 Actions Immédiates

### Priorité 1 - Corriger les fonctions PostgreSQL

```sql
-- Exécuter dans CloudBeaver/psql

-- 1. Corriger get_unread_count
DROP FUNCTION IF EXISTS get_unread_count(text);
CREATE OR REPLACE FUNCTION get_unread_count(p_user_id uuid)
RETURNS integer AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM notifications
        WHERE user_id = p_user_id
          AND is_read = false
          AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
    );
END;
$$ LANGUAGE plpgsql;

-- 2. Corriger audit_logs
ALTER TABLE audit_logs
ALTER COLUMN details TYPE jsonb USING details::jsonb;
```

### Priorité 2 - Créer detect_order_pattern

```sql
-- Voir api-v2/migrations/HOTFIX_001_fix_functions.sql pour le code complet
-- Exécuter dans CloudBeaver/psql
```

### Priorité 3 - Debug assignDeliverer

```javascript
// Ajouter des logs pour comprendre le problème
```

---

## 📋 Checklist de Correction

- [x] Créer la fonction detect_order_pattern complète dans HOTFIX_001_fix_functions.sql
- [x] Exécuter les corrections SQL (get_unread_count, audit_logs) ✅
- [ ] Exécuter le SQL pour créer detect_order_pattern dans CloudBeaver
- [ ] Ajouter logs debug assignDeliverer (déjà fait dans le code)
- [ ] Tester en production
- [ ] Vérifier les logs

---

## 🔍 Pourquoi ces erreurs n'ont pas été détectées ?

1. **Fonctions PostgreSQL:** Pas vérifiées car hors du code JavaScript
2. **Validation:** Testée en syntaxe mais pas en runtime
3. **Audit log:** Colonne DB pas vérifiée

**Leçon:** Toujours tester en production après déploiement !
