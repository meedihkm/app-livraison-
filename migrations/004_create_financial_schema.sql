-- =====================================================
-- MIGRATION: SchÃ©ma financier complet - VERSION SÃ‰CURISÃ‰E
-- Cette migration crÃ©e UNIQUEMENT de nouvelles tables
-- Elle ne modifie AUCUNE table existante
-- =====================================================

-- VÃ©rification: Ne rien exÃ©cuter si les tables existent dÃ©jÃ 
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'payments') THEN
        RAISE NOTICE 'âš ï¸  Les tables financiÃ¨res existent dÃ©jÃ . Migration dÃ©jÃ  appliquÃ©e.';
        RETURN;
    END IF;
END $$;

BEGIN;

-- ============================================
-- TABLE: payments (Nouvelle table dÃ©diÃ©e)
-- ============================================
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    mode VARCHAR(20) NOT NULL DEFAULT 'cash' CHECK (mode IN ('cash', 'check', 'transfer')),
    recorded_by UUID NOT NULL REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour les requÃªtes courantes
CREATE INDEX IF NOT EXISTS idx_payments_org_customer 
ON payments(organization_id, customer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payments_date 
ON payments(organization_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payments_recorded_by 
ON payments(recorded_by, created_at DESC);

COMMENT ON TABLE payments IS 'Table des paiements dÃ©diÃ©e - nouvelle architecture v2';
COMMENT ON COLUMN payments.mode IS 'cash, check, or transfer';

-- ============================================
-- TABLE: payment_orders (Liaison paiement-commande)
-- ============================================
CREATE TABLE IF NOT EXISTS payment_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    amount_applied DECIMAL(10,2) NOT NULL CHECK (amount_applied > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(payment_id, order_id)
);

CREATE INDEX IF NOT EXISTS idx_payment_orders_payment 
ON payment_orders(payment_id);

CREATE INDEX IF NOT EXISTS idx_payment_orders_order 
ON payment_orders(order_id);

COMMENT ON TABLE payment_orders IS 'Liaison entre paiements et commandes (rÃ©partition)';

-- ============================================
-- TABLE: debt_history (Historique des dettes - optionnel)
-- ============================================
CREATE TABLE IF NOT EXISTS debt_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    debt_before DECIMAL(10,2) NOT NULL DEFAULT 0,
    debt_after DECIMAL(10,2) NOT NULL DEFAULT 0,
    change_amount DECIMAL(10,2) NOT NULL,
    change_type VARCHAR(20) NOT NULL CHECK (change_type IN ('payment', 'order', 'adjustment', 'cancel')),
    reference_id UUID, -- ID du paiement ou de la commande
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_debt_history_customer 
ON debt_history(organization_id, customer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_debt_history_date 
ON debt_history(organization_id, created_at DESC);

COMMENT ON TABLE debt_history IS 'Historique des changements de dette (audit trail)';

-- ============================================
-- INDEX OPTIMISÃ‰S pour les requÃªtes frÃ©quentes (sur tables EXISTANTES)
-- Ces index accÃ©lÃ¨rent les requÃªtes sans modifier la structure
-- ============================================

-- Index pour le calcul rapide des dettes (si pas dÃ©jÃ  existant)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_orders_debt_calculation') THEN
        CREATE INDEX idx_orders_debt_calculation 
        ON orders(organization_id, customer_id, status) 
        WHERE total > amount_paid AND status != 'cancelled';
        
        RAISE NOTICE 'âœ… Index idx_orders_debt_calculation crÃ©Ã©';
    END IF;
END $$;

-- Index pour les stats financiÃ¨res (si pas dÃ©jÃ  existant)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_orders_financial_stats') THEN
        CREATE INDEX idx_orders_financial_stats 
        ON orders(organization_id, created_at, status, payment_status);
        
        RAISE NOTICE 'âœ… Index idx_orders_financial_stats crÃ©Ã©';
    END IF;
END $$;

-- Index pour les alertes crÃ©dit (si pas dÃ©jÃ  existant)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_users_credit') THEN
        CREATE INDEX idx_users_credit 
        ON users(organization_id, credit_limit) 
        WHERE credit_limit > 0;
        
        RAISE NOTICE 'âœ… Index idx_users_credit crÃ©Ã©';
    END IF;
END $$;

-- Index composite pour les commandes client (si pas dÃ©jÃ  existant)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_orders_customer_status') THEN
        CREATE INDEX idx_orders_customer_status 
        ON orders(customer_id, status, created_at DESC);
        
        RAISE NOTICE 'âœ… Index idx_orders_customer_status crÃ©Ã©';
    END IF;
END $$;

COMMIT;

-- ============================================
-- VÃ‰RIFICATION POST-MIGRATION
-- ============================================
DO $$
DECLARE
    v_payments_exists BOOLEAN;
    v_payment_orders_exists BOOLEAN;
    v_debt_history_exists BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT FROM pg_tables WHERE tablename = 'payments') INTO v_payments_exists;
    SELECT EXISTS (SELECT FROM pg_tables WHERE tablename = 'payment_orders') INTO v_payment_orders_exists;
    SELECT EXISTS (SELECT FROM pg_tables WHERE tablename = 'debt_history') INTO v_debt_history_exists;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'MIGRATION FINANCIÃˆRE TERMINÃ‰E';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'âœ… Table payments: %', CASE WHEN v_payments_exists THEN 'CRÃ‰Ã‰E' ELSE 'ERREUR' END;
    RAISE NOTICE 'âœ… Table payment_orders: %', CASE WHEN v_payment_orders_exists THEN 'CRÃ‰Ã‰E' ELSE 'ERREUR' END;
    RAISE NOTICE 'âœ… Table debt_history: %', CASE WHEN v_debt_history_exists THEN 'CRÃ‰Ã‰E' ELSE 'ERREUR' END;
    RAISE NOTICE '';
    RAISE NOTICE 'ðŸ“ Prochaines Ã©tapes:';
    RAISE NOTICE '  1. Tester les routes /api/financial/v2/*';
    RAISE NOTICE '  2. VÃ©rifier que l ancienne API fonctionne toujours';
    RAISE NOTICE '  3. Migrer les donnÃ©es de audit_logs vers payments';
    RAISE NOTICE '========================================';
END $$;
