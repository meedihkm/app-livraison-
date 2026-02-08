-- ============================================
-- CONVERSION UUID - VERSION SIMPLE (sans blocs DO)
-- Exécuter section par section
-- ============================================

-- ============================================
-- SECTION 1: SUPPRIMER LES VUES
-- ============================================
DROP VIEW IF EXISTS active_deliveries_view CASCADE;
DROP VIEW IF EXISTS client_debts_view CASCADE;
DROP VIEW IF EXISTS client_favorite_stats CASCADE;
DROP VIEW IF EXISTS customer_packaging_balance CASCADE;
DROP VIEW IF EXISTS daily_stats_view CASCADE;
DROP VIEW IF EXISTS notification_stats CASCADE;

-- ============================================
-- SECTION 2: SUPPRIMER LES FOREIGN KEYS
-- (Copier toutes les lignes ci-dessous ensemble)
-- ============================================
ALTER TABLE users DROP CONSTRAINT IF EXISTS fk_users_organization CASCADE;
ALTER TABLE products DROP CONSTRAINT IF EXISTS fk_products_organization CASCADE;
ALTER TABLE orders DROP CONSTRAINT IF EXISTS fk_orders_customer CASCADE;
ALTER TABLE orders DROP CONSTRAINT IF EXISTS fk_orders_organization CASCADE;
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS fk_order_items_order CASCADE;
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS fk_order_items_product CASCADE;
ALTER TABLE deliveries DROP CONSTRAINT IF EXISTS fk_deliveries_order CASCADE;
ALTER TABLE deliveries DROP CONSTRAINT IF EXISTS fk_deliveries_deliverer CASCADE;
ALTER TABLE deliveries DROP CONSTRAINT IF EXISTS fk_deliveries_organization CASCADE;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS fk_payments_customer CASCADE;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS fk_payments_organization CASCADE;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS fk_payments_recorded_by CASCADE;
ALTER TABLE payment_orders DROP CONSTRAINT IF EXISTS fk_payment_orders_payment CASCADE;
ALTER TABLE payment_orders DROP CONSTRAINT IF EXISTS fk_payment_orders_order CASCADE;
ALTER TABLE audit_logs DROP CONSTRAINT IF EXISTS fk_audit_logs_user CASCADE;
ALTER TABLE audit_logs DROP CONSTRAINT IF EXISTS fk_audit_logs_organization CASCADE;
ALTER TABLE refresh_tokens DROP CONSTRAINT IF EXISTS fk_refresh_tokens_user CASCADE;
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS fk_notifications_user CASCADE;
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS fk_notifications_organization CASCADE;
ALTER TABLE recurring_orders DROP CONSTRAINT IF EXISTS fk_recurring_orders_customer CASCADE;
ALTER TABLE recurring_orders DROP CONSTRAINT IF EXISTS fk_recurring_orders_organization CASCADE;
ALTER TABLE recurring_order_items DROP CONSTRAINT IF EXISTS fk_recurring_order_items_recurring_order CASCADE;
ALTER TABLE recurring_order_items DROP CONSTRAINT IF EXISTS fk_recurring_order_items_product CASCADE;
ALTER TABLE favorite_orders DROP CONSTRAINT IF EXISTS fk_favorite_orders_client CASCADE;
ALTER TABLE favorite_orders DROP CONSTRAINT IF EXISTS fk_favorite_orders_organization CASCADE;
ALTER TABLE packaging_types DROP CONSTRAINT IF EXISTS fk_packaging_types_organization CASCADE;
ALTER TABLE packaging_deposits DROP CONSTRAINT IF EXISTS fk_packaging_deposits_customer CASCADE;
ALTER TABLE packaging_deposits DROP CONSTRAINT IF EXISTS fk_packaging_deposits_organization CASCADE;
ALTER TABLE packaging_deposits DROP CONSTRAINT IF EXISTS fk_packaging_deposits_packaging_type CASCADE;
ALTER TABLE packaging_deposits DROP CONSTRAINT IF EXISTS fk_packaging_deposits_delivery CASCADE;
ALTER TABLE location_history DROP CONSTRAINT IF EXISTS fk_location_history_deliverer CASCADE;
ALTER TABLE location_history DROP CONSTRAINT IF EXISTS fk_location_history_organization CASCADE;
ALTER TABLE client_order_patterns DROP CONSTRAINT IF EXISTS fk_client_order_patterns_client CASCADE;
ALTER TABLE client_order_patterns DROP CONSTRAINT IF EXISTS fk_client_order_patterns_organization CASCADE;
ALTER TABLE user_preferences DROP CONSTRAINT IF EXISTS fk_user_preferences_user CASCADE;
ALTER TABLE notification_preferences DROP CONSTRAINT IF EXISTS fk_notification_preferences_user CASCADE;
ALTER TABLE order_sequences DROP CONSTRAINT IF EXISTS fk_order_sequences_organization CASCADE;

-- ============================================
-- SECTION 3: CONVERTIR ORGANIZATIONS (EN PREMIER)
-- ============================================
ALTER TABLE organizations ALTER COLUMN id TYPE UUID USING id::UUID;

-- ============================================
-- SECTION 4: CONVERTIR USERS
-- ============================================
ALTER TABLE users ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE users ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- SECTION 5: CONVERTIR PRODUCTS
-- ============================================
ALTER TABLE products ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE products ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- SECTION 6: CONVERTIR ORDERS
-- ============================================
ALTER TABLE orders ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE orders ALTER COLUMN customer_id TYPE UUID USING customer_id::UUID;
ALTER TABLE orders ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- SECTION 7: CONVERTIR ORDER_ITEMS
-- ============================================
ALTER TABLE order_items ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE order_items ALTER COLUMN order_id TYPE UUID USING order_id::UUID;
ALTER TABLE order_items ALTER COLUMN product_id TYPE UUID USING product_id::UUID;

-- ============================================
-- SECTION 8: CONVERTIR DELIVERIES
-- ============================================
ALTER TABLE deliveries ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE deliveries ALTER COLUMN order_id TYPE UUID USING order_id::UUID;
ALTER TABLE deliveries ALTER COLUMN deliverer_id TYPE UUID USING deliverer_id::UUID;
ALTER TABLE deliveries ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- SECTION 9: CONVERTIR AUDIT_LOGS
-- ============================================
ALTER TABLE audit_logs ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE audit_logs ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
ALTER TABLE audit_logs ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;
ALTER TABLE audit_logs ALTER COLUMN entity_id TYPE UUID USING entity_id::UUID;

-- ============================================
-- SECTION 10: CONVERTIR REFRESH_TOKENS
-- ============================================
ALTER TABLE refresh_tokens ALTER COLUMN id TYPE UUID USING id::UUID;
ALTER TABLE refresh_tokens ALTER COLUMN user_id TYPE UUID USING user_id::UUID;

-- ============================================
-- SECTION 11: CONVERTIR PAYMENTS
-- ============================================
ALTER TABLE payments ALTER COLUMN customer_id TYPE UUID USING customer_id::UUID;
ALTER TABLE payments ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;
ALTER TABLE payments ALTER COLUMN recorded_by TYPE UUID USING recorded_by::UUID;

-- ============================================
-- SECTION 12: CONVERTIR PAYMENT_ORDERS
-- ============================================
ALTER TABLE payment_orders ALTER COLUMN order_id TYPE UUID USING order_id::UUID;

-- ============================================
-- SECTION 13: CONVERTIR NOTIFICATIONS
-- ============================================
ALTER TABLE notifications ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
ALTER TABLE notifications ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- SECTION 14: CONVERTIR RECURRING_ORDERS
-- ============================================
ALTER TABLE recurring_orders ALTER COLUMN customer_id TYPE UUID USING customer_id::UUID;
ALTER TABLE recurring_orders ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- SECTION 15: CONVERTIR RECURRING_ORDER_ITEMS
-- ============================================
ALTER TABLE recurring_order_items ALTER COLUMN product_id TYPE UUID USING product_id::UUID;

-- ============================================
-- SECTION 16: CONVERTIR FAVORITE_ORDERS
-- ============================================
ALTER TABLE favorite_orders ALTER COLUMN client_id TYPE UUID USING client_id::UUID;
ALTER TABLE favorite_orders ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- SECTION 17: CONVERTIR PACKAGING_TYPES
-- ============================================
ALTER TABLE packaging_types ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- SECTION 18: CONVERTIR PACKAGING_DEPOSITS
-- ============================================
ALTER TABLE packaging_deposits ALTER COLUMN customer_id TYPE UUID USING customer_id::UUID;
ALTER TABLE packaging_deposits ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;
ALTER TABLE packaging_deposits ALTER COLUMN delivery_id TYPE UUID USING delivery_id::UUID;

-- ============================================
-- SECTION 19: CONVERTIR LOCATION_HISTORY
-- ============================================
ALTER TABLE location_history ALTER COLUMN deliverer_id TYPE UUID USING deliverer_id::UUID;
ALTER TABLE location_history ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- SECTION 20: CONVERTIR CLIENT_ORDER_PATTERNS
-- ============================================
ALTER TABLE client_order_patterns ALTER COLUMN client_id TYPE UUID USING client_id::UUID;
ALTER TABLE client_order_patterns ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- SECTION 21: CONVERTIR USER_PREFERENCES
-- ============================================
ALTER TABLE user_preferences ALTER COLUMN user_id TYPE UUID USING user_id::UUID;

-- ============================================
-- SECTION 22: CONVERTIR NOTIFICATION_PREFERENCES
-- ============================================
ALTER TABLE notification_preferences ALTER COLUMN user_id TYPE UUID USING user_id::UUID;

-- ============================================
-- SECTION 23: CONVERTIR ORDER_SEQUENCES
-- ============================================
ALTER TABLE order_sequences ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- VÉRIFICATION: Afficher les colonnes encore en TEXT
-- ============================================
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND (column_name LIKE '%_id' OR column_name = 'id')
AND data_type != 'uuid'
AND table_name NOT IN (
    SELECT table_name 
    FROM information_schema.views 
    WHERE table_schema = 'public'
)
ORDER BY table_name, column_name;
