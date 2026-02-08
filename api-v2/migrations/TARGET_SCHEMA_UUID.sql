-- ============================================
-- SCHÉMA CIBLE: TOUT EN UUID
-- Date: 2026-02-04
-- Version: 2.0 (Standardisé)
-- ============================================
-- Ce fichier définit la structure cible après conversion

-- ============================================
-- TABLES PRINCIPALES - STRUCTURE CIBLE
-- ============================================

-- users
-- id: UUID (converti de TEXT)
-- organization_id: UUID (converti de TEXT)

-- organizations  
-- id: UUID (converti de TEXT)

-- products
-- id: UUID (converti de TEXT)
-- organization_id: UUID (converti de TEXT)

-- orders
-- id: UUID (converti de TEXT)
-- customer_id: UUID (converti de TEXT)
-- organization_id: UUID (converti de TEXT)

-- order_items
-- id: UUID (converti de TEXT)
-- order_id: UUID (converti de TEXT)
-- product_id: UUID (converti de TEXT)

-- deliveries
-- id: UUID (converti de TEXT)
-- order_id: UUID (converti de TEXT)
-- deliverer_id: UUID (converti de TEXT)
-- organization_id: UUID (converti de TEXT)

-- payments
-- id: UUID (déjà UUID) ✅
-- customer_id: UUID (converti de TEXT)
-- organization_id: UUID (converti de TEXT)

-- payment_orders
-- id: UUID (déjà UUID) ✅
-- payment_id: UUID (déjà UUID) ✅
-- order_id: UUID (converti de TEXT)

-- ============================================
-- TABLES SECONDAIRES - STRUCTURE CIBLE
-- ============================================

-- audit_logs
-- id: UUID (converti de TEXT)
-- user_id: UUID (converti de TEXT)
-- organization_id: UUID (converti de TEXT)
-- entity_id: UUID (converti de TEXT)

-- refresh_tokens
-- id: UUID (converti de TEXT)
-- user_id: UUID (converti de TEXT)

-- notifications
-- id: UUID (déjà UUID) ✅
-- user_id: UUID (converti de TEXT)
-- organization_id: UUID (converti de TEXT)

-- recurring_orders
-- id: UUID (déjà UUID) ✅
-- customer_id: UUID (converti de TEXT)
-- organization_id: UUID (converti de TEXT)

-- favorite_orders
-- id: UUID (déjà UUID) ✅
-- client_id: UUID (converti de TEXT)
-- organization_id: UUID (converti de TEXT)

-- packaging_types
-- id: UUID (déjà UUID) ✅
-- organization_id: UUID (converti de TEXT)

-- packaging_deposits
-- id: UUID (déjà UUID) ✅
-- customer_id: UUID (déjà UUID) ✅
-- organization_id: UUID (converti de TEXT)
-- packaging_type_id: UUID (déjà UUID) ✅
-- delivery_id: UUID (converti de TEXT)

-- location_history
-- id: UUID (déjà UUID) ✅
-- deliverer_id: UUID (converti de TEXT)
-- organization_id: UUID (converti de TEXT)

-- client_order_patterns
-- id: UUID (déjà UUID) ✅
-- client_id: UUID (converti de TEXT)
-- organization_id: UUID (converti de TEXT)

-- recurring_order_items
-- id: UUID (déjà UUID) ✅
-- recurring_order_id: UUID (déjà UUID) ✅
-- product_id: UUID (converti de TEXT)

-- user_preferences
-- user_id: UUID (converti de TEXT)

-- notification_preferences
-- user_id: UUID (converti de TEXT)

-- order_sequences
-- organization_id: UUID (converti de TEXT)

-- ============================================
-- RÉSUMÉ DES CONVERSIONS
-- ============================================

-- Tables à convertir (ID principal):
-- 1. users.id: TEXT → UUID
-- 2. organizations.id: TEXT → UUID
-- 3. products.id: TEXT → UUID
-- 4. orders.id: TEXT → UUID
-- 5. order_items.id: TEXT → UUID
-- 6. deliveries.id: TEXT → UUID
-- 7. audit_logs.id: TEXT → UUID
-- 8. refresh_tokens.id: TEXT → UUID

-- Colonnes FK à convertir:
-- Toutes les colonnes *_id qui référencent les tables ci-dessus

-- Total estimé: ~50 colonnes à convertir
