# Conversion TEXT → UUID - Terminée ✅

**Date:** 2026-02-04  
**Base de données:** awid (Coolify PostgreSQL)  
**Statut:** ✅ SUCCÈS

## Résumé

Conversion complète de toutes les colonnes ID et FK de TEXT vers UUID pour uniformiser la base de données.

## Résultats

- ✅ **64 colonnes UUID** (tous les ID et foreign keys)
- ✅ **37 foreign keys** recréées avec intégrité référentielle
- ✅ **4 vues** recréées (active_deliveries_view, client_debts_view, daily_stats_view, notification_stats)
- ✅ **0 colonne TEXT restante** (hors amount_paid qui est un montant, pas un ID)

## Tables converties

### Tables principales
- ✅ organizations (id)
- ✅ users (id, organization_id)
- ✅ products (id, organization_id)
- ✅ orders (id, customer_id, organization_id)
- ✅ order_items (id, order_id, product_id)
- ✅ deliveries (id, order_id, deliverer_id, organization_id)
- ✅ audit_logs (id, user_id, organization_id, entity_id)
- ✅ refresh_tokens (id, user_id)

### Tables secondaires
- ✅ payments (customer_id, organization_id, recorded_by)
- ✅ payment_orders (order_id)
- ✅ notifications (user_id, organization_id)
- ✅ recurring_orders (customer_id, organization_id)
- ✅ recurring_order_items (product_id)
- ✅ favorite_orders (client_id, organization_id)
- ✅ packaging_types (organization_id)
- ✅ packaging_deposits (customer_id, organization_id, delivery_id)
- ✅ location_history (deliverer_id, organization_id)
- ✅ client_order_patterns (client_id, organization_id)
- ✅ user_preferences (user_id)
- ✅ notification_preferences (user_id)
- ✅ order_sequences (organization_id)

## Backups créés

1. **awid_backup** - Backup complet avant conversion (dans PostgreSQL)
2. **/tmp/awid_final_uuid.dump** - Dump final après conversion (383.8K)

## Commandes de restauration

### Restaurer depuis le backup PostgreSQL
```bash
# Si besoin de revenir en arrière
psql -U awid_user -d postgres -c "DROP DATABASE IF EXISTS awid;"
psql -U awid_user -d postgres -c "CREATE DATABASE awid WITH TEMPLATE awid_backup;"
```

### Restaurer depuis le dump final
```bash
# Restaurer la version UUID finale
pg_restore -U awid_user -d awid -c /tmp/awid_final_uuid.dump
```

## Prochaines étapes

### 1. Backend API (api-v2)
Le backend utilise déjà des UUID dans la plupart des endroits, mais il faut vérifier :
- ✅ Les modèles utilisent déjà `uuid` pour les ID
- ⚠️ Vérifier les requêtes SQL qui pourraient faire des conversions TEXT
- ⚠️ Tester tous les endpoints

### 2. Application mobile (mobile)
L'app mobile Flutter gère déjà les UUID :
- ✅ Les modèles Dart utilisent `String` pour les UUID
- ⚠️ Tester les flux complets (création commande, paiement, livraison)

### 3. Tests à effectuer
- [ ] Créer un utilisateur
- [ ] Créer un produit
- [ ] Créer une commande
- [ ] Créer une livraison
- [ ] Enregistrer un paiement (déjà testé ✅)
- [ ] Vérifier les vues dans l'app mobile

## Commandes utiles

### Vérifier l'état de la base
```bash
psql -U awid_user -d awid -c "
SELECT 
    '✅ COLONNES UUID' as verification,
    COUNT(*) as count
FROM information_schema.columns
WHERE table_schema = 'public'
AND (column_name LIKE '%_id' OR column_name = 'id')
AND data_type = 'uuid'
UNION ALL
SELECT 
    '🔗 FOREIGN KEYS' as verification,
    COUNT(*) as count
FROM information_schema.table_constraints
WHERE constraint_type = 'FOREIGN KEY'
AND table_schema = 'public';
"
```

### Lister toutes les tables
```bash
psql -U awid_user -d awid -c "\dt"
```

### Voir la structure d'une table
```bash
psql -U awid_user -d awid -c "\d nom_table"
```

## Notes importantes

- Toutes les vues ont été supprimées puis recréées avec les bons types UUID
- Les DEFAULT sur les colonnes ID ont été supprimés temporairement pour la conversion
- Toutes les foreign keys ont été recréées avec les bonnes contraintes (CASCADE, SET NULL)
- La base est maintenant 100% cohérente avec UUID partout

## Environnement

- **Plateforme:** Coolify
- **Base de données:** PostgreSQL
- **Utilisateur:** awid_user
- **Base:** awid
- **Outil de gestion:** CloudBeaver Community + psql

## Auteurs

Conversion réalisée en collaboration étape par étape le 2026-02-04.
