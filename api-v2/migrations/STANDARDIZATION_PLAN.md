# Plan de Standardisation de la Base de Données

## Date: 2026-02-04

## Problème Principal

**Incohérence des types de données pour les ID:**
- Certaines tables utilisent `UUID`
- D'autres utilisent `TEXT`
- Impossible de créer des foreign keys entre elles

## Décision de Standardisation

**TOUT doit être en UUID** pour:
- ✅ Performance (UUID natif PostgreSQL)
- ✅ Sécurité (non-séquentiel)
- ✅ Cohérence (un seul type partout)
- ✅ Foreign keys fonctionnelles

## Tables à Auditer

### Tables Principales
- [ ] users
- [ ] organizations
- [ ] products
- [ ] orders
- [ ] order_items
- [ ] deliveries
- [ ] payments
- [ ] payment_orders

### Tables Secondaires
- [ ] audit_logs
- [ ] notifications
- [ ] recurring_orders
- [ ] favorite_orders
- [ ] packaging_types
- [ ] packaging_deposits
- [ ] location_history
- [ ] refresh_tokens

## Plan d'Action

### Phase 1: Audit (EN COURS)
1. Lister toutes les colonnes `*_id` et `id`
2. Identifier les types (TEXT vs UUID)
3. Créer la matrice de conversion

### Phase 2: Conversion
1. Créer un script de migration pour chaque table
2. Convertir TEXT → UUID avec validation
3. Recréer les foreign keys

### Phase 3: Validation
1. Tester toutes les foreign keys
2. Vérifier l'intégrité des données
3. Tester l'API backend

### Phase 4: Documentation
1. Créer le schéma de référence final
2. Mettre à jour les migrations
3. Documenter les changements pour l'app mobile

## Prochaines Étapes

Attendre le résultat de l'audit complet des types...
