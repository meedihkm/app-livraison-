-- ============================================
-- AUDIT COMPLET DE LA BASE DE DONNÉES
-- Date: 2026-02-04
-- ============================================

-- 1. LISTE DE TOUTES LES TABLES
SELECT 
    'TABLES' as type,
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_name)::regclass)) as size
FROM information_schema.tables t
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- 2. TOUTES LES FOREIGN KEYS
SELECT 
    'FOREIGN KEYS' as type,
    tc.table_name, 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema='public'
ORDER BY tc.table_name;

-- 3. TOUS LES INDEX
SELECT 
    'INDEXES' as type,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- 4. COMPTAGE DES ENREGISTREMENTS PAR TABLE
SELECT 'payments' as table_name, COUNT(*) as count FROM payments
UNION ALL SELECT 'debt_payments', COUNT(*) FROM debt_payments
UNION ALL SELECT 'payment_orders', COUNT(*) FROM payment_orders
UNION ALL SELECT 'payment_transactions', COUNT(*) FROM payment_transactions
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'deliveries', COUNT(*) FROM deliveries
UNION ALL SELECT 'organizations', COUNT(*) FROM organizations
ORDER BY table_name;

-- 5. TABLES VIDES (potentiellement inutiles)
SELECT 
    'EMPTY TABLES' as type,
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = pg_tables.tablename 
    AND table_schema = 'public'
    LIMIT 1
)
ORDER BY tablename;

-- 6. COLONNES AVEC VALEURS NULL (potentiellement mal définies)
SELECT 
    'NULLABLE COLUMNS' as type,
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND is_nullable = 'YES'
AND column_name NOT IN ('notes', 'description', 'updated_at', 'deleted_at')
ORDER BY table_name, column_name;

-- 7. CONTRAINTES MANQUANTES (colonnes _id sans foreign key)
SELECT 
    'MISSING FK' as type,
    c.table_name,
    c.column_name,
    c.data_type
FROM information_schema.columns c
WHERE c.table_schema = 'public'
AND c.column_name LIKE '%_id'
AND NOT EXISTS (
    SELECT 1 
    FROM information_schema.key_column_usage kcu
    WHERE kcu.table_schema = 'public'
    AND kcu.table_name = c.table_name
    AND kcu.column_name = c.column_name
)
ORDER BY c.table_name, c.column_name;
