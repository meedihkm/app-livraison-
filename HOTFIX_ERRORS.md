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

**Solution:** Désactiver temporairement ou créer la fonction

```javascript
// api-v2/routes/favorites.routes.js
// Ligne 104-140 - Commenter temporairement
router.post("/detect-pattern", authenticate, async (req, res) => {
  try {
    // TEMPORAIRE: Fonction désactivée
    res.json({
      success: true,
      data: {
        hasPattern: false,
        message: "Détection de pattern temporairement désactivée",
      },
    });
  } catch (error) {
    // ...
  }
});
```

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

### Priorité 2 - Désactiver detect_order_pattern temporairement

```javascript
// api-v2/routes/favorites.routes.js
// Remplacer la route par un stub
```

### Priorité 3 - Debug assignDeliverer

```javascript
// Ajouter des logs pour comprendre le problème
```

---

## 📋 Checklist de Correction

- [ ] Exécuter les corrections SQL
- [ ] Désactiver detect_order_pattern
- [ ] Ajouter logs debug assignDeliverer
- [ ] Tester en production
- [ ] Vérifier les logs

---

## 🔍 Pourquoi ces erreurs n'ont pas été détectées ?

1. **Fonctions PostgreSQL:** Pas vérifiées car hors du code JavaScript
2. **Validation:** Testée en syntaxe mais pas en runtime
3. **Audit log:** Colonne DB pas vérifiée

**Leçon:** Toujours tester en production après déploiement !
