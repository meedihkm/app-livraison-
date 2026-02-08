-- ============================================
-- SCHÉMA DE RÉFÉRENCE DE LA BASE DE DONNÉES
-- Date: 2026-02-04
-- Version: 1.0
-- ============================================
-- Ce fichier documente la structure finale propre de la base

-- ============================================
-- TABLES PRINCIPALES
-- ============================================

-- Organizations (1.7 MB)
-- Gestion des organisations/entreprises

-- Users (176 kB)
-- Gestion des utilisateurs (admin, customer, kitchen, deliverer)
-- 5 users actuellement

-- Products (352 kB)
-- Catalogue des produits

-- Orders (160 kB)
-- Commandes clients
-- 18 orders actuellement

-- Order Items (96 kB)
-- Détails des articles dans chaque commande

-- Deliveries (128 kB)
-- Gestion des livraisons

-- ============================================
-- SYSTÈME DE PAIEMENT (PROPRE)
-- ============================================

-- payments (48 kB)
-- Table principale des paiements de dettes
-- 2 paiements actuellement
-- Colonnes: id, organization_id, customer_id, amount, mode, recorded_by, notes, created_at
-- FK: customer_id → users(id)
-- FK: recorded_by → users(id)
-- FK: organization_id → organizations(id)

-- payment_orders (40 kB)
-- Table de liaison paiement ↔ commandes
-- 6 liaisons actuellement
-- Colonnes: id, payment_id, order_id, amount_applied, created_at
-- FK: payment_id → payments(id) ON DELETE CASCADE
-- FK: order_id → orders(id) ON DELETE CASCADE
-- UNIQUE: (payment_id, order_id)

-- ============================================
-- TABLES SUPPRIMÉES (NETTOYAGE)
-- ============================================

-- ❌ debt_payments (était vide, remplacée par payments)
-- ❌ payment_transactions (était vide, non utilisée)

-- ============================================
-- AUTRES TABLES
-- ============================================

-- Audit & Logs
-- - audit_logs (240 kB)

-- Notifications
-- - notifications (56 kB)
-- - notification_preferences (32 kB)

-- Commandes récurrentes
-- - recurring_orders (112 kB)
-- - recurring_order_items (40 kB)

-- Favoris & Patterns
-- - favorite_orders (40 kB)
-- - client_order_patterns (40 kB)

-- Emballages
-- - packaging_types (32 kB)
-- - packaging_deposits (56 kB)

-- Localisation
-- - location_history (48 kB)

-- Authentification
-- - refresh_tokens (256 kB)

-- Préférences
-- - user_preferences (32 kB)

-- Séquences
-- - order_sequences (32 kB)

-- ============================================
-- STATISTIQUES FINALES
-- ============================================
-- Total tables: 23 (après nettoyage)
-- Total size: ~2.5 MB
-- Users: 5 (1 admin, 2 customers, 1 kitchen, 1 deliverer)
-- Orders: 18
-- Payments: 2
-- Payment-Order links: 6
