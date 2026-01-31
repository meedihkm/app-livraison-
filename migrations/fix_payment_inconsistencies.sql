-- ============================================
-- SCRIPT DE CORRECTION DES INCOHÃ‰RENCES DE PAIEMENTS ET DETTES
-- Date: 2026-01-25
-- Description: Identifier et corriger les incohÃ©rences entre orders, payments et debts
-- ============================================

-- ============================================
-- PARTIE 1: DIAGNOSTIC - IDENTIFIER LES INCOHÃ‰RENCES
-- ============================================

-- 1.1 Commandes marquÃ©es "paid" SANS paiement enregistrÃ©
SELECT 
    'ðŸ”´ INCOHÃ‰RENCE: Commandes paid sans paiement' as issue_type,
    COUNT(*) as count
FROM orders o
WHERE o.payment_status = 'paid'
AND NOT EXISTS (
    SELECT 1 FROM payments p 
    WHERE p.order_id = o.id
);

-- DÃ©tails des commandes concernÃ©es
SELECT 
    o.id as order_id,
    o.customer_id,
    u.name as customer_name,
    o.total,
    o.payment_status,
    o.created_at,
    'MarquÃ© paid mais aucun paiement enregistrÃ©' as problem
FROM orders o
LEFT JOIN users u ON o.customer_id = u.id
WHERE o.payment_status = 'paid'
AND NOT EXISTS (
    SELECT 1 FROM payments p 
    WHERE p.order_id = o.id
)
ORDER BY o.created_at DESC;

-- 1.2 Commandes marquÃ©es "unpaid" AVEC paiement enregistrÃ©
SELECT 
    'ðŸ”´ INCOHÃ‰RENCE: Commandes unpaid avec paiement' as issue_type,
    COUNT(*) as count
FROM orders o
WHERE o.payment_status = 'unpaid'
AND EXISTS (
    SELECT 1 FROM payments p 
    WHERE p.order_id = o.id
    AND p.amount >= o.total
);

-- DÃ©tails des commandes concernÃ©es
SELECT 
    o.id as order_id,
    o.customer_id,
    u.name as customer_name,
    o.total as order_total,
    COALESCE(SUM(p.amount), 0) as total_paid,
    o.payment_status,
    'MarquÃ© unpaid mais paiement complet enregistrÃ©' as problem
FROM orders o
LEFT JOIN users u ON o.customer_id = u.id
LEFT JOIN payments p ON p.order_id = o.id
WHERE o.payment_status = 'unpaid'
GROUP BY o.id, o.customer_id, u.name, o.total, o.payment_status
HAVING COALESCE(SUM(p.amount), 0) >= o.total
ORDER BY o.created_at DESC;

-- 1.3 Commandes avec paiements partiels
SELECT 
    'âš ï¸  ATTENTION: Paiements partiels' as issue_type,
    COUNT(*) as count
FROM orders o
WHERE EXISTS (
    SELECT 1 FROM payments p 
    WHERE p.order_id = o.id
    HAVING SUM(p.amount) < o.total
);

-- DÃ©tails des paiements partiels
SELECT 
    o.id as order_id,
    o.customer_id,
    u.name as customer_name,
    o.total as order_total,
    COALESCE(SUM(p.amount), 0) as total_paid,
    o.total - COALESCE(SUM(p.amount), 0) as remaining_debt,
    o.payment_status,
    'Paiement partiel' as status
FROM orders o
LEFT JOIN users u ON o.customer_id = u.id
LEFT JOIN payments p ON p.order_id = o.id
GROUP BY o.id, o.customer_id, u.name, o.total, o.payment_status
HAVING COALESCE(SUM(p.amount), 0) > 0 
   AND COALESCE(SUM(p.amount), 0) < o.total
ORDER BY o.created_at DESC;

-- 1.4 Dettes dans la table debts SANS commande correspondante
SELECT 
    'ðŸ”´ INCOHÃ‰RENCE: Dettes orphelines' as issue_type,
    COUNT(*) as count
FROM debts d
WHERE NOT EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.id = d.order_id
);

-- DÃ©tails des dettes orphelines
SELECT 
    d.id as debt_id,
    d.order_id,
    d.customer_id,
    d.amount as debt_amount,
    d.status as debt_status,
    'Dette sans commande correspondante' as problem
FROM debts d
WHERE NOT EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.id = d.order_id
)
ORDER BY d.created_at DESC;

-- ============================================
-- PARTIE 2: CORRECTION AUTOMATIQUE
-- ============================================

-- 2.1 Corriger les commandes "paid" sans paiement
-- CrÃ©er les entrÃ©es de paiement manquantes
INSERT INTO payments (
    order_id,
    customer_id,
    amount,
    payment_method,
    payment_date,
    recorded_by,
    organization_id,
    created_at
)
SELECT 
    o.id as order_id,
    o.customer_id,
    o.total as amount,
    'cash' as payment_method,
    o.updated_at as payment_date,
    o.customer_id as recorded_by, -- EnregistrÃ© par le client lui-mÃªme
    o.organization_id,
    NOW() as created_at
FROM orders o
WHERE o.payment_status = 'paid'
AND NOT EXISTS (
    SELECT 1 FROM payments p 
    WHERE p.order_id = o.id
)
AND o.total > 0;

-- 2.2 Corriger les commandes "unpaid" avec paiement complet
UPDATE orders o
SET 
    payment_status = 'paid',
    updated_at = NOW()
WHERE o.payment_status = 'unpaid'
AND EXISTS (
    SELECT 1 FROM (
        SELECT order_id, SUM(amount) as total_paid
        FROM payments
        GROUP BY order_id
    ) p
    WHERE p.order_id = o.id
    AND p.total_paid >= o.total
);

-- 2.3 Corriger les commandes avec paiements partiels
UPDATE orders o
SET 
    payment_status = 'partial',
    updated_at = NOW()
WHERE EXISTS (
    SELECT 1 FROM (
        SELECT order_id, SUM(amount) as total_paid
        FROM payments
        GROUP BY order_id
    ) p
    WHERE p.order_id = o.id
    AND p.total_paid > 0
    AND p.total_paid < o.total
);

-- ============================================
-- PARTIE 3: RECALCUL DES DETTES
-- ============================================

-- 3.1 Supprimer les dettes pour les commandes payÃ©es
DELETE FROM debts d
WHERE EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = d.order_id
    AND o.payment_status = 'paid'
);

-- 3.2 Mettre Ã  jour les dettes existantes avec les montants corrects
UPDATE debts d
SET 
    amount = o.total - COALESCE(p.total_paid, 0),
    updated_at = NOW()
FROM orders o
LEFT JOIN (
    SELECT order_id, SUM(amount) as total_paid
    FROM payments
    GROUP BY order_id
) p ON p.order_id = o.id
WHERE d.order_id = o.id
AND o.payment_status IN ('unpaid', 'partial')
AND (o.total - COALESCE(p.total_paid, 0)) > 0;

-- 3.3 CrÃ©er les dettes manquantes pour les commandes impayÃ©es
INSERT INTO debts (
    order_id,
    customer_id,
    amount,
    status,
    organization_id,
    created_at,
    updated_at
)
SELECT 
    o.id as order_id,
    o.customer_id,
    o.total - COALESCE(p.total_paid, 0) as amount,
    'pending' as status,
    o.organization_id,
    o.created_at,
    NOW() as updated_at
FROM orders o
LEFT JOIN (
    SELECT order_id, SUM(amount) as total_paid
    FROM payments
    GROUP BY order_id
) p ON p.order_id = o.id
WHERE o.payment_status IN ('unpaid', 'partial')
AND (o.total - COALESCE(p.total_paid, 0)) > 0
AND NOT EXISTS (
    SELECT 1 FROM debts d 
    WHERE d.order_id = o.id
);

-- 3.4 Supprimer les dettes orphelines (sans commande)
DELETE FROM debts d
WHERE NOT EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.id = d.order_id
);

-- ============================================
-- PARTIE 4: VÃ‰RIFICATION POST-CORRECTION
-- ============================================

-- 4.1 RÃ©sumÃ© des corrections
SELECT 
    'âœ… RÃ‰SUMÃ‰ DES CORRECTIONS' as summary,
    (SELECT COUNT(*) FROM orders WHERE payment_status = 'paid') as total_paid,
    (SELECT COUNT(*) FROM orders WHERE payment_status = 'unpaid') as total_unpaid,
    (SELECT COUNT(*) FROM orders WHERE payment_status = 'partial') as total_partial,
    (SELECT COUNT(*) FROM debts) as total_debts,
    (SELECT COUNT(*) FROM payments) as total_payments;

-- 4.2 VÃ©rifier qu'il n'y a plus d'incohÃ©rences
SELECT 
    'ðŸ” VÃ‰RIFICATION: Commandes paid sans paiement' as check_type,
    COUNT(*) as remaining_issues
FROM orders o
WHERE o.payment_status = 'paid'
AND NOT EXISTS (
    SELECT 1 FROM payments p 
    WHERE p.order_id = o.id
);

SELECT 
    'ðŸ” VÃ‰RIFICATION: Commandes unpaid avec paiement complet' as check_type,
    COUNT(*) as remaining_issues
FROM orders o
WHERE o.payment_status = 'unpaid'
AND EXISTS (
    SELECT 1 FROM (
        SELECT order_id, SUM(amount) as total_paid
        FROM payments
        GROUP BY order_id
    ) p
    WHERE p.order_id = o.id
    AND p.total_paid >= o.total
);

SELECT 
    'ðŸ” VÃ‰RIFICATION: Dettes orphelines' as check_type,
    COUNT(*) as remaining_issues
FROM debts d
WHERE NOT EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.id = d.order_id
);

-- 4.3 Statistiques finales par client
SELECT 
    u.id as customer_id,
    u.name as customer_name,
    COUNT(DISTINCT o.id) as total_orders,
    SUM(CASE WHEN o.payment_status = 'paid' THEN 1 ELSE 0 END) as paid_orders,
    SUM(CASE WHEN o.payment_status = 'unpaid' THEN 1 ELSE 0 END) as unpaid_orders,
    SUM(CASE WHEN o.payment_status = 'partial' THEN 1 ELSE 0 END) as partial_orders,
    COALESCE(SUM(o.total), 0) as total_revenue,
    COALESCE(SUM(p.total_paid), 0) as total_collected,
    COALESCE(SUM(d.total_debt), 0) as total_debt
FROM users u
LEFT JOIN orders o ON o.customer_id = u.id
LEFT JOIN (
    SELECT customer_id, SUM(amount) as total_paid
    FROM payments
    GROUP BY customer_id
) p ON p.customer_id = u.id
LEFT JOIN (
    SELECT customer_id, SUM(amount) as total_debt
    FROM debts
    WHERE status = 'pending'
    GROUP BY customer_id
) d ON d.customer_id = u.id
WHERE u.role = 'customer'
GROUP BY u.id, u.name
ORDER BY total_debt DESC NULLS LAST;

-- ============================================
-- FIN DU SCRIPT
-- ============================================

DO $$ 
BEGIN
    RAISE NOTICE 'âœ… Script de correction des incohÃ©rences terminÃ©!';
    RAISE NOTICE 'ðŸ“Š VÃ©rifiez les rÃ©sultats ci-dessus';
    RAISE NOTICE 'ðŸ’¡ Les dettes ont Ã©tÃ© recalculÃ©es automatiquement';
    RAISE NOTICE 'ðŸ”„ RedÃ©marrez l''application pour voir les changements';
END $$;
