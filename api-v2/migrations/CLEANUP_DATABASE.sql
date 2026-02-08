-- ============================================
-- NETTOYAGE DE LA BASE DE DONNÉES
-- Date: 2026-02-04
-- ============================================
-- ATTENTION: À exécuter APRÈS avoir vérifié que users n'est pas vide!

-- ============================================
-- ÉTAPE 1: SUPPRIMER LES TABLES VIDES INUTILES
-- ============================================

-- Supprimer debt_payments (vide, remplacée par payments)
DROP TABLE IF EXISTS debt_payments CASCADE;

-- Supprimer payment_transactions (vide, non utilisée)
DROP TABLE IF EXISTS payment_transactions CASCADE;

-- ============================================
-- ÉTAPE 2: NETTOYER LES FOREIGN KEYS EN DOUBLON
-- ============================================

-- Client Order Patterns - Garder seulement les FK avec noms explicites
ALTER TABLE client_order_patterns 
DROP CONSTRAINT IF EXISTS client_order_patterns_organization_id_fkey;

ALTER TABLE client_order_patterns 
DROP CONSTRAINT IF EXISTS client_order_patterns_client_id_fkey;

-- Favorite Orders - Garder seulement les FK avec noms explicites
ALTER TABLE favorite_orders 
DROP CONSTRAINT IF EXISTS favorite_orders_client_id_fkey;

ALTER TABLE favorite_orders 
DROP CONSTRAINT IF EXISTS favorite_orders_organization_id_fkey;

-- Notification Preferences - Garder seulement les FK avec noms explicites
ALTER TABLE notification_preferences 
DROP CONSTRAINT IF EXISTS notification_preferences_user_id_fkey;

-- Notifications - Garder seulement les FK avec noms explicites
ALTER TABLE notifications 
DROP CONSTRAINT IF EXISTS notifications_organization_id_fkey;

ALTER TABLE notifications 
DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;

-- User Preferences - Garder seulement les FK avec noms explicites
ALTER TABLE user_preferences 
DROP CONSTRAINT IF EXISTS user_preferences_user_id_fkey;

-- ============================================
-- ÉTAPE 3: AJOUTER LES FOREIGN KEYS MANQUANTES
-- ============================================

-- Payment Orders vers Payments (si pas déjà fait)
ALTER TABLE payment_orders 
ADD CONSTRAINT IF NOT EXISTS fk_payment_orders_payment 
FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE;

-- Payment Orders vers Orders (si pas déjà fait)
ALTER TABLE payment_orders 
ADD CONSTRAINT IF NOT EXISTS fk_payment_orders_order 
FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;

-- Payments vers Users
ALTER TABLE payments 
ADD CONSTRAINT IF NOT EXISTS fk_payments_customer 
FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE payments 
ADD CONSTRAINT IF NOT EXISTS fk_payments_recorded_by 
FOREIGN KEY (recorded_by) REFERENCES users(id) ON DELETE SET NULL;

-- Payments vers Organizations
ALTER TABLE payments 
ADD CONSTRAINT IF NOT EXISTS fk_payments_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- ============================================
-- ÉTAPE 4: VÉRIFICATION FINALE
-- ============================================

-- Compter les tables restantes
SELECT 
    'TABLES AFTER CLEANUP' as info,
    COUNT(*) as total_tables
FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

-- Compter les foreign keys
SELECT 
    'FOREIGN KEYS AFTER CLEANUP' as info,
    COUNT(*) as total_fks
FROM information_schema.table_constraints 
WHERE constraint_type = 'FOREIGN KEY' AND table_schema = 'public';

-- Tables de paiement restantes
SELECT 'payments' as table_name, COUNT(*) as records FROM payments
UNION ALL SELECT 'payment_orders', COUNT(*) FROM payment_orders;
