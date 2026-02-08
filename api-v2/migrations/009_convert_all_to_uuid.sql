-- ============================================
-- CONVERSION COMPLÈTE: TEXT → UUID
-- Date: 2026-02-04
-- ============================================
-- ⚠️ ATTENTION: Ce script modifie TOUTE la base de données
-- ⚠️ FAIRE UN BACKUP COMPLET AVANT D'EXÉCUTER
-- ⚠️ Tester d'abord sur une copie de la base

-- ============================================
-- ÉTAPE 0: VÉRIFICATIONS PRÉALABLES
-- ============================================

-- Vérifier que toutes les valeurs TEXT sont des UUID valides
DO $$
DECLARE
    invalid_count INTEGER;
BEGIN
    -- Vérifier users.id
    SELECT COUNT(*) INTO invalid_count
    FROM users
    WHERE id !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
    
    IF invalid_count > 0 THEN
        RAISE EXCEPTION 'users.id contient % valeurs non-UUID', invalid_count;
    END IF;
    
    -- Vérifier organizations.id
    SELECT COUNT(*) INTO invalid_count
    FROM organizations
    WHERE id !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
    
    IF invalid_count > 0 THEN
        RAISE EXCEPTION 'organizations.id contient % valeurs non-UUID', invalid_count;
    END IF;
    
    RAISE NOTICE 'Vérification OK: Toutes les valeurs sont des UUID valides';
END $$;

-- ============================================
-- ÉTAPE 1: SUPPRIMER TOUTES LES FOREIGN KEYS
-- ============================================

-- On doit supprimer toutes les FK avant de changer les types
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
-- ÉTAPE 2: CONVERTIR LES TABLES PRINCIPALES
-- ============================================

-- 1. ORGANIZATIONS (doit être fait en premier car référencé partout)
ALTER TABLE organizations ALTER COLUMN id TYPE UUID USING id::UUID;

-- 2. USERS (référencé partout)
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
-- ÉTAPE 3: CONVERTIR LES TABLES SECONDAIRES
-- ============================================

-- PAYMENTS (customer_id et organization_id seulement, id déjà UUID)
ALTER TABLE payments ALTER COLUMN customer_id TYPE UUID USING customer_id::UUID;
ALTER TABLE payments ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;
ALTER TABLE payments ALTER COLUMN recorded_by TYPE UUID USING recorded_by::UUID;

-- PAYMENT_ORDERS (order_id seulement, les autres déjà UUID)
ALTER TABLE payment_orders ALTER COLUMN order_id TYPE UUID USING order_id::UUID;

-- NOTIFICATIONS (user_id et organization_id)
ALTER TABLE notifications ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
ALTER TABLE notifications ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- RECURRING_ORDERS (customer_id et organization_id)
ALTER TABLE recurring_orders ALTER COLUMN customer_id TYPE UUID USING customer_id::UUID;
ALTER TABLE recurring_orders ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- RECURRING_ORDER_ITEMS (product_id)
ALTER TABLE recurring_order_items ALTER COLUMN product_id TYPE UUID USING product_id::UUID;

-- FAVORITE_ORDERS (client_id et organization_id)
ALTER TABLE favorite_orders ALTER COLUMN client_id TYPE UUID USING client_id::UUID;
ALTER TABLE favorite_orders ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- PACKAGING_TYPES (organization_id)
ALTER TABLE packaging_types ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- PACKAGING_DEPOSITS (organization_id et delivery_id)
ALTER TABLE packaging_deposits ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;
ALTER TABLE packaging_deposits ALTER COLUMN delivery_id TYPE UUID USING delivery_id::UUID;

-- LOCATION_HISTORY (deliverer_id et organization_id)
ALTER TABLE location_history ALTER COLUMN deliverer_id TYPE UUID USING deliverer_id::UUID;
ALTER TABLE location_history ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- CLIENT_ORDER_PATTERNS (client_id et organization_id)
ALTER TABLE client_order_patterns ALTER COLUMN client_id TYPE UUID USING client_id::UUID;
ALTER TABLE client_order_patterns ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- USER_PREFERENCES (user_id)
ALTER TABLE user_preferences ALTER COLUMN user_id TYPE UUID USING user_id::UUID;

-- NOTIFICATION_PREFERENCES (user_id)
ALTER TABLE notification_preferences ALTER COLUMN user_id TYPE UUID USING user_id::UUID;

-- ORDER_SEQUENCES (organization_id)
ALTER TABLE order_sequences ALTER COLUMN organization_id TYPE UUID USING organization_id::UUID;

-- ============================================
-- ÉTAPE 4: RECRÉER LES FOREIGN KEYS
-- ============================================

-- Organizations (aucune FK sortante)

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
-- ÉTAPE 5: VÉRIFICATION FINALE
-- ============================================

-- Compter les colonnes converties
SELECT 
    'CONVERSION COMPLETE' as status,
    COUNT(*) as total_uuid_columns
FROM information_schema.columns
WHERE table_schema = 'public'
AND data_type = 'uuid'
AND (column_name LIKE '%_id' OR column_name = 'id');

-- Vérifier les foreign keys
SELECT 
    'FOREIGN KEYS RECREATED' as status,
    COUNT(*) as total_fks
FROM information_schema.table_constraints
WHERE constraint_type = 'FOREIGN KEY'
AND table_schema = 'public';

-- Afficher un résumé
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND (column_name LIKE '%_id' OR column_name = 'id')
AND data_type != 'uuid'
ORDER BY table_name, column_name;

RAISE NOTICE '✅ CONVERSION TERMINÉE AVEC SUCCÈS';
