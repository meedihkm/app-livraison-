-- ============================================
-- CONVERSION COMPLÈTE: TEXT → UUID (avec gestion des vues)
-- Date: 2026-02-04
-- ============================================
-- ⚠️ ATTENTION: Ce script modifie TOUTE la base de données
-- ⚠️ FAIRE UN BACKUP COMPLET AVANT D'EXÉCUTER

-- ============================================
-- ÉTAPE 0: SAUVEGARDER LES DÉFINITIONS DES VUES
-- ============================================

-- On va supprimer les vues, faire la conversion, puis les recréer
-- Liste des vues à gérer:
-- - active_deliveries_view
-- - client_debts_view
-- - client_favorite_stats
-- - customer_packaging_balance
-- - daily_stats_view
-- - notification_stats

-- ============================================
-- ÉTAPE 1: SUPPRIMER TOUTES LES VUES
-- ============================================

DROP VIEW IF EXISTS active_deliveries_view CASCADE;
DROP VIEW IF EXISTS client_debts_view CASCADE;
DROP VIEW IF EXISTS client_favorite_stats CASCADE;
DROP VIEW IF EXISTS customer_packaging_balance CASCADE;
DROP VIEW IF EXISTS daily_stats_view CASCADE;
DROP VIEW IF EXISTS notification_stats CASCADE;

-- ============================================
-- ÉTAPE 2: SUPPRIMER TOUTES LES FOREIGN KEYS
-- ============================================

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT tc.constraint_name, tc.table_name
        FROM information_schema.table_constraints tc
        WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'public'
    ) LOOP
        EXECUTE format('ALTER TABLE %I DROP CONSTRAINT IF EXISTS %I CASCADE', 
                      r.table_name, r.constraint_name);
        RAISE NOTICE 'Dropped FK: %.%', r.table_name, r.constraint_name;
    END LOOP;
END $$;

-- ============================================
-- ÉTAPE 3: CONVERTIR LES TABLES PRINCIPALES
-- ============================================

-- 1. ORGANIZATIONS
ALTER TABLE organizations ALTER COLUMN id TYPE UUID USING id::UUID;

-- 2. USERS
ALTER TABLE users ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE users ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- 3. PRODUCTS
ALTER TABLE products ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE products ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- 4. ORDERS
ALTER TABLE orders ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE orders ALTER COLUMN customer_id TYPE UUID USING customer_id::UUID;
ALTER TABLE orders ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- 5. ORDER_ITEMS
ALTER TABLE order_items ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE order_items ALTER COLUMN order_id TYPE UUID USING order_id::UUID;
ALTER TABLE order_items ALTER COLUMN product_id TYPE UUID USING product_id::UUID;

-- 6. DELIVERIES
ALTER TABLE deliveries ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE deliveries ALTER COLUMN order_id TYPE UUID USING order_id::UUID;
ALTER TABLE deliveries ALTER COLUMN deliverer_id TYPE UUID USING deliverer_id::UUID;
ALTER TABLE deliveries ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- 7. AUDIT_LOGS
ALTER TABLE audit_logs ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE audit_logs ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
ALTER TABLE audit_logs ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;
ALTER TABLE audit_logs ALTER COLUMN entity_id TYPE UUID USING entity_id::UUID;

-- 8. REFRESH_TOKENS
ALTER TABLE refresh_tokens ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE refresh_tokens ALTER COLUMN user_id TYPE UUID USING user_id::UUID;

-- ============================================
-- ÉTAPE 4: CONVERTIR LES TABLES SECONDAIRES
-- ============================================

-- PAYMENTS
ALTER TABLE payments ALTER COLUMN customer_id TYPE UUID USING customer_id::UUID;
ALTER TABLE payments ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;
ALTER TABLE payments ALTER COLUMN recorded_by TYPE UUID USING recorded_by::UUID;

-- PAYMENT_ORDERS
ALTER TABLE payment_orders ALTER COLUMN order_id TYPE UUID USING order_id::UUID;

-- NOTIFICATIONS
ALTER TABLE notifications ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
ALTER TABLE notifications ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- RECURRING_ORDERS
ALTER TABLE recurring_orders ALTER COLUMN customer_id TYPE UUID USING customer_id::UUID;
ALTER TABLE recurring_orders ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- RECURRING_ORDER_ITEMS
ALTER TABLE recurring_order_items ALTER COLUMN product_id TYPE UUID USING product_id::UUID;

-- FAVORITE_ORDERS
ALTER TABLE favorite_orders ALTER COLUMN client_id TYPE UUID USING client_id::UUID;
ALTER TABLE favorite_orders ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- PACKAGING_TYPES
ALTER TABLE packaging_types ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- PACKAGING_DEPOSITS
ALTER TABLE packaging_deposits ALTER COLUMN customer_id TYPE UUID USING customer_id::UUID;
ALTER TABLE packaging_deposits ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;
ALTER TABLE packaging_deposits ALTER COLUMN delivery_id TYPE UUID USING delivery_id::UUID;

-- LOCATION_HISTORY
ALTER TABLE location_history ALTER COLUMN deliverer_id TYPE UUID USING deliverer_id::UUID;
ALTER TABLE location_history ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- CLIENT_ORDER_PATTERNS
ALTER TABLE client_order_patterns ALTER COLUMN client_id TYPE UUID USING client_id::UUID;
ALTER TABLE client_order_patterns ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- USER_PREFERENCES
ALTER TABLE user_preferences ALTER COLUMN user_id TYPE UUID USING user_id::UUID;

-- NOTIFICATION_PREFERENCES
ALTER TABLE notification_preferences ALTER COLUMN user_id TYPE UUID USING user_id::UUID;

-- ORDER_SEQUENCES
ALTER TABLE order_sequences ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- ÉTAPE 5: RECRÉER LES FOREIGN KEYS
-- ============================================

-- Users
ALTER TABLE users ADD CONSTRAINT fk_users_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Products
ALTER TABLE products ADD CONSTRAINT fk_products_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Orders
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer 
FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE orders ADD CONSTRAINT fk_orders_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Order Items
ALTER TABLE order_items ADD CONSTRAINT fk_order_items_order 
FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;
ALTER TABLE order_items ADD CONSTRAINT fk_order_items_product 
FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;

-- Deliveries
ALTER TABLE deliveries ADD CONSTRAINT fk_deliveries_order 
FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;
ALTER TABLE deliveries ADD CONSTRAINT fk_deliveries_deliverer 
FOREIGN KEY (deliverer_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE deliveries ADD CONSTRAINT fk_deliveries_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Payments
ALTER TABLE payments ADD CONSTRAINT fk_payments_customer 
FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE payments ADD CONSTRAINT fk_payments_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE payments ADD CONSTRAINT fk_payments_recorded_by 
FOREIGN KEY (recorded_by) REFERENCES users(id) ON DELETE SET NULL;

-- Payment Orders
ALTER TABLE payment_orders ADD CONSTRAINT fk_payment_orders_payment 
FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE;
ALTER TABLE payment_orders ADD CONSTRAINT fk_payment_orders_order 
FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;

-- Audit Logs
ALTER TABLE audit_logs ADD CONSTRAINT fk_audit_logs_user 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE audit_logs ADD CONSTRAINT fk_audit_logs_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Refresh Tokens
ALTER TABLE refresh_tokens ADD CONSTRAINT fk_refresh_tokens_user 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- Notifications
ALTER TABLE notifications ADD CONSTRAINT fk_notifications_user 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE notifications ADD CONSTRAINT fk_notifications_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Recurring Orders
ALTER TABLE recurring_orders ADD CONSTRAINT fk_recurring_orders_customer 
FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE recurring_orders ADD CONSTRAINT fk_recurring_orders_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Recurring Order Items
ALTER TABLE recurring_order_items ADD CONSTRAINT fk_recurring_order_items_recurring_order 
FOREIGN KEY (recurring_order_id) REFERENCES recurring_orders(id) ON DELETE CASCADE;
ALTER TABLE recurring_order_items ADD CONSTRAINT fk_recurring_order_items_product 
FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;

-- Favorite Orders
ALTER TABLE favorite_orders ADD CONSTRAINT fk_favorite_orders_client 
FOREIGN KEY (client_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE favorite_orders ADD CONSTRAINT fk_favorite_orders_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Packaging Types
ALTER TABLE packaging_types ADD CONSTRAINT fk_packaging_types_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Packaging Deposits
ALTER TABLE packaging_deposits ADD CONSTRAINT fk_packaging_deposits_customer 
FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE packaging_deposits ADD CONSTRAINT fk_packaging_deposits_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE packaging_deposits ADD CONSTRAINT fk_packaging_deposits_packaging_type 
FOREIGN KEY (packaging_type_id) REFERENCES packaging_types(id) ON DELETE CASCADE;
ALTER TABLE packaging_deposits ADD CONSTRAINT fk_packaging_deposits_delivery 
FOREIGN KEY (delivery_id) REFERENCES deliveries(id) ON DELETE SET NULL;

-- Location History
ALTER TABLE location_history ADD CONSTRAINT fk_location_history_deliverer 
FOREIGN KEY (deliverer_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE location_history ADD CONSTRAINT fk_location_history_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Client Order Patterns
ALTER TABLE client_order_patterns ADD CONSTRAINT fk_client_order_patterns_client 
FOREIGN KEY (client_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE client_order_patterns ADD CONSTRAINT fk_client_order_patterns_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- User Preferences
ALTER TABLE user_preferences ADD CONSTRAINT fk_user_preferences_user 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- Notification Preferences
ALTER TABLE notification_preferences ADD CONSTRAINT fk_notification_preferences_user 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- Order Sequences
ALTER TABLE order_sequences ADD CONSTRAINT fk_order_sequences_organization 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- ============================================
-- ÉTAPE 6: RECRÉER LES VUES (avec UUID)
-- ============================================

-- Note: Les vues vont automatiquement utiliser les types UUID maintenant

-- Vue: active_deliveries_view
CREATE OR REPLACE VIEW active_deliveries_view AS
SELECT 
    d.id,
    d.order_id,
    d.deliverer_id,
    d.status,
    d.scheduled_date,
    d.actual_delivery_time,
    o.customer_id,
    u.name as customer_name,
    u.phone as customer_phone,
    u.address as customer_address,
    o.total_amount,
    o.payment_status,
    d.created_at,
    d.updated_at
FROM deliveries d
JOIN orders o ON d.order_id = o.id
JOIN users u ON o.customer_id = u.id
WHERE d.status IN ('pending', 'in_progress');

-- Vue: client_debts_view
CREATE OR REPLACE VIEW client_debts_view AS
SELECT 
    u.id as customer_id,
    u.name as customer_name,
    u.phone as customer_phone,
    u.organization_id,
    COALESCE(SUM(o.total_amount), 0) as total_ordered,
    COALESCE(SUM(CASE WHEN o.payment_status = 'paid' THEN o.total_amount ELSE 0 END), 0) as total_paid,
    COALESCE(SUM(CASE WHEN o.payment_status != 'paid' THEN o.total_amount ELSE 0 END), 0) as total_debt,
    COUNT(o.id) as total_orders,
    MAX(o.created_at) as last_order_date
FROM users u
LEFT JOIN orders o ON u.id = o.customer_id
WHERE u.role = 'customer'
GROUP BY u.id, u.name, u.phone, u.organization_id;

-- Vue: client_favorite_stats
CREATE OR REPLACE VIEW client_favorite_stats AS
SELECT 
    f.client_id,
    f.organization_id,
    COUNT(*) as favorite_count,
    SUM(f.order_count) as total_orders_from_favorites,
    MAX(f.last_ordered) as last_favorite_order_date,
    AVG(f.order_count) as avg_orders_per_favorite
FROM favorite_orders f
GROUP BY f.client_id, f.organization_id;

-- Vue: customer_packaging_balance
CREATE OR REPLACE VIEW customer_packaging_balance AS
SELECT 
    pd.customer_id,
    pd.organization_id,
    pt.name as packaging_name,
    pt.id as packaging_type_id,
    SUM(CASE WHEN pd.transaction_type = 'deposit' THEN pd.quantity ELSE 0 END) as total_deposits,
    SUM(CASE WHEN pd.transaction_type = 'return' THEN pd.quantity ELSE 0 END) as total_returns,
    SUM(CASE WHEN pd.transaction_type = 'deposit' THEN pd.quantity ELSE -pd.quantity END) as current_balance,
    SUM(CASE WHEN pd.transaction_type = 'deposit' THEN pd.quantity * pt.deposit_amount ELSE -pd.quantity * pt.deposit_amount END) as balance_amount
FROM packaging_deposits pd
JOIN packaging_types pt ON pd.packaging_type_id = pt.id
GROUP BY pd.customer_id, pd.organization_id, pt.name, pt.id;

-- Vue: daily_stats_view
CREATE OR REPLACE VIEW daily_stats_view AS
SELECT 
    DATE(o.created_at) as date,
    o.organization_id,
    COUNT(*) as total_orders,
    SUM(o.total_amount) as total_revenue,
    COUNT(DISTINCT o.customer_id) as unique_customers,
    AVG(o.total_amount) as avg_order_value
FROM orders o
GROUP BY DATE(o.created_at), o.organization_id;

-- Vue: notification_stats
CREATE OR REPLACE VIEW notification_stats AS
SELECT 
    n.user_id,
    n.organization_id,
    COUNT(*) as total_notifications,
    SUM(CASE WHEN n.is_read THEN 1 ELSE 0 END) as read_count,
    SUM(CASE WHEN NOT n.is_read THEN 1 ELSE 0 END) as unread_count,
    MAX(n.created_at) as last_notification_date
FROM notifications n
GROUP BY n.user_id, n.organization_id;

-- ============================================
-- ÉTAPE 7: VÉRIFICATION FINALE
-- ============================================

-- Compter les colonnes UUID
SELECT 
    'UUID COLUMNS' as type,
    COUNT(*) as count
FROM information_schema.columns
WHERE table_schema = 'public'
AND data_type = 'uuid'
AND (column_name LIKE '%_id' OR column_name = 'id');

-- Compter les foreign keys
SELECT 
    'FOREIGN KEYS' as type,
    COUNT(*) as count
FROM information_schema.table_constraints
WHERE constraint_type = 'FOREIGN KEY'
AND table_schema = 'public';

-- Compter les vues
SELECT 
    'VIEWS' as type,
    COUNT(*) as count
FROM information_schema.views
WHERE table_schema = 'public';

-- Afficher les colonnes qui ne sont PAS en UUID (devrait être vide)
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name NOT LIKE 'pg_%'
AND (column_name LIKE '%_id' OR column_name = 'id')
AND data_type != 'uuid'
AND table_name NOT IN (
    SELECT table_name 
    FROM information_schema.views 
    WHERE table_schema = 'public'
)
ORDER BY table_name, column_name;
