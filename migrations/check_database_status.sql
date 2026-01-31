-- Script de vÃ©rification de l'Ã©tat de la base de donnÃ©es
-- Date: 2026-01-24
-- Usage: psql -U postgres -d votre_db -f api-v2/migrations/check_database_status.sql

\echo '========================================='
\echo 'ðŸ” VÃ‰RIFICATION DE LA BASE DE DONNÃ‰ES'
\echo '========================================='
\echo ''

-- 1. VÃ©rifier la colonne dans orders
\echo '1ï¸âƒ£ VÃ©rification de la table ORDERS:'
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'customer_id')
        THEN 'âœ… Column customer_id existe'
        ELSE 'âŒ Column customer_id manquante'
    END as orders_customer_id,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'cafeteria_id')
        THEN 'âš ï¸  Column cafeteria_id existe encore (Ã  renommer)'
        ELSE 'âœ… Column cafeteria_id n''existe pas'
    END as orders_cafeteria_id;

\echo ''

-- 2. VÃ©rifier recurring_orders
\echo '2ï¸âƒ£ VÃ©rification de la table RECURRING_ORDERS:'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'recurring_orders'
ORDER BY ordinal_position;

\echo ''

-- 3. VÃ©rifier audit_logs
\echo '3ï¸âƒ£ VÃ©rification de la table AUDIT_LOGS:'
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'audit_logs' AND column_name = 'entity_type')
        THEN 'âœ… Column entity_type existe'
        ELSE 'âŒ Column entity_type manquante'
    END as audit_entity_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'audit_logs' AND column_name = 'entity_id')
        THEN 'âœ… Column entity_id existe'
        ELSE 'âŒ Column entity_id manquante'
    END as audit_entity_id;

\echo ''

-- 4. VÃ©rifier debt_payments
\echo '4ï¸âƒ£ VÃ©rification de la table DEBT_PAYMENTS:'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'debt_payments'
ORDER BY ordinal_position;

\echo ''

-- 5. VÃ©rifier les vues
\echo '5ï¸âƒ£ VÃ©rification des VUES:'
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'client_debts_view')
        THEN 'âœ… Vue client_debts_view existe'
        ELSE 'âŒ Vue client_debts_view manquante'
    END as client_debts_view,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'active_deliveries_view')
        THEN 'âœ… Vue active_deliveries_view existe'
        ELSE 'âŒ Vue active_deliveries_view manquante'
    END as active_deliveries_view;

\echo ''

-- 6. VÃ©rifier les triggers
\echo '6ï¸âƒ£ VÃ©rification des TRIGGERS:'
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

\echo ''

-- 7. VÃ©rifier les fonctions problÃ©matiques
\echo '7ï¸âƒ£ VÃ©rification des FONCTIONS:'
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public' 
  AND routine_name IN ('update_client_address_from_delivery', 'detect_order_pattern')
ORDER BY routine_name;

\echo ''

-- 8. VÃ©rifier les index
\echo '8ï¸âƒ£ VÃ©rification des INDEX sur les colonnes clÃ©s:'
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND (indexname LIKE '%customer_id%' OR indexname LIKE '%cafeteria_id%')
ORDER BY tablename, indexname;

\echo ''
\echo '========================================='
\echo 'âœ… VÃ‰RIFICATION TERMINÃ‰E'
\echo '========================================='
